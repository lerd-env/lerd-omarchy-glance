import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Model.js is loaded by QML as a plain script, so it has no exports to import.
// Evaluating the source keeps the file usable by the shell and by these tests.
const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8");
const Model = new Function(
  source + "; return { summarize, unreachable, issues, siteState, unhealthyWorkers, resources, formatBytes, workerCounts, cleanup, siteRows, serviceGroup, splitServices, domainFor };"
)();

const status = {
  nginx: { running: true },
  dns: { ok: true, status: "ok", tld: "test" },
  php_fpms: [
    { version: "8.3", running: true },
    { version: "8.4", running: true }
  ],
  php_default: "8.4",
  watcher_running: true
};

const site = (over) => ({
  name: "shop",
  domain: "shop.test",
  fpm_running: true,
  paused: false,
  idle: false,
  idle_suspended: false,
  ...over
});

test("counts running sites and services", () => {
  const s = Model.summarize({
    status,
    sites: [site({}), site({ name: "blog", domain: "blog.test", fpm_running: false })],
    services: [{ name: "postgres", status: "active" }, { name: "redis", status: "active" }]
  });
  assert.equal(s.sites.up, 1);
  assert.equal(s.sites.total, 2);
  assert.equal(s.services.up, 2);
  assert.equal(s.level, "ok");
});

test("paused sites leave the count entirely", () => {
  const s = Model.summarize({ status, sites: [site({}), site({ name: "old", paused: true })] });
  assert.equal(s.sites.total, 1);
});

test("workers come from lerd's own health verdict", () => {
  const s = Model.summarize({
    status,
    sites: [site({})],
    health: { unhealthy: [{ site: "shop.test", worker: "queue", state: "failed" }] }
  });
  assert.deepEqual(s.workers.down, [{ site: "shop.test", worker: "queue", state: "failed" }]);
  assert.equal(s.level, "warn");
  assert.deepEqual(Model.issues(s), ["shop.test queue failed"]);
});

test("each worker state gets its own wording", () => {
  const s = Model.summarize({
    status,
    health: {
      unhealthy: [
        { site: "a.test", worker: "queue", state: "expected-but-stopped" },
        { site: "b.test", worker: "reverb", state: "unreachable" },
        { site: "c.test", worker: "horizon", state: "orphaned" }
      ]
    }
  });
  assert.deepEqual(Model.issues(s), [
    "a.test queue stopped",
    "b.test reverb not responding",
    "c.test horizon orphaned"
  ]);
});

test("an empty health report leaves the level at ok", () => {
  const s = Model.summarize({ status, sites: [site({})], health: { unhealthy: [] } });
  assert.deepEqual(s.workers.down, []);
  assert.equal(s.level, "ok");
});

test("a failed service reads as failed, a stopped one as stopped", () => {
  const s = Model.summarize({
    status,
    services: [
      { name: "meilisearch", status: "failed" },
      { name: "mailpit", status: "inactive" }
    ]
  });
  assert.equal(s.services.up, 0);
  assert.deepEqual(Model.issues(s), ["meilisearch failed", "mailpit stopped"]);
});

test("nginx down outranks everything else", () => {
  const s = Model.summarize({ status: { ...status, nginx: { running: false } } });
  assert.equal(s.level, "down");
  assert.deepEqual(Model.issues(s), ["nginx is not running"]);
});

test("broken dns names the configured tld", () => {
  const s = Model.summarize({ status: { ...status, dns: { ok: false, tld: "localhost" } } });
  assert.equal(s.level, "warn");
  assert.deepEqual(Model.issues(s), [".localhost resolution is down"]);
});

test("resources take the totals lerd already computed", () => {
  const r = Model.resources({
    available: true,
    total_cpu_percent: 12.5,
    total_mem_bytes: 2147483648,
    host_mem_bytes: 8589934592,
    containers: [
      { name: "lerd-ui", cpu_percent: 1, mem_bytes: 104857600 },
      { name: "lerd-mysql", cpu_percent: 2, mem_bytes: 1073741824 }
    ]
  });
  assert.equal(r.cpu, 12.5);
  assert.equal(r.memLabel, "2.0 GB");
  assert.equal(r.memPercent, 25);
  assert.equal(r.hostLabel, "8.0 GB");
  assert.equal(r.count, 2);
});

test("the container list is heaviest first, without the lerd prefix", () => {
  const r = Model.resources({
    containers: [
      { name: "lerd-ui", mem_bytes: 104857600 },
      { name: "lerd-mysql", mem_bytes: 1073741824 }
    ]
  });
  assert.deepEqual(r.top.map((c) => c.name), ["mysql", "ui"]);
  assert.equal(r.top[0].memLabel, "1.0 GB");
});

test("cpu over 100 percent still fits the meter", () => {
  assert.equal(Model.resources({ total_cpu_percent: 340 }).cpuBar, 100);
});

test("megabytes below a gigabyte stay megabytes", () => {
  assert.equal(Model.formatBytes(484462592), "462 MB");
});

test("an update on the version endpoint surfaces on the summary", () => {
  const s = Model.summarize({
    status,
    version: { current: "v1.33.0", latest: "1.33.1", has_update: true }
  });
  assert.equal(s.update.available, true);
  assert.equal(s.update.latest, "1.33.1");
});

test("an unreachable lerd says so instead of showing zeros", () => {
  const s = Model.unreachable();
  assert.equal(s.level, "down");
  assert.equal(s.resources.count, 0);
  assert.deepEqual(Model.issues(s), ["lerd is not running"]);
});

