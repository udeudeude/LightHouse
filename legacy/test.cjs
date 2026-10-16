// Standalone legacy-browser regression checks. Run: node legacy/test.cjs
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(require('node:path').join(__dirname, 'index.html'), 'utf8');
const js = html.match(/<script>([\s\S]*?)<\/script>/);
assert(js, 'inline legacy script exists');
assert(!/\b(const|let|class)\s+\w+|=>|\?\.|\basync\s+function\b/.test(js[1]), 'ES5-compatible script');
const elements = {};
function element(id) {
  return elements[id] ||= {
    value: id === 'ppm' ? '4' : 'none',
    style: {},
    innerHTML: '',
    addEventListener() {},
    getBoundingClientRect() { return { left: 0, top: 0 }; }
  };
}
const ctx = {
  fillRect() {}, strokeRect() {}, beginPath() {}, moveTo() {}, lineTo() {},
  closePath() {}, fill() {}, stroke() {}, save() {}, restore() {},
  translate() {}, rotate() {}
};
const canvas = element('c');
canvas.getContext = () => ctx;
const saved = {};
const sandbox = {
  document: {
    getElementById: element,
    createElement() { return { click() {}, style: {} }; },
    body: { appendChild() {}, removeChild() {} }
  },
  navigator: { userAgent: 'Mozilla/5.0 (iPad; CPU OS 9_3_5 like Mac OS X)' },
  localStorage: {
    setItem(k, v) { saved[k] = v; },
    getItem(k) { return saved[k] || null; }
  },
  window: { innerWidth: 1024, innerHeight: 768, addEventListener() {} },
  Math, Date, JSON, Number, Object, Array, RegExp, isFinite, parseFloat,
  alert() {}, confirm() { return true; }, prompt() { return null; },
  setTimeout() {}
};
vm.runInNewContext(js[1], sandbox, { timeout: 2000 });
function click(id) { assert.equal(typeof element(id).onclick, 'function', id); element(id).onclick(); }
function state() { return JSON.parse(saved['abandoned-lighthouse-v1']); }
assert.equal(canvas.width, 1024);
assert.equal(canvas.height, 768);
assert(Math.abs(state().ppm - 132 / 25.4) < 0.001, 'iPad 2 calibration preset');
click('add');
assert.equal(state().shapes.length, 1);
assert.equal(state().shapes[0].size, 0);
click('size');
assert.equal(state().shapes[0].size, 1);
click('undo');
assert.equal(state().shapes[0].size, 0);
click('redo');
assert.equal(state().shapes[0].size, 1);
click('light');
assert.equal(state().shapes[0].outline, true);
click('flat');
assert.equal(state().shapes[0].flat, true);
click('left');
assert.equal(state().shapes[0].angle, -45);
click('del');
assert.equal(state().shapes.length, 0);
click('undo');
assert.equal(state().shapes.length, 1);
click('snap');
assert.equal(state().snap, true);
click('collision');
assert.equal(element('collision').innerHTML, 'Pushing: on');
console.log('Abandoned Lighthouse legacy regression checks passed');
