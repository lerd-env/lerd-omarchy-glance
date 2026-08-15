// Reduces the lerd dashboard endpoints into the handful of numbers the bar and
// panel show. Deliberately free of QML imports so the tests can run it under
// node without a shell.

function serviceUp(status) {
  return status === "active" || status === "running";
}

function serviceBroken(status) {
  return status === "failed";
}

function siteState(site) {
  if (site.paused) return "paused";
  if (site.idle_suspended) return "suspended";
  return site.fpm_running ? "up" : "down";
}

// lerd decides what an unhealthy worker is; a site merely declaring a queue
// worker says nothing about whether it should be running right now.
var WORKER_STATES = {
  "failed": "failed",
  "expected-but-stopped": "stopped",
  "unreachable": "not responding",
  "orphaned": "orphaned"
};

function unhealthyWorkers(health) {
  var list = (health && health.unhealthy) || [];
  var out = [];
  for (var i = 0; i < list.length; i++) {
    out.push({
      site: list[i].site,
      worker: list[i].worker,
      state: WORKER_STATES[list[i].state] || list[i].state
    });
  }
  return out;
}

function formatBytes(bytes) {
  if (!bytes) return "0 MB";
  var mb = bytes / 1048576;
  if (mb < 1024) return Math.round(mb) + " MB";
  return (mb / 1024).toFixed(1) + " GB";
}

// Container names are all prefixed with the install, which is noise in a list
// that is already inside the lerd panel.
function shortName(name) {
  return name.indexOf("lerd-") === 0 ? name.slice(5) : name;
}

function resources(stats) {
  stats = stats || {};
  var containers = stats.containers || [];
  var rows = [];
  for (var i = 0; i < containers.length; i++) {
    var c = containers[i];
    rows.push({
      name: shortName(c.name),
      cpu: c.cpu_percent || 0,
      memBytes: c.mem_bytes || 0,
      memLabel: formatBytes(c.mem_bytes || 0)
    });
  }
  rows.sort(function(a, b) { return b.memBytes - a.memBytes; });

  var mem = stats.total_mem_bytes || 0;
  var host = stats.host_mem_bytes || 0;
  return {
    available: stats.available !== false,
    count: containers.length,
    cpu: stats.total_cpu_percent || 0,
    cpuBar: Math.min(100, stats.total_cpu_percent || 0),
    memBytes: mem,
    memLabel: formatBytes(mem),
    memPercent: host > 0 ? (mem / host) * 100 : 0,
    hostLabel: formatBytes(host),
    top: rows.slice(0, 4)
  };
}

// Worker kinds a site can declare, in the order the panel shows them. Framework
// workers are counted together under their own kind because a site can declare
// several and their names vary by framework.
var WORKER_KINDS = [
  ["queue", "has_queue_worker", "queue_running"],
  ["horizon", "has_horizon", "horizon_running"],
  ["schedule", "has_schedule_worker", "schedule_running"],
  ["reverb", "has_reverb", "reverb_running"],
  ["stripe", "stripe_secret_set", "stripe_running"]
];

function workerCounts(sites) {
  sites = sites || [];
  var tally = {}, order = [];

  function add(kind, running) {
    if (!tally[kind]) {
      tally[kind] = { kind: kind, running: 0, total: 0 };
      order.push(kind);
    }
    tally[kind].total++;
    if (running) tally[kind].running++;
  }

  for (var i = 0; i < sites.length; i++) {
    var site = sites[i];
    if (site.paused) continue;
    for (var k = 0; k < WORKER_KINDS.length; k++) {
      var kind = WORKER_KINDS[k];
      if (site[kind[1]]) add(kind[0], site[kind[2]]);
    }
    var extra = site.framework_workers || [];
    for (var f = 0; f < extra.length; f++) add("framework", extra[f].running);
  }

  var out = [];
  for (var o = 0; o < order.length; o++) out.push(tally[order[o]]);
  return out;
}