test("worker kinds are counted per type across sites", () => {
  const s = Model.summarize({ status, sites: [
    site({ has_queue_worker: true, queue_running: true }),
    site({ name: "b", domain: "b.test", has_queue_worker: true, queue_running: false,
           has_schedule_worker: true, schedule_running: true,
           framework_workers: [{ name: "vite", running: false }] }),
    site({ name: "old", paused: true, has_queue_worker: true, queue_running: false })
  ] });
  assert.deepEqual(s.workers.kinds, [
    { kind: "queue", running: 1, total: 2 },
    { kind: "schedule", running: 1, total: 1 },
    { kind: "framework", running: 0, total: 1 }
  ]);
});

test("a site with no workers contributes no kinds", () => {
  assert.deepEqual(Model.summarize({ status, sites: [site({})] }).workers.kinds, []);
});

test("cleanup is only offered when there is something to reclaim", () => {
  const empty = Model.cleanup({ available: true, reclaimable_bytes: 0, images: [] });
  assert.equal(empty.available, false);

  const full = Model.cleanup({ available: true, reclaimable_bytes: 1698428113, images: [{}, {}] });
  assert.equal(full.available, true);
  assert.equal(full.label, "1.6 GB");
  assert.equal(full.count, 2);
});

test("a host that cannot report disk offers no cleanup", () => {
  assert.equal(Model.cleanup({ available: false, reclaimable_bytes: 500 }).available, false);
});

test("the site list keeps every site, with its state, PHP and workers", () => {
  const s = Model.summarize({
    status,
    sites: [
      site({ php_version: "8.5", tls: true, has_queue_worker: true, queue_running: true, framework_workers: [{ name: "vite", label: "Vite", running: false }] }),
      site({ name: "old", domain: "old.test", paused: true, php_version: "8.2" })
    ]
  });
  assert.equal(s.sitesList.length, 2);
  assert.deepEqual(s.sitesList[0].workers, [
    { kind: "queue", label: "queue", running: true },
    { kind: "framework", label: "Vite", running: false }
  ]);
  assert.equal(s.sitesList[0].php, "8.5");
  assert.equal(s.sitesList[0].tls, true);
  assert.equal(s.sitesList[1].state, "paused");
  assert.equal(s.sites.total, 1);
});

test("service rows tell shared services from per-site worker units", () => {
  assert.deepEqual(Model.serviceGroup({ name: "redis" }), { group: "service", site: "", kind: "", worker: "" });
  assert.deepEqual(Model.serviceGroup({ name: "queue-shop", queue_site: "shop" }), { group: "worker", site: "shop", kind: "queue", worker: "queue" });
  assert.deepEqual(Model.serviceGroup({ name: "schedule-shop", schedule_worker_site: "shop" }), { group: "worker", site: "shop", kind: "schedule", worker: "schedule" });
  assert.deepEqual(
    Model.serviceGroup({ name: "vite-shop", worker_site: "shop", worker_name: "vite", worker_label: "Vite" }),
    { group: "worker", site: "shop", kind: "framework", worker: "vite", label: "Vite" }
  );
  assert.equal(Model.serviceGroup({ name: "horizon-shop", worker_site: "shop", worker_name: "horizon" }).kind, "horizon");
});

test("a worker unit lerd lists twice is counted once", () => {
  const s = Model.summarize({
    status,
    services: [
      { name: "redis", status: "active", port: 6379 },
      { name: "horizon-shop", status: "active", horizon_site: "shop" },
      { name: "horizon-shop", status: "active", worker_site: "shop", worker_name: "horizon" },
      { name: "vite-shop", status: "inactive", worker_site: "shop", worker_name: "vite", worker_label: "Vite" }
    ]
  });
  assert.equal(s.services.total, 3);
  assert.equal(s.services.up, 2);
  assert.equal(s.services.list[1].group, "worker");
  assert.equal(s.services.list[1].kind, "horizon");
  assert.equal(s.services.list[2].label, "Vite");
  const split = Model.splitServices(s.services.list);
  assert.deepEqual(split.shared.map((r) => r.name), ["redis"]);
  assert.deepEqual(split.bySite.map((g) => g.site), ["shop"]);
  assert.equal(split.bySite[0].rows.length, 2);
  assert.equal(split.workerCount, 2);
});

test("a worker unit carries the domain its site answers on", () => {
  const s = Model.summarize({
    status,
    // The name is not the domain here, which is the whole point: a worker
    // verb posted to /api/sites/scopey-env-2/... would 404.
    sites: [site({ name: "scopey-env-2", domain: "scopey-dev.test", has_horizon: true, horizon_running: true })],
    services: [
      { name: "redis", status: "active" },
      { name: "horizon-scopey-env-2", status: "active", horizon_site: "scopey-env-2" },
      { name: "vite-scopey-env-2", status: "inactive", worker_site: "scopey-env-2", worker_name: "vite", worker_label: "Vite" }
    ]
  });
  assert.equal(s.services.list[0].domain, "");
  assert.equal(s.services.list[1].domain, "scopey-dev.test");
  assert.equal(s.services.list[2].domain, "scopey-dev.test");
  assert.equal(s.services.list[2].worker, "vite");
});

test("a worker unit whose site is gone reports no domain", () => {
  const s = Model.summarize({
    status,
    sites: [],
    services: [{ name: "queue-ghost", status: "failed", queue_site: "ghost" }]
  });
  assert.equal(s.services.list[0].domain, "");
  assert.equal(Model.domainFor([], "ghost"), "");
});
