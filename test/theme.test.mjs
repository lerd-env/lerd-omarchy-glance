import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Same trick as model.test.mjs: Theme.js is a plain script for QML, so the
// source is evaluated here rather than imported.
const source = readFileSync(new URL("../Theme.js", import.meta.url), "utf8");
const Theme = new Function(
  source + "; return { palette, levelColor, serviceColor, flagColor, siteStateColor, workerKindColor };"
)();

// Relative luminance and contrast ratio, WCAG 2.1.
function luminance(hex) {
  const channel = (v) => {
    const c = parseInt(hex.slice(v, v + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
}

function contrast(hex, backgroundHex) {
  const a = luminance(hex);
  const b = luminance(backgroundHex);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

test("the dark set is the dashboard's palette", () => {
  assert.equal(Theme.levelColor("ok"), "#10b981");
  assert.equal(Theme.levelColor("warn"), "#facc15");
  assert.equal(Theme.levelColor("down"), "#ef4444");
});

test("a light surface takes the darker set", () => {
  assert.equal(Theme.levelColor("ok", true), "#047857");
  assert.equal(Theme.levelColor("warn", true), "#a16207");
  assert.equal(Theme.levelColor("down", true), "#b91c1c");
});

test("every state colour clears 3:1 on its own surface", () => {
  for (const [light, background] of [[false, "#101315"], [true, "#ffffff"]]) {
    const p = Theme.palette(light);
    const colors = [p.ok, p.warn, p.bad, p.idle, p.muted].concat(Object.values(p.workers));
    for (const color of colors) {
      assert.ok(
        contrast(color, background) >= 3,
        `${color} is ${contrast(color, background).toFixed(2)}:1 on ${background}`
      );
    }
  }
});

test("a service that is down but not broken is muted, not red", () => {
  assert.equal(Theme.serviceColor({ up: false, broken: false }, true), Theme.palette(true).muted);
  assert.equal(Theme.serviceColor({ up: false, broken: true }, true), Theme.palette(true).bad);
});

test("a stopped worker is muted on either surface", () => {
  assert.equal(Theme.workerKindColor("queue", false), "#6b7280");
  assert.equal(Theme.workerKindColor("queue", false, true), "#4b5563");
});

test("an unknown worker kind falls back to the running colour", () => {
  assert.equal(Theme.workerKindColor("octane", true, true), Theme.palette(true).ok);
});

test("sites and flags read from the same set", () => {
  assert.equal(Theme.siteStateColor("suspended", true), Theme.palette(true).idle);
  assert.equal(Theme.flagColor(false, true), Theme.palette(true).bad);
});
