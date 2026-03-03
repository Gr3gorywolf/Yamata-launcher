
// ==UserScript==
// @name         The Simplest Adblocker
// @namespace    https://kawamoto.no-ip.org/
// @version      1.1
// @description  Just removes all cross-origin and dynamically generated iframes.
// @author       Suguru Kawamoto
// @include      *
// @grant        none
// @updateURL    https://kawamoto.no-ip.org/misc/The%20Simplest%20Adblocker.user.js
// @downloadURL  https://kawamoto.no-ip.org/misc/The%20Simplest%20Adblocker.user.js
// ==/UserScript==
(function() {
    'use strict';

    // Your code here...
    let f = function(){
        Array.prototype.forEach.call(document.getElementsByTagName("iframe"), function(e){
            let s = getComputedStyle(e);
            if(s.display != "none" && s.visibility == "visible" && s.opacity > 0){
                if(!e.src){
                    while(e.contentWindow.document.firstChild){
                        e.contentWindow.document.removeChild(e.contentWindow.document.firstChild);
                    }
                }else if(new URL(e.src, location.href).hostname != document.domain){
                    e.src = "about:blank";
                }
            }
        });
    };
    new MutationObserver(f).observe(document, {subtree : true, childList : true});
    f();
})();