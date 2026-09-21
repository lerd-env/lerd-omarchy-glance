// The dashboard's state palette, so the panel reads the same way the web UI
// does: emerald for running, red for failed, yellow for attention, sky for
// idle. Colour is only ever used for state; the mark itself is monochrome.
//
// Two sets of the same hues, because the popup card takes its background from
// the Omarchy theme: the bright set drops to 1.5:1 on a light card, so a light
// surface gets the darker shades of the same colours instead.
var DARK = {
  ok: "#10b981",
  warn: "#facc15",
  bad: "#ef4444",
  idle: "#0ea5e9",
  muted: "#6b7280",
  workers: {
    queue: "#f59e0b",
    horizon: "#f59e0b",
    schedule: "#10b981",
    reverb: "#0ea5e9",
    stripe: "#8b5cf6",
    framework: "#6366f1"
  }
};

var LIGHT = {
  ok: "#047857",
  warn: "#a16207",
  bad: "#b91c1c",
  idle: "#0369a1",
  muted: "#4b5563",
  workers: {
    queue: "#b45309",
    horizon: "#b45309",
    schedule: "#047857",
    reverb: "#0369a1",
    stripe: "#6d28d9",
    framework: "#4338ca"
  }
};

function palette(light) {
  return light ? LIGHT : DARK;
}

function levelColor(level, light) {
  var p = palette(light);
  if (level === "down") return p.bad;
  if (level === "warn") return p.warn;
  return p.ok;
}

function serviceColor(row, light) {
  var p = palette(light);
  if (row.up) return p.ok;
  return row.broken ? p.bad : p.muted;
}

function flagColor(on, light) {
  var p = palette(light);
  return on ? p.ok : p.bad;
}

// Sites: emerald up, red down, sky suspended (idle), grey paused.
function siteStateColor(state, light) {
  var p = palette(light);
  if (state === "up") return p.ok;
  if (state === "down") return p.bad;
  if (state === "suspended") return p.idle;
  return p.muted;
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

function workerKindColor(kind, running, light) {
  var p = palette(light);
  if (running === false) return p.muted;
  return p.workers[kind] || p.ok;
}

// Glyphs for the panel's own chrome (all present in the Nerd Font).
var ICONS = {
  "play": "\uf04b",
  "pause": "\uf04c",
  "stop": "\uf04d",
  "restart": "\uf021",
  "heart-pulse": "\u{F05F6}",
  "spinner": "\uf110",
  "view-table": "\u{F0569}",     // nf-md-table_large: the dense table view
  "view-columns": "\u{F0571}",   // nf-md-view_column: the three-column view
  "caret-down": "\uf0d7",
  "caret-right": "\uf0da",
  "external-link": "\uf08e",
  "broom": "\u{F00E2}"
};

function icon(name) {
  return ICONS[name] || "";
}
