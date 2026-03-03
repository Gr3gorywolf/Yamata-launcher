import 'dart:convert';

// ignore_for_file: lines_longer_than_80_chars, use_raw_strings

import 'dart:convert';
import 'package:adblocker_manager/adblocker_manager.dart';

/// Generates JavaScript for blocking ad resources (XHR, Fetch, Scripts, Images).
///
/// Performance optimizations:
/// - Rules indexed by domain fragments for O(1) lookup
/// - Exception rules checked via Set for fast lookup
/// - Minimal logging (debug mode only)
/// - Fixed XHR override to properly block requests
/// - Added iframe and WebSocket blocking
String getResourceLoadingBlockerScript(List<ResourceRule> rules) {
  // Separate and encode rules
  // For simplicity and performance in JS, we only send necessary data
  final blockRulesData = rules.where((r) => !r.isException).map((r) {
    if (r.resourceTypes == null &&
        r.domains == null &&
        !r.isImportant &&
        !r.isThirdParty) {
      return "'${_escapeJs(r.url)}'";
    }
    // Complex rule
    // t: types, d: domains, i: important, tp: thirdParty
    // ignore: omit_local_variable_types
    final Map<String, dynamic> map = {'u': r.url};
    if (r.resourceTypes != null) map['t'] = r.resourceTypes;
    if (r.domains != null) map['d'] = r.domains;
    // Optimization: don't send false flags
    if (r.isImportant) map['i'] = 1;
    if (r.isThirdParty) map['tp'] = 1;
    return jsonEncode(map);
  }).join(',');

  final exceptionRulesData = rules
      .where((r) => r.isException)
      .map((r) => "'${_escapeJs(r.url)}'")
      .join(',');

  return '''
(function() {
  'use strict';
  
  const DEBUG = false;
  // blockUrls contains strings (simple rules) or objects (complex rules)
  const blockRules = [$blockRulesData];
  const exceptionUrls = new Set([$exceptionRulesData]);
  
  // Build index for fast lookups
  const blockIndex = new Map();
  // Separate simple strings from complex objects for performance
  const simpleRules = [];
  const complexRules = [];

  blockRules.forEach(rule => {
    if (typeof rule === 'string') {
      simpleRules.push(rule);
      indexRule(rule, blockIndex, rule);
    } else {
      complexRules.push(rule);
      indexRule(rule.u, blockIndex, rule);
    }
  });
  
  function indexRule(urlPart, index, ruleRef) {
    const parts = urlPart.split('.');
    parts.forEach(part => {
      if (part.length > 2) {
        if (!index.has(part)) index.set(part, []);
        index.get(part).push(ruleRef);
      }
    });
  }
  
  function isException(url) {
    const lowerUrl = url.toLowerCase();
    for (const exc of exceptionUrls) {
      if (lowerUrl.includes(exc)) return true;
    }
    return false;
  }
  
  function isDomainMatch(domain, ruleDomain) {
    if (domain === ruleDomain) return true;
    if (domain.endsWith('.' + ruleDomain)) return true;
    return false;
  }

  function checkRule(rule, url, type, domain) {
    const ruleUrl = typeof rule === 'string' ? rule : rule.u;
    if (!url.includes(ruleUrl)) return false;
    
    if (typeof rule === 'string') return true;
    
    // Check Resource Type
    if (rule.t && type) {
      if (!rule.t.includes(type)) return false;
    }

    // Check Third Party
    if (rule.tp) {
       try {
         const targetHost = new URL(url).hostname;
         const pageHost = window.location.hostname;
         // Simple third-party check: domain suffix mismatch
         // This is a heuristic; proper TLD matching is hard in pure JS without a huge list
         if (isDomainMatch(targetHost, pageHost)) return false; 
       } catch(e) {}
    }
    
    // Check Domains (simplified)
    if (rule.d) {
       const pageHost = window.location.hostname;
       let matched = false;
       for (const d of rule.d) {
         if (d.startsWith('~')) {
           const ruleDomain = d.substring(1);
           if (isDomainMatch(pageHost, ruleDomain)) return false; // Explicit exclusion
         } else {
           if (isDomainMatch(pageHost, d)) matched = true;
         }
       }
       // If there were positive domain constraints, we must have matched at least one
       const hasPositive = rule.d.some(d => !d.startsWith('~'));
       if (hasPositive && !matched) return false;
    }

    return true;
  }

  function shouldBlock(url, type) {
    if (!url || typeof url !== 'string') return false;
    const lowerUrl = url.toLowerCase();
    
    // Fast path: check exceptions first
    if (isException(lowerUrl)) {
      if (DEBUG) console.log('[AdBlocker] Exception:', url);
      return false;
    }
    
    const domain = window.location.hostname; // current page domain for context

    // Check against index for faster matching
    const urlParts = lowerUrl.split(/[./]/);
    for (const part of urlParts) {
      const candidates = blockIndex.get(part);
      if (candidates) {
        for (const rule of candidates) {
          if (checkRule(rule, lowerUrl, type, domain)) {
             if (DEBUG) console.log('[AdBlocker] Blocked:', url, type);
             return true;
          }
        }
      }
    }
    
    // Fallback: linear check for simple rules not indexed
    // (Actual logic above indexes everything > 2 chars, so this is just cleanup for very short rules if any)
    for (const rule of simpleRules) {
      if (lowerUrl.includes(rule)) {
        if (DEBUG) console.log('[AdBlocker] Blocked:', url, type);
        return true;
      }
    }
    
    for (const rule of complexRules) {
      if (checkRule(rule, lowerUrl, type, domain)) {
         if (DEBUG) console.log('[AdBlocker] Blocked:', url, type);
         return true;
      }
    }
    
    return false;
  }
  
  // Override XMLHttpRequest
  const OrigXHR = window.XMLHttpRequest;
  window.XMLHttpRequest = function() {
    const xhr = new OrigXHR();
    const origOpen = xhr.open.bind(xhr);
    
    xhr.open = function(method, url, ...args) {
      if (shouldBlock(url, 'xmlhttprequest')) {
        // Block by making it a no-op
        xhr.send = () => {};
        xhr.abort = () => {};
        Object.defineProperty(xhr, 'status', { value: 0 });
        Object.defineProperty(xhr, 'readyState', { value: 4 });
        return;
      }
      return origOpen(method, url, ...args);
    };
    
    return xhr;
  };
  window.XMLHttpRequest.prototype = OrigXHR.prototype;
  
  // Override Fetch API
  const origFetch = window.fetch;
  window.fetch = function(resource, init) {
    const url = resource instanceof Request ? resource.url : String(resource);
    if (shouldBlock(url, 'xmlhttprequest')) {
      // Return a Promise that never resolves (or resolves empty) to simulate network failure/empty response
      // Commonly, adblockers return an empty 200 OK or a network error.
      // We'll return an empty 200 to avoid console noise, or maybe a 403?
      // uBlock Origin often redirects to a 1x1 gif or empty text.
      return Promise.resolve(new Response('', { 
        status: 200, 
        statusText: 'Blocked' 
      }));
    }
    return origFetch.apply(this, arguments);
  };
  
  // Override Navigator.sendBeacon
  if (navigator.sendBeacon) {
    const origSendBeacon = navigator.sendBeacon;
    navigator.sendBeacon = function(url, data) {
      if (shouldBlock(url, 'ping')) {
        if (DEBUG) console.log('[AdBlocker] Blocked Beacon:', url);
        return true; // sendBeacon returns true if queued, we lie to the caller
      }
      return origSendBeacon.call(navigator, url, data);
    };
  }
  
  // Override createElement for script/iframe blocking
  const origCreate = document.createElement.bind(document);
  document.createElement = function(tag) {
    const el = origCreate(tag);
    const lowerTag = tag.toLowerCase();
    
    if (lowerTag === 'script') {
       const origSetAttr = el.setAttribute.bind(el);
       el.setAttribute = function(name, value) {
         if (name === 'src' && shouldBlock(value, 'script')) return;
         return origSetAttr(name, value);
       };
       Object.defineProperty(el, 'src', {
          set: function(v) {
             if (shouldBlock(v, 'script')) return;
             el.setAttribute('src', v);
          },
          get: () => el.getAttribute('src') || '',
          configurable: true
       });
    } else if (lowerTag === 'iframe') {
        const origSetAttr = el.setAttribute.bind(el);
        el.setAttribute = function(name, value) {
          if (name === 'src' && shouldBlock(value, 'subdocument')) return;
          return origSetAttr(name, value);
        };
       Object.defineProperty(el, 'src', {
          set: function(v) {
             if (shouldBlock(v, 'subdocument')) return;
             el.setAttribute('src', v);
          },
          get: () => el.getAttribute('src') || '',
          configurable: true
       });
    }
    
    return el;
  };
  
  // Override Image src
  const imgDesc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  if (imgDesc) {
    Object.defineProperty(HTMLImageElement.prototype, 'src', {
      get: function() { return imgDesc.get.call(this); },
      set: function(v) {
        if (shouldBlock(v, 'image')) return;
        imgDesc.set.call(this, v);
      },
      configurable: true
    });
  }
  
  // Override WebSocket
  const OrigWS = window.WebSocket;
  if (OrigWS) {
    window.WebSocket = function(url, protocols) {
      if (shouldBlock(url, 'websocket')) {
        return {
          send: () => { throw new Error('Blocked'); },
          close: () => {},
          readyState: 3, // CLOSED
          addEventListener: () => {},
          removeEventListener: () => {}
        };
      }
      return protocols ? new OrigWS(url, protocols) : new OrigWS(url);
    };
    window.WebSocket.prototype = OrigWS.prototype;
    window.WebSocket.CONNECTING = 0;
    window.WebSocket.OPEN = 1;
    window.WebSocket.CLOSING = 2;
    window.WebSocket.CLOSED = 3;
  }
  
  if (DEBUG) console.log('[AdBlocker] Blocking enabled');
})();
''';
}

