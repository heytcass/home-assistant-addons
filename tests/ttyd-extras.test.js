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
function loadPage({ secure = true, clipboard = 'ok', gesture = true } = {}) {
    const handlers = [];
    const inputs = [];
    const keyHandlers = [];
    const term = {
        parser: { registerOscHandler: (id, fn) => handlers.push({ id, fn, term }) },
        attachCustomKeyEventHandler: (fn) => keyHandlers.push(fn),
        input: (data, wasUserInput) => inputs.push({ data, wasUserInput }),
    };
    const written = [];
    const copied = [];
    const listeners = new Set();
    const toasts = [];
    const intervals = [];

    const doc = {
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
        term,
        document: doc,
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
