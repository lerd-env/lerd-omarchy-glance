// The dashboard's state palette, so the panel reads the same way the web UI
// does: emerald for running, red for failed, yellow for attention, sky for
// idle. Colour is only ever used for state; the mark itself is monochrome.
var ok = "#10b981";
var warn = "#facc15";
var bad = "#ef4444";
var idle = "#0ea5e9";
var muted = "#6b7280";

function levelColor(level) {
  if (level === "down") return bad;
  if (level === "warn") return warn;
  return ok;
}

function serviceColor(row) {
  if (row.up) return ok;
  return row.broken ? bad : muted;
}

function flagColor(on) {
  return on ? ok : bad;
}

// Nerd Font glyphs for the worker kinds, and the dashboard's per-kind colours.
var WORKER_GLYPHS = {
  queue: "\uf0ae",
  horizon: "\uf085",
  schedule: "\uf017",
  reverb: "\uf09e",
  stripe: "\uf09d",
  framework: "\uf0e7"
};

var WORKER_COLORS = {
  queue: "#f59e0b",
  horizon: "#f59e0b",
  schedule: ok,
  reverb: idle,
  stripe: "#8b5cf6",
  framework: "#6366f1"
};

function workerGlyph(kind) {
  return WORKER_GLYPHS[kind] || "";
}

var WORKER_LABELS = {
  queue: "Queue",
  horizon: "Horizon",
  schedule: "Schedule",
  reverb: "Reverb",
  stripe: "Stripe",
  framework: "Framework"
};

function workerLabel(kind) {
  return WORKER_LABELS[kind] || kind;
}

function workerColor(count) {
  if (count.running === 0) return muted;
  return WORKER_COLORS[count.kind] || ok;
}