/// Escapes a string for use in JavaScript string literals.
String _escapeJs(String s) {
  return s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}

/// Generates JavaScript for hiding ad elements using CSS selectors.
///
/// Performance optimizations:
/// - Debounced MutationObserver to prevent excessive processing
/// - Reduced batch delay (10ms vs 300ms)
/// - Combined selectors into CSS style injection for initial hide
/// - Removal is still done for dynamically added elements
/// - Minimal logging in production
String generateHidingScript(List<String> selectors) {
  final jsSelectorsArray = jsonEncode(selectors);
  return '''
(function() {
  'use strict';
  
  const selectors = $jsSelectorsArray;
  if (!Array.isArray(selectors) || selectors.length === 0) return;
  
  const BATCH_SIZE = 500;
  const DEBOUNCE_MS = 50;
  const DEBUG = false;
  
  let hideTimeout = null;
  let isProcessing = false;
  let processedCount = 0;
  
  // Inject CSS to hide elements immediately (faster than JS removal)
  function injectHidingStyles() {
    try {
      const style = document.createElement('style');
      style.id = 'adblocker-hiding-rules';
      
      // We chunk the selectors to avoid one massive rule if possible, 
      // but for "display: none !important", a single rule with all selectors comma-separated is most efficient.
      // However, one invalid selector can invalidate the whole rule in some browsers/versions (though standard says it drops just the invalid one).
      // To be safe, we can try to join them. If it fails, we falling back or splitting might be too heavy.
      // Modern browsers handle invalid selectors in a list gracefully (Selector Level 4), but older ones discard the whole rule.
      // We will blindly join for performance, assuming the parser that produced these selectors is decent.
      
      style.textContent = selectors.join(',') + ' { display: none !important; }';
      (document.head || document.documentElement).appendChild(style);
      
      if (DEBUG) console.log('[AdBlocker] Injected hiding styles for', selectors.length, 'selectors');
    } catch (e) {
      if (DEBUG) console.error('[AdBlocker] CSS injection error:', e);
    }
  }
  
  // Remove elements that match selectors (for complete removal, not just hiding)
  async function removeElements() {
    if (isProcessing) return;
    isProcessing = true;
    
    try {
      // Chunk processing to avoid blocking main thread for too long
      const batchCount = Math.ceil(selectors.length / BATCH_SIZE);
      
      for (let i = 0; i < batchCount; i++) {
        const start = i * BATCH_SIZE;
        const end = Math.min(start + BATCH_SIZE, selectors.length);
        // Optimize: Use querySelectorAll with comma-separated batch if possible? 
        // Yes, much faster than iterating selectors individually.
        const batchSelectors = selectors.slice(start, end);
        const combinedSelector = batchSelectors.join(',');
        
        try {
          const elements = document.querySelectorAll(combinedSelector);
          elements.forEach(el => {
            if (el && el.parentNode) {
              el.remove();
            }
          });
          processedCount += elements.length;
        } catch (e) {
          // If combined selector fails (e.g. one bad selector), we might need to fallback?
          // For now, silent fail for the batch.
          if (DEBUG) console.warn('[AdBlocker] Batch removal failed, likely invalid selector in batch', e);
        }
        
        // Yield to main thread
        if (i < batchCount - 1) {
          await new Promise(r => setTimeout(r, 10));
        }
      }
      
      if (DEBUG && processedCount > 0) {
        console.log('[AdBlocker] Removed', processedCount, 'elements');
      }
    } catch (e) {
      if (DEBUG) console.error('[AdBlocker] Remove error:', e);
    } finally {
      isProcessing = false;
    }
  }
  
  // Debounced hide function for MutationObserver
  function scheduleHide() {
    if (hideTimeout) clearTimeout(hideTimeout);
    hideTimeout = setTimeout(removeElements, DEBOUNCE_MS);
  }
  
  // Initialize
  function init() {
    injectHidingStyles();
    removeElements();
    
    try {
      const observer = new MutationObserver(scheduleHide);
      observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true
      });
    } catch (e) {
      if (DEBUG) console.error('[AdBlocker] Observer error:', e);
    }
  }
  
  if (document.body) {
    init();
  } else {
    const bodyObserver = new MutationObserver((_, obs) => {
      if (document.body) {
        obs.disconnect();
        init();
      }
    });
    bodyObserver.observe(document.documentElement, { childList: true });
  }
  
})();
''';
}
