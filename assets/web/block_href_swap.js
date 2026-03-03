(() => {
  'use strict';

  const CFG = {
    blockedHostPatterns: [
      /doubleclick\.net/i,
      /googlesyndication\.com/i,
      /googleadservices\.com/i,
      /adservice/i,
      /adsystem/i,
      /adnxs\.com/i,
      /taboola\.com/i,
      /outbrain\.com/i,
      /mgid\.com/i,
      /popads/i,
      /propellerads/i,
      /adsterra/i,
      /tracking/i,
      /trk/i,
      /affiliat/i
    ],
    blockedParamKeys: [
      'url','u','redirect','redir','r','target','dest','destination','goto','out'
    ]
  };

  const original = new WeakMap();

  const safeUrl = (href) => {
    try { return new URL(href, location.href); }
    catch { return null; }
  };

  const isBlocked = (href, base) => {
    if (!href || href === base) return false;
    const u = safeUrl(href);
    if (!u) return true;
    if (CFG.blockedHostPatterns.some(r => r.test(u.hostname))) return true;
    for (const k of CFG.blockedParamKeys) {
      if (u.searchParams.has(k)) return true;
    }
    return false;
  };

  const remember = (a) => {
    if (!original.has(a)) {
      const h = a.getAttribute('href');
      if (h) original.set(a, h);
    }
  };

  const protectAnchor = (a) => {
    if (!a || original.has(a)) return;
    const h = a.getAttribute('href');
    if (!h) return;
    original.set(a, h);
    try {
      Object.defineProperty(a, 'href', {
        configurable: false,
        enumerable: true,
        get() { return h; },
        set(v) {
          if (!isBlocked(v, h)) {
            original.set(a, v);
          }
        }
      });
    } catch {}
  };

  const origSetAttr = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function(name, value) {
    if (this.tagName === 'A' && name.toLowerCase() === 'href') {
      const base = original.get(this) || this.getAttribute('href');
      if (base && isBlocked(value, base)) return;
      if (!original.has(this)) original.set(this, value);
    }
    return origSetAttr.apply(this, arguments);
  };

  const desc = Object.getOwnPropertyDescriptor(HTMLAnchorElement.prototype, 'href');
  if (desc && desc.configurable) {
    Object.defineProperty(HTMLAnchorElement.prototype, 'href', {
      configurable: false,
      enumerable: desc.enumerable,
      get: desc.get,
      set(value) {
        const base = original.get(this) || desc.get.call(this);
        if (base && isBlocked(value, base)) return;
        desc.set.call(this, value);
      }
    });
  }

  document.querySelectorAll('a[href]').forEach(protectAnchor);

  const mo = new MutationObserver(muts => {
    for (const m of muts) {
      if (m.type === 'childList') {
        m.addedNodes.forEach(n => {
          if (n.nodeType === 1) {
            if (n.tagName === 'A') protectAnchor(n);
            n.querySelectorAll?.('a[href]').forEach(protectAnchor);
          }
        });
      }
      if (m.type === 'attributes' && m.target.tagName === 'A') {
        const a = m.target;
        const base = original.get(a);
        if (!base) return;
        const cur = a.getAttribute('href');
        if (isBlocked(cur, base)) {
          origSetAttr.call(a, 'href', base);
        }
      }
    }
  });

  mo.observe(document.documentElement, {
    subtree: true,
    childList: true,
    attributes: true,
    attributeFilter: []
  });

})();