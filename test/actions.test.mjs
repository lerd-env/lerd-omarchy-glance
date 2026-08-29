import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Actions.js is loaded by QML as a plain script, so it has no exports to
// import. Evaluating the source keeps the file usable by the shell and by
// these tests.
const source = readFileSync(new URL("../Actions.js", import.meta.url), "utf8");
const Actions = new Function(
  source + "; return { forSite, siteActions, siteUrl, forWorker, workerActions, forService, serviceActions, heal, cleanup, verdict };"
)();

const site = (over) => ({ name: "shop", domain: "shop.test", state: "up", ...over });
const worker = (over) => ({ name: "queue-shop", group: "worker", site: "shop", domain: "shop.test", kind: "queue", worker: "queue", up: true, ...over });
const service = (over) => ({ name: "redis", group: "service", up: true, ...over });

test("every mutation is a POST with a key of its own", () => {
  const req = Actions.forSite(site(), "restart");
  assert.equal(req.method, "POST");
  assert.equal(req.path, "/api/sites/shop.test/restart");
  assert.equal(req.key, "POST /api/sites/shop.test/restart");
  assert.equal(req.label, "Restart site");
});

test("a site is addressed by domain, never by name", () => {
  // The trap this guards: lerd resolves sites with FindSiteByDomain, and
  // scopey-env-2 answers on scopey-dev.test.
  const req = Actions.forSite(site({ name: "scopey-env-2", domain: "scopey-dev.test" }), "restart");
  assert.equal(req.path, "/api/sites/scopey-dev.test/restart");
});

test("a site with no domain offers nothing", () => {
  assert.equal(Actions.forSite(site({ domain: "" }), "restart"), null);
  assert.deepEqual(Actions.siteActions(site({ domain: "" })), []);
});

test("a paused site can only be resumed", () => {
  const paused = site({ state: "paused" });
  assert.equal(Actions.forSite(paused, "pause"), null);
  assert.equal(Actions.forSite(paused, "restart"), null);
  assert.equal(Actions.forSite(paused, "unpause").path, "/api/sites/shop.test/unpause");
  assert.deepEqual(Actions.siteActions(paused).map((a) => a.icon), ["play"]);
});

test("a running site offers restart and pause, in that order", () => {
  assert.deepEqual(Actions.siteActions(site()).map((a) => a.icon), ["restart", "pause"]);
  assert.equal(Actions.forSite(site(), "unpause"), null);
});

test("a suspended or down site is still restartable", () => {
  assert.equal(Actions.siteActions(site({ state: "down" })).length, 2);
  assert.equal(Actions.siteActions(site({ state: "suspended" })).length, 2);
});

test("worker verbs go through the site, both ways", () => {
  // The services endpoint only accepts "stop" for a worker unit, so start
  // would be refused there with "unsupported action for queue worker".
  assert.equal(Actions.forWorker(worker(), true).path, "/api/sites/shop.test/queue:start");
  assert.equal(Actions.forWorker(worker(), false).path, "/api/sites/shop.test/queue:stop");
  assert.equal(Actions.forWorker(worker({ kind: "horizon", worker: "horizon" }), false).path, "/api/sites/shop.test/horizon:stop");
});

test("a framework worker takes the generic verb, under its own name", () => {
  const vite = worker({ name: "vite-shop", kind: "framework", worker: "vite", up: false });
  assert.equal(Actions.forWorker(vite, true).path, "/api/sites/shop.test/worker:vite:start");
  assert.equal(Actions.forWorker(vite, false).path, "/api/sites/shop.test/worker:vite:stop");
});

test("a framework worker with no unit name offers nothing", () => {
  assert.equal(Actions.forWorker(worker({ kind: "framework", worker: "" }), true), null);
});

test("a worker whose site is gone offers nothing", () => {
  assert.equal(Actions.forWorker(worker({ domain: "" }), true), null);
  assert.deepEqual(Actions.workerActions(worker({ domain: "" })), []);
});

test("a worker offers the verb it is not currently doing", () => {
  assert.deepEqual(Actions.workerActions(worker({ up: true })).map((a) => a.icon), ["stop"]);
  assert.deepEqual(Actions.workerActions(worker({ up: false })).map((a) => a.icon), ["play"]);
});

test("a shared service takes its verbs on its own endpoint", () => {
  assert.equal(Actions.forService(service(), "restart").path, "/api/services/redis/restart");
  assert.equal(Actions.forService(service(), "stop").path, "/api/services/redis/stop");
  assert.equal(Actions.forService(service({ up: false }), "start").path, "/api/services/redis/start");
});

test("a service never offers the state it is already in", () => {
  assert.equal(Actions.forService(service({ up: true }), "start"), null);
  assert.equal(Actions.forService(service({ up: false }), "stop"), null);
});

test("restart is offered to a failed service too, since that is the fix", () => {
  assert.deepEqual(Actions.serviceActions(service({ up: false })).map((a) => a.icon), ["play", "restart"]);
  assert.deepEqual(Actions.serviceActions(service({ up: true })).map((a) => a.icon), ["restart", "stop"]);
});

test("a worker unit is never addressed as a service", () => {
  assert.equal(Actions.forService(worker(), "start"), null);
  assert.deepEqual(Actions.serviceActions(worker()), []);
});

test("an unknown verb is refused rather than guessed", () => {
  assert.equal(Actions.forService(service(), "remove"), null);
  assert.equal(Actions.forSite(site(), "unlink"), null);
});

test("heal and cleanup are the two requests with no subject", () => {
  assert.equal(Actions.heal().path, "/api/workers/heal");
  assert.equal(Actions.cleanup().path, "/api/disk");
});

test("the verdict comes from the body, because lerd always answers 200", () => {
  assert.deepEqual(Actions.verdict('{"ok":true}'), { ok: true });
  assert.deepEqual(Actions.verdict('{"ok":false,"error":"port 5433 already in use"}'), { ok: false, error: "port 5433 already in use" });
  assert.deepEqual(Actions.verdict('{"error":"site not found: shop.test"}'), { ok: false, error: "site not found: shop.test" });
  assert.deepEqual(Actions.verdict('{"ok":false}'), { ok: false, error: "failed" });
});

test("a heal stream is read by its last line", () => {
  const stream = '{"phase":"start"}\n{"phase":"restart","worker":"queue"}\n{"phase":"done"}\n';
  assert.deepEqual(Actions.verdict(stream), { ok: true });
  assert.deepEqual(
    Actions.verdict('{"phase":"start"}\n{"phase":"failed","error":"podman is not running"}'),
    { ok: false, error: "podman is not running" }
  );
});

test("an empty or unreadable body is not treated as a failure", () => {
  assert.deepEqual(Actions.verdict(""), { ok: true });
  assert.deepEqual(Actions.verdict(null), { ok: true });
  assert.deepEqual(Actions.verdict("not json at all"), { ok: true });
});

// lerd tags a per-worktree worker unit with the PARENT site's name and a
// separate worker_worktree (internal/ui/server.go:1731, locked by
// framework_workers_test.go: "WorkerSite = rapids (parent for grouping)"),
// so a worktree row that carries only site+worker is indistinguishable from
// the parent's. lerd's own dashboard keeps them apart, reaching for
// worker_worktree_domain before the parent's domain (stores/services.ts:750).
const wtWorker = (over) => worker({
  name: "vite-shop-feat-login", kind: "framework", worker: "vite",
  worktree: "feat-login", worktreeDomain: "feat-login.shop.test", ...over
});

test("a worktree worker is not addressed as the parent's", () => {
  const parent = Actions.forWorker(worker({ name: "vite-shop", kind: "framework", worker: "vite" }), false);
  const child = Actions.forWorker(wtWorker(), false);
  assert.notEqual(child.path, parent.path,
    "the worktree row stops lerd-vite-shop instead of lerd-vite-shop-feat-login");
});

test("two rows for the same worker keep separate in-flight state", () => {
  // key is what actionState is stored under, so a shared key spins both rows
  // and shows one row's refusal on the other.
  const parent = Actions.forWorker(worker({ name: "vite-shop", kind: "framework", worker: "vite" }), false);
  const child = Actions.forWorker(wtWorker(), false);
  assert.notEqual(child.key, parent.key);
});

test("a worktree worker names the worktree it belongs to", () => {
  // Either shape passes: ?branch= on the parent's domain, which is what the
  // site endpoint reads (server.go:4590), or the worktree's own domain.
  const req = Actions.forWorker(wtWorker(), true);
  assert.ok(
    /[?&]branch=feat-login\b/.test(req.path) || req.path.indexOf("feat-login.shop.test") >= 0,
    `request does not identify the worktree: ${req.path}`
  );
});

test("a site row opens the site over the scheme its certificate decides", () => {
  assert.equal(Actions.siteUrl(site({ tls: true })), "https://shop.test");
  assert.equal(Actions.siteUrl(site({ tls: false })), "http://shop.test");
});

test("a site with no usable domain opens nothing", () => {
  assert.equal(Actions.siteUrl(site({ domain: "" })), "");
  assert.equal(Actions.siteUrl(null), "");
  assert.equal(Actions.siteUrl(site({ domain: "shop.test; rm -rf ~" })), "");
});