// Everything lerd's cleanup would reclaim, so the panel can offer the button
// only when there is actually something to remove.
function cleanup(disk) {
  disk = disk || {};
  var bytes = disk.reclaimable_bytes || 0;
  return {
    available: disk.available !== false && bytes > 0,
    bytes: bytes,
    label: formatBytes(bytes),
    count: (disk.images || []).length
  };
}

function summarize(payload) {
  payload = payload || {};
  var status = payload.status, services = payload.services, version = payload.version;
  var sitesUp = 0, sitesTotal = 0;
  var sites = payload.sites || [];
  for (var i = 0; i < sites.length; i++) {
    var state = siteState(sites[i]);
    if (state === "paused") continue;
    sitesTotal++;
    if (state === "up") sitesUp++;
  }
  var workers = unhealthyWorkers(payload.health);

  var servicesUp = 0, servicesDown = [], serviceRows = [];
  services = services || [];
  for (var j = 0; j < services.length; j++) {
    var svc = services[j];
    var up = serviceUp(svc.status);
    if (up) servicesUp++;
    else servicesDown.push({ name: svc.name, status: svc.status, broken: serviceBroken(svc.status) });
    serviceRows.push({
      name: svc.name,
      status: svc.status,
      up: up,
      broken: serviceBroken(svc.status),
      version: svc.version || "",
      port: svc.port || 0,
      sites: svc.site_count || 0
    });
  }

  status = status || {};
  var php = [];
  var fpms = status.php_fpms || [];
  for (var k = 0; k < fpms.length; k++) {
    php.push({ version: fpms[k].version, running: !!fpms[k].running });
  }

  var nginx = !!(status.nginx && status.nginx.running);
  var dns = !!(status.dns && status.dns.ok);

  version = version || {};

  return {
    reachable: true,
    sites: { up: sitesUp, total: sitesTotal },
    services: { up: servicesUp, total: services.length, down: servicesDown, list: serviceRows },
    workers: { down: workers, kinds: workerCounts(sites) },
    php: php,
    nginx: nginx,
    dns: dns,
    watcher: !!status.watcher_running,
    phpDefault: status.php_default || "",
    nodeDefault: status.node_default || "",
    tld: (status.dns && status.dns.tld) || "test",
    resources: resources(payload.stats),
    cleanup: cleanup(payload.disk),
    update: {
      current: version.current || "",
      latest: version.latest || "",
      available: !!version.has_update
    },
    level: level(nginx, dns, servicesDown, workers)
  };
}

function level(nginx, dns, servicesDown, workers) {
  if (!nginx) return "down";
  if (!dns || workers.length > 0 || servicesDown.length > 0) return "warn";
  return "ok";
}

function unreachable() {
  return {
    reachable: false,
    sites: { up: 0, total: 0 },
    services: { up: 0, total: 0, down: [], list: [] },
    workers: { down: [], kinds: [] },
    php: [],
    nginx: false,
    dns: false,
    watcher: false,
    phpDefault: "",
    nodeDefault: "",
    tld: "test",
    resources: resources(null),
    cleanup: cleanup(null),
    update: { current: "", latest: "", available: false },
    level: "down"
  };
}

// One line per problem, in the order the panel lists them.
function issues(summary) {
  if (!summary.reachable) return ["lerd is not running"];
  var out = [];
  if (!summary.nginx) out.push("nginx is not running");
  if (!summary.dns) out.push("." + summary.tld + " resolution is down");
  for (var i = 0; i < summary.services.down.length; i++) {
    var svc = summary.services.down[i];
    out.push(svc.name + " " + (svc.broken ? "failed" : "stopped"));
  }
  for (var j = 0; j < summary.workers.down.length; j++) {
    var w = summary.workers.down[j];
    out.push(w.site + " " + w.worker + " " + w.state);
  }
  return out;
}
