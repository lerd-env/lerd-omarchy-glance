// Which request a row in the panel turns into. Kept free of QML imports so
// the rules can be tested under node, the same way Model.js is: the mistakes
// worth catching here are all in the addressing, and none of them are visible
// on screen.
//
// Every mutation lerd exposes is a POST that carries the X-Lerd-CSRF header;
// the value is ignored, its presence is what clears lerd's cross-origin gate.
// The reply is always HTTP 200, even for a refusal, so the verdict has to be
// read out of the body — see verdict() at the bottom.

function request(path, label, icon) {
  return { method: "POST", path: path, key: "POST " + path, label: label, icon: icon };
}

// Sites are addressed by domain: lerd looks them up with FindSiteByDomain, and
// a site's name is not always its domain — scopey-env-2 answers on
// scopey-dev.test.
function forSite(site, action) {
  if (!site || !site.domain) return null;
  var paused = site.state === "paused";
  if (action === "pause") {
    if (paused) return null;
    return request("/api/sites/" + site.domain + "/pause", "Pause site", "pause");
  }
  if (action === "unpause") {
    if (!paused) return null;
    return request("/api/sites/" + site.domain + "/unpause", "Resume site", "play");
  }
  if (action === "restart") {
    if (paused) return null;
    return request("/api/sites/" + site.domain + "/restart", "Restart site", "restart");
  }
  return null;
}

// The verbs a site row offers, in the order they are drawn. A paused site can
// only be resumed; restarting one would start a site the user just stopped.
function siteActions(site) {
  var out = [];
  var candidates = site && site.state === "paused" ? ["unpause"] : ["restart", "pause"];
  for (var i = 0; i < candidates.length; i++) {
    var req = forSite(site, candidates[i]);
    if (req) out.push(req);
  }
  return out;
}

// A worker unit is listed by /api/services, but the services endpoint only
// accepts "stop" for one — starting it is a site verb. Both go through the
// site, which owns the whole set, so the row has one addressing rule and not
// two. Framework workers (Vite and friends) have their own generic verb
// because their unit name varies by framework.
function forWorker(row, start) {
  if (!row || !row.domain || !row.kind) return null;
  var verb = start ? "start" : "stop";
  var action;
  if (row.kind === "framework") {
    if (!row.worker) return null;
    action = "worker:" + row.worker + ":" + verb;
  } else {
    action = row.kind + ":" + verb;
  }
  // A worktree unit is lerd-<worker>-<site>-<wt>; the site endpoint reaches it
  // with ?branch=, and without one it resolves to the parent's unit instead.
  var query = row.worktree ? "?branch=" + encodeURIComponent(row.worktree) : "";
  return request("/api/sites/" + row.domain + "/" + action + query,
    start ? "Start worker" : "Stop worker",
    start ? "play" : "stop");
}

function workerActions(row) {
  var req = forWorker(row, !(row && row.up));
  return req ? [req] : [];
}

// Shared services take their verbs on their own endpoint, by name.
function forService(row, action) {
  if (!row || !row.name || row.group === "worker") return null;
  if (action === "start" && row.up) return null;
  if (action === "stop" && !row.up) return null;
  if (["start", "stop", "restart"].indexOf(action) < 0) return null;
  var labels = { start: "Start service", stop: "Stop service", restart: "Restart service" };
  var icons = { start: "play", stop: "stop", restart: "restart" };
  return request("/api/services/" + row.name + "/" + action, labels[action], icons[action]);
}

// Restart is offered either way: it is the usual answer to a service that
// failed, not only to one that is running.
function serviceActions(row) {
  var out = [];
  var candidates = row && row.up ? ["restart", "stop"] : ["start", "restart"];
  for (var i = 0; i < candidates.length; i++) {
    var req = forService(row, candidates[i]);
    if (req) out.push(req);
  }
  return out;
}

function heal() {
  return request("/api/workers/heal", "Heal workers", "heart-pulse");
}

function cleanup() {
  return request("/api/disk", "Clean up", "broom");
}

// lerd answers 200 even when it refused, so the body is the verdict. Most
// endpoints reply with one JSON object; heal streams NDJSON, and there the
// last line is the one that says how it ended.
function verdict(text) {
  var body = parseObject(text);
  if (!body) return { ok: true };
  if (body.ok === false) return { ok: false, error: body.error || "failed" };
  if (body.error) return { ok: false, error: body.error };
  return { ok: true };
}

function parseObject(text) {
  text = String(text === undefined || text === null ? "" : text).replace(/^\s+|\s+$/g, "");
  if (text === "") return null;
  try {
    return JSON.parse(text);
  } catch (e) {
    // Not a single object: fall through and read the stream's last line.
  }
  var lines = text.split("\n");
  for (var i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].replace(/^\s+|\s+$/g, "");
    if (line === "") continue;
    try {
      return JSON.parse(line);
    } catch (e2) {
      return null;
    }
  }
  return null;
}
