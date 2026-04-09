(() => {
  'use strict';

  const pendingMessages = [];
  let inAppWebViewReady =
    typeof window.flutter_inappwebview?.callHandler === 'function';

  const flushMessages = () => {
    while (pendingMessages.length > 0) {
      const message = pendingMessages.shift();
      if (window.Print?.postMessage) {
        window.Print.postMessage(message);
        continue;
      }
      if (inAppWebViewReady && window.flutter_inappwebview?.callHandler) {
        window.flutter_inappwebview.callHandler('Print', message);
        continue;
      }
      pendingMessages.unshift(message);
      break;
    }
  };

  const postMessage = (message) => {
    if (!message) return;
    pendingMessages.push(message);
    flushMessages();
  };

  window.addEventListener('flutterInAppWebViewPlatformReady', () => {
    inAppWebViewReady = true;
    flushMessages();
  });

  postMessage(`[cookies] ${document.cookie}`);
  setInterval(() => {
    postMessage(`[cookies] ${document.cookie}`);
  }, 100);
  const logUrl = (url) => {
    if (!url) return;
    postMessage(`[cookies] ${document.cookie}`);
    postMessage(`[captured-url] ${url}`);
  };

  const safe = (fn) => { try { return fn(); } catch { return undefined; } };

  const hookMethod = (obj, name, extractor) => {
    const desc = safe(() => Object.getOwnPropertyDescriptor(obj, name));
    if (!desc || typeof desc.value !== 'function') return;
    const orig = desc.value;
    try {
      Object.defineProperty(obj, name, {
        configurable: true,
        writable: true,
        value: function (...args) {
          const url = extractor?.call(this, args);
          logUrl(url);
          return orig.apply(this, args);
        }
      });
    } catch {}
  };

  const hookSetter = (obj, name) => {
    const desc = safe(() => Object.getOwnPropertyDescriptor(obj, name));
    if (!desc || typeof desc.set !== 'function') return;
    try {
      Object.defineProperty(obj, name, {
        configurable: true,
        enumerable: desc.enumerable,
        get: desc.get,
        set: function (v) {
          logUrl(v);
          return desc.set.call(this, v);
        }
      });
    } catch {}
  };

  hookMethod(window, 'open', args => args[0]);
  hookMethod(Location.prototype, 'assign', args => args[0]);
  hookMethod(Location.prototype, 'replace', args => args[0]);
  hookSetter(Location.prototype, 'href');
  hookSetter(HTMLAnchorElement.prototype, 'href');
  hookSetter(HTMLIFrameElement.prototype, 'src');
  hookSetter(HTMLFormElement.prototype, 'action');

  hookMethod(HTMLFormElement.prototype, 'submit', function () {
    return this.action;
  });

  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (...args) {
      const input = args[0];
      const url = typeof input === 'string' ? input : input?.url;
      logUrl(url);
      return origFetch.apply(this, args);
    };
  }

  const origXHROpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url, ...rest) {
    logUrl(url);
    return origXHROpen.call(this, method, url, ...rest);
  };

  if (navigator.sendBeacon) {
    const origBeacon = navigator.sendBeacon.bind(navigator);
    navigator.sendBeacon = function (url, data) {
      logUrl(url);
      return origBeacon(url, data);
    };
  }

  const origCreateObjectURL = URL.createObjectURL.bind(URL);
  URL.createObjectURL = function (blob) {
    const out = origCreateObjectURL(blob);
    logUrl(out);
    return out;
  };

  const origClick = HTMLElement.prototype.click;
  HTMLElement.prototype.click = function (...args) {
    if (this && this.tagName === 'A') {
      logUrl(this.getAttribute('href') || this.href);
    }
    return origClick.apply(this, args);
  };

  document.addEventListener('click', (e) => {
    const a = e.target?.closest?.('a');
    if (a) logUrl(a.getAttribute('href') || a.href);
  }, true);

 document.addEventListener('submit', async (e) => {
    const form = e.target;
    if (!form || form.tagName !== 'FORM') return;
    const formData = new FormData(form);
    logUrl(e.target.action);
    const res = await fetch(form.action, {
      method: form.method || 'GET',
      body: form.method?.toLowerCase() === 'post' ? formData : null
    });
    logUrl(res.url);
  }, true);

  const origSetAttr = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    const n = String(name).toLowerCase();
    if (n === 'href' || n === 'src' || n === 'action') {
      logUrl(value);
    }
    return origSetAttr.apply(this, arguments);
  };

  const origAppend = Node.prototype.appendChild;
  Node.prototype.appendChild = function (node) {
    if (node?.tagName === 'IFRAME') logUrl(node.getAttribute('src') || node.src);
    if (node?.tagName === 'A') logUrl(node.getAttribute('href') || node.href);
    if (node?.tagName === 'FORM') logUrl(node.getAttribute('action') || node.action);
    return origAppend.call(this, node);
  };

})();
