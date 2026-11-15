'use strict';

// Tests for claude-terminal/scripts/ttyd-extras.js. Run: node --test tests/
//
// The decoder cases are ported from owine/claude-terminal-home-assistant's
// terminal-clipboard tests. The browser half runs the same file in a vm
// context with a fake window, xterm.js terminal and clipboard, so the code
// the image ships is the code under test.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SOURCE_PATH = path.join(__dirname, '..', 'claude-terminal', 'scripts', 'ttyd-extras.js');
const SOURCE = fs.readFileSync(SOURCE_PATH, 'utf8');
const { decodeOsc52 } = require(SOURCE_PATH);

const b64 = (s) => Buffer.from(s).toString('base64');

// --- decodeOsc52 ---

test('decodes a base64 clipboard write', () => {
    assert.deepStrictEqual(decodeOsc52(`c;${b64('hello world')}`), { kind: 'write', text: 'hello world' });
});

test('decodes UTF-8 correctly', () => {
    const text = 'café — ünicode ✂';
    assert.deepStrictEqual(decodeOsc52(`c;${b64(text)}`), { kind: 'write', text });
});

test('handles an empty selection parameter', () => {
    assert.deepStrictEqual(decodeOsc52(`;${b64('x')}`), { kind: 'write', text: 'x' });
});

// SECURITY: honouring a read request would let any process that can write
// to the terminal read the user's clipboard over the PTY.
test('reports clipboard READ requests as reads', () => {
    assert.deepStrictEqual(decodeOsc52('c;?'), { kind: 'read' });
});

test('rejects oversized payloads', () => {
    assert.deepStrictEqual(decodeOsc52('c;' + 'A'.repeat(1000004)), { kind: 'oversize' });
});

test('accepts a payload exactly at the size cap', () => {
    assert.strictEqual(decodeOsc52('c;' + 'A'.repeat(1000000)).kind, 'write');
});

test('rejects a payload with no separator', () => {
    assert.deepStrictEqual(decodeOsc52('garbage'), { kind: 'invalid' });
});

test('rejects non-base64 payloads', () => {
    assert.deepStrictEqual(decodeOsc52('c;not!valid!base64'), { kind: 'invalid' });
});

test('rejects non-string input', () => {
    assert.deepStrictEqual(decodeOsc52(null), { kind: 'invalid' });
});

// Node's Buffer silently truncates malformed base64 where the browser's atob
// throws; the regex must reject these so both environments agree.
test('rejects base64 whose length is not a multiple of 4', () => {
    assert.deepStrictEqual(decodeOsc52('c;A'), { kind: 'invalid' });
    assert.deepStrictEqual(decodeOsc52('c;AAAAA'), { kind: 'invalid' });
});

test('rejects base64 with padding that does not match the data length', () => {
    assert.deepStrictEqual(decodeOsc52('c;A='), { kind: 'invalid' });
    assert.deepStrictEqual(decodeOsc52('c;=='), { kind: 'invalid' });
});

test('treats an empty payload as an empty write', () => {
    assert.deepStrictEqual(decodeOsc52('c;'), { kind: 'write', text: '' });
});

// --- Browser half: the OSC 52 handler on ttyd's window.term ---

function element() {
    return { style: {}, setAttribute() {}, textContent: '' };
}

