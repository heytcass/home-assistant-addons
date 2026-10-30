// Browser-side additions to ttyd's own page. build-ttyd-index.sh injects
// this file as the one <script> added to ttyd 1.7.7's built-in index.html
// at image build time, and run.sh serves the result with `ttyd --index`.
// Nothing else in ttyd's page is changed: keep it that way, and keep this
// file small and dependency-free.
//
// OSC 52 (#125): tmux's drag-copy binding and Claude Code's own copy both
// send the text out as an OSC 52 escape sequence, but ttyd registers no
// handler for it, so xterm.js dropped the sequence and nothing reached the
// browser clipboard. This registers one on ttyd's xterm.js instance
// (window.term). Clipboard READ requests (`52;c;?`) are refused: answering
// them would let any process that can write to the terminal read the
// user's clipboard.
//
// Shift+Enter: xterm.js sends a plain carriage return for it, so Claude
// Code submits the prompt. Claude's /terminal-setup can't fix that here (it
// only knows desktop terminal apps), so send backslash + return instead,
// which Claude Code reads as "insert a newline" (and bash as a line
// continuation).
//
// The decoder and key filter are pure and exported for the Node tests in
// tests/.
(function (root) {
    'use strict';

    // Cap on one clipboard write, in base64 characters (~750 KB of text)
    var OSC52_MAX = 1000000;

    // Strict base64: a multiple of 4, padding only where the length needs it.
    // This regex is the only validation. Node's Buffer (used by the tests)
    // silently truncates malformed input while the browser's atob throws, so
    // anything looser would let the tests accept input the browser rejects.
    var BASE64 = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

    function b64ToBytes(b64) {
        if (typeof Buffer !== 'undefined') return Uint8Array.from(Buffer.from(b64, 'base64'));
        return Uint8Array.from(atob(b64), function (c) { return c.charCodeAt(0); });
    }

    // Decode an OSC 52 payload, `<selection>;<base64 | '?'>`. Returns
    // { kind: 'write', text } | { kind: 'read' } | { kind: 'oversize' } |
    // { kind: 'invalid' }. Invalid UTF-8 decodes lossily to U+FFFD.
    function decodeOsc52(data) {
        if (typeof data !== 'string') return { kind: 'invalid' };
        var i = data.indexOf(';');
        if (i === -1) return { kind: 'invalid' };

        var payload = data.slice(i + 1);
        if (payload === '?') return { kind: 'read' };
        if (payload.length > OSC52_MAX) return { kind: 'oversize' };
        if (!BASE64.test(payload)) return { kind: 'invalid' };

        try {
            return { kind: 'write', text: new TextDecoder().decode(b64ToBytes(payload)) };
        } catch (e) {
            return { kind: 'invalid' };
        }
    }

    // Shift+Enter alone (no Ctrl/Alt/Meta). Every event of that chord is
    // claimed so xterm.js never also sends its own CR; only keydown inputs.
    function isShiftEnter(event) {
        return event.key === 'Enter' && event.shiftKey &&
            !event.ctrlKey && !event.altKey && !event.metaKey;
    }

    var SHIFT_ENTER_INPUT = '\\\r';

    var api = { decodeOsc52: decodeOsc52, isShiftEnter: isShiftEnter, SHIFT_ENTER_INPUT: SHIFT_ENTER_INPUT };
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
        return;
    }

    // --- Browser only below ---

    var win = root;
    var doc = win.document;

    // Fallback for when the async Clipboard API is missing (plain-HTTP Home
    // Assistant: not a secure context) or refuses. execCommand('copy') fires
    // a copy event; answering it here, ahead of xterm.js's own handler,
    // puts our text on the clipboard without moving focus out of the
    // terminal. Browsers only allow it shortly after a user gesture, which
    // the mouse release or keypress behind a copy usually is.
    function copyWithExecCommand(text) {
        var done = false;
        function onCopy(event) {
            event.clipboardData.setData('text/plain', text);
            event.preventDefault();
            event.stopImmediatePropagation();
            done = true;
        }
        doc.addEventListener('copy', onCopy, true);
        try {
            doc.execCommand('copy');
        } catch (e) {
            // Treated as not copied
        }
        doc.removeEventListener('copy', onCopy, true);
        return done;
    }

    function writeClipboard(text) {
        var clipboard = win.navigator.clipboard;
        if (win.isSecureContext && clipboard && typeof clipboard.writeText === 'function') {
            return clipboard.writeText(text).then(
                function () { return true; },
                function () { return copyWithExecCommand(text); }
            );
        }
        return Promise.resolve(copyWithExecCommand(text));
    }

    // One small message in the corner, replacing tmux's old "Not copied"
    // status-line hint now that the page knows whether a copy landed
    var toast = null;
    var toastTimer = 0;
    function notify(message, ok) {
        if (!toast) {
            toast = doc.createElement('div');
            toast.setAttribute('role', 'status');
            toast.style.cssText = 'position:fixed;right:12px;bottom:12px;z-index:10;' +
                'padding:6px 10px;border-radius:4px;font:13px sans-serif;' +
                'background:#1a1b26;pointer-events:none;transition:opacity .3s;';
            doc.body.appendChild(toast);
        }
        toast.textContent = message;
        toast.style.color = ok ? '#c0caf5' : '#e0af68';
        toast.style.border = '1px solid ' + (ok ? '#414868' : '#d97757');
        toast.style.opacity = '1';
        win.clearTimeout(toastTimer);
        toastTimer = win.setTimeout(function () { toast.style.opacity = '0'; }, ok ? 1500 : 5000);
    }

    function onOsc52(data) {
        var result = decodeOsc52(data);
        if (result.kind === 'write' && result.text) {
            writeClipboard(result.text).then(function (ok) {
                notify(ok ? 'Copied to clipboard'
                    : 'The browser blocked the copy. Hold Shift (Option on Mac) while dragging instead.', ok);
            });
        }
        // Everything else (read requests, empty or invalid payloads) is
        // swallowed: nothing reaches the clipboard and nothing is answered.
        return true;
    }

    // ttyd creates window.term once its page has mounted, and the instance
    // has outlived reconnects so far; checking for a new one stays cheap
    // insurance against that changing.
    var registered = null;
    function attach() {
        var term = win.term;
        if (!term || term === registered || !term.parser) return;
        registered = term;
        term.parser.registerOscHandler(52, onOsc52);
        term.attachCustomKeyEventHandler(function (event) {
            if (!isShiftEnter(event)) return true;
            if (event.type === 'keydown') term.input(SHIFT_ENTER_INPUT, true);
            return false;
        });
    }
    attach();
    win.setInterval(attach, 1000);

    win.ClaudeTerminal = api;
})(typeof self !== 'undefined' ? self : this);