// A fake page: window.term with a parser that records registered handlers,
// a clipboard, a document whose execCommand('copy') dispatches a copy event
// to capture listeners (only when `gesture` is true, as browsers do), and
// manual timers.
function loadPage({ secure = true, clipboard = 'ok', gesture = true, withTerm = true } = {}) {
    const handlers = [];
    const inputs = [];
    const keyHandlers = [];
    const winListeners = [];
    const inside = { inTerminal: true };
    const textarea = { tag: 'textarea' };
    let focusCalls = 0;
    const term = {
        parser: { registerOscHandler: (id, fn) => handlers.push({ id, fn, term }) },
        attachCustomKeyEventHandler: (fn) => keyHandlers.push(fn),
        input: (data, wasUserInput) => inputs.push({ data, wasUserInput }),
        element: { contains: (node) => Boolean(node && node.inTerminal) },
        textarea,
        focus: () => { focusCalls++; doc.activeElement = textarea; doc.focused = true; },
    };
    const written = [];
    const copied = [];
    const listeners = new Set();
    const toasts = [];
    const intervals = [];

    const doc = {
        focused: false,
        activeElement: null,
        hasFocus: () => doc.focused,
        body: { appendChild: (el) => toasts.push(el) },
        createElement: element,
        addEventListener: (type, fn) => { if (type === 'copy') listeners.add(fn); },
        removeEventListener: (type, fn) => { if (type === 'copy') listeners.delete(fn); },
        execCommand: (cmd) => {
            if (cmd !== 'copy' || !gesture) return false;
            const event = {
                clipboardData: { setData: (_type, text) => copied.push(text) },
                preventDefault() {},
                stopImmediatePropagation() {},
            };
            listeners.forEach((fn) => fn(event));
            return true;
        },
    };

    const navigatorClipboard = clipboard === 'none' ? undefined : {
        writeText: (text) => {
            written.push(text);
            return clipboard === 'ok' ? Promise.resolve() : Promise.reject(new Error('denied'));
        },
    };

    const win = {
        term: withTerm ? term : undefined,
        document: doc,
        addEventListener: (type, fn, capture) => winListeners.push({ type, fn, capture }),
        isSecureContext: secure,
        navigator: { clipboard: navigatorClipboard },
        setInterval: (fn) => intervals.push(fn),
        setTimeout: () => 0,
        clearTimeout() {},
        atob: (s) => Buffer.from(s, 'base64').toString('latin1'),
        TextDecoder,
        Uint8Array,
        Promise,
    };
    win.self = win;
    vm.runInNewContext(SOURCE, win);

    return {
        win,
        handlers,
        inputs,
        key: (event) => keyHandlers[keyHandlers.length - 1](event),
        written,
        copied,
        toast: () => (toasts[0] ? toasts[0].textContent : null),
        tick: () => intervals.forEach((fn) => fn()),
        osc: (data) => handlers[handlers.length - 1].fn(data),
        doc,
        inside,
        focusCalls: () => focusCalls,
        listeners: (type) => winListeners.filter((l) => l.type === type).map((l) => l.capture === true),
        // Dispatch a window event to the page's listeners. Returns what a
        // listener did to it, so a test can tell whether xterm.js (further
        // down the capture/bubble path) would still have seen it.
        fire: (type, props = {}) => {
            const event = Object.assign({
                type, button: 0, target: inside,
                shiftKey: false, ctrlKey: false, altKey: false, metaKey: false,
                prevented: false, stopped: false,
                preventDefault() { this.prevented = true; },
                stopPropagation() { this.stopped = true; },
            }, props);
            winListeners.filter((l) => l.type === type).forEach((l) => l.fn(event));
            return event;
        },
    };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

test('registers an OSC 52 handler on window.term', () => {
    const page = loadPage();
    assert.strictEqual(page.handlers.length, 1);
    assert.strictEqual(page.handlers[0].id, 52);
});

test('writes decoded text with the async Clipboard API and confirms it', async () => {
    const page = loadPage();
    assert.strictEqual(page.osc(`c;${b64('copied text')}`), true);
    await settle();
    assert.deepStrictEqual(page.written, ['copied text']);
    assert.match(page.toast(), /Copied/);
});

test('refuses read requests: nothing written, nothing answered', async () => {
    const page = loadPage();
    assert.strictEqual(page.osc('c;?'), true);
    await settle();
    assert.deepStrictEqual(page.written, []);
    assert.deepStrictEqual(page.copied, []);
    assert.strictEqual(page.toast(), null);
});

test('ignores invalid and empty payloads', async () => {
    const page = loadPage();
    page.osc('c;not!base64');
    page.osc('c;');
    await settle();
    assert.deepStrictEqual(page.written, []);
    assert.strictEqual(page.toast(), null);
});

test('falls back to execCommand outside a secure context (plain HTTP)', async () => {
    const page = loadPage({ secure: false });
    page.osc(`c;${b64('over http')}`);
    await settle();
    assert.deepStrictEqual(page.written, []);
    assert.deepStrictEqual(page.copied, ['over http']);
    assert.match(page.toast(), /Copied/);
});

test('falls back to execCommand when writeText is refused', async () => {
    const page = loadPage({ clipboard: 'denied' });
    page.osc(`c;${b64('retry')}`);
    await settle();
    assert.deepStrictEqual(page.copied, ['retry']);
    assert.match(page.toast(), /Copied/);
});

test('says so, and points at Shift+drag, when the browser blocks both', async () => {
    const page = loadPage({ clipboard: 'denied', gesture: false });
    page.osc(`c;${b64('blocked')}`);
    await settle();
    assert.deepStrictEqual(page.copied, []);
    assert.match(page.toast(), /blocked/);
    assert.match(page.toast(), /Shift/);
});

test('registers again if ttyd replaces window.term, and only once per instance', () => {
    const page = loadPage();
    page.tick();
    assert.strictEqual(page.handlers.length, 1);
    const replacement = {
        parser: { registerOscHandler: (id, fn) => page.handlers.push({ id, fn }) },
        attachCustomKeyEventHandler() {},
    };
    page.win.term = replacement;
    page.tick();
    page.tick();
    assert.strictEqual(page.handlers.length, 2);
});

// --- Shift+Enter ---

const key = (type, k, mods = {}) => Object.assign(
    { type, key: k, shiftKey: false, ctrlKey: false, altKey: false, metaKey: false }, mods);

test('Shift+Enter sends backslash + return instead of submitting', () => {
    const page = loadPage();
    assert.strictEqual(page.key(key('keydown', 'Enter', { shiftKey: true })), false);
    assert.deepStrictEqual(page.inputs, [{ data: '\\\r', wasUserInput: true }]);
});

test('Shift+Enter keypress and keyup are claimed without sending anything more', () => {
    const page = loadPage();
    assert.strictEqual(page.key(key('keypress', 'Enter', { shiftKey: true })), false);
    assert.strictEqual(page.key(key('keyup', 'Enter', { shiftKey: true })), false);
    assert.deepStrictEqual(page.inputs, []);
});

test('plain Enter and other modifier combinations go through untouched', () => {
    const page = loadPage();
    assert.strictEqual(page.key(key('keydown', 'Enter')), true);
    assert.strictEqual(page.key(key('keydown', 'Enter', { shiftKey: true, ctrlKey: true })), true);
    assert.strictEqual(page.key(key('keydown', 'Enter', { shiftKey: true, altKey: true })), true);
    assert.strictEqual(page.key(key('keydown', 'Enter', { shiftKey: true, metaKey: true })), true);
    assert.strictEqual(page.key(key('keydown', 'a', { shiftKey: true })), true);
    assert.deepStrictEqual(page.inputs, []);
});

// --- Focusing click (#159) ---

test('listens for presses on window in the capture phase', () => {
    // Captured ahead of xterm.js's own mousedown handler on the terminal
    // element, or stopping the event would come too late.
    const page = loadPage();
    assert.deepStrictEqual(page.listeners('mousedown'), [true]);
});

test('the click that focuses the terminal only focuses it', () => {
    const page = loadPage();
    const event = page.fire('mousedown');
    assert.strictEqual(event.prevented, true);
    assert.strictEqual(event.stopped, true);
    assert.strictEqual(page.focusCalls(), 1);
});

test('the next click on the focused terminal goes through', () => {
    const page = loadPage();
    page.fire('mousedown');
    const event = page.fire('mousedown');
    assert.strictEqual(event.stopped, false);
    assert.strictEqual(event.prevented, false);
    assert.strictEqual(page.focusCalls(), 1);
});

// Alt+Tab or a click in another app, then a click back into the terminal:
// the textarea may still be the active element, and the browser may report
// focus already, but the click is still the one that brought the page back.
test('a click after the page lost focus is swallowed even if focus looks intact', () => {
    const page = loadPage();
    page.fire('mousedown');
    page.fire('blur');
    assert.strictEqual(page.doc.hasFocus(), true);
    assert.strictEqual(page.fire('mousedown').stopped, true);
    assert.strictEqual(page.fire('mousedown').stopped, false);
});

test('typing after coming back means the next click goes through', () => {
    const page = loadPage();
    page.fire('mousedown');
    page.fire('blur');
    page.fire('keydown');
    assert.strictEqual(page.fire('mousedown').stopped, false);
});

test('a click while the terminal is not the focused element is swallowed', () => {
    const page = loadPage();
    page.fire('mousedown');
    page.doc.activeElement = null;
    assert.strictEqual(page.fire('mousedown').stopped, true);
});

test('Shift, Option, Ctrl and Cmd clicks always go through (forced selection)', () => {
    for (const mod of ['shiftKey', 'altKey', 'ctrlKey', 'metaKey']) {
        const page = loadPage();
        const event = page.fire('mousedown', { [mod]: true });
        assert.strictEqual(event.stopped, false, mod);
        assert.strictEqual(event.prevented, false, mod);
    }
});

test('right and middle clicks go through', () => {
    for (const button of [1, 2]) {
        const page = loadPage();
        assert.strictEqual(page.fire('mousedown', { button }).stopped, false);
    }
});

test('clicks outside the terminal are left alone', () => {
    const page = loadPage();
    assert.strictEqual(page.fire('mousedown', { target: { inTerminal: false } }).stopped, false);
    assert.strictEqual(page.focusCalls(), 0);
});

test('does nothing before ttyd has created window.term', () => {
    const page = loadPage({ withTerm: false });
    const event = page.fire('mousedown');
    assert.strictEqual(event.stopped, false);
    assert.strictEqual(event.prevented, false);
});
