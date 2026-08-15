# lerd Glance

Your [lerd](https://lerd.sh) dashboard at a glance in the Omarchy Quattro bar, so you can see the state of your local PHP environment without opening a browser tab.

![The lerd Glance panel open in the Omarchy bar](preview.png)

## What it shows

The bar carries lerd's mark on its own. When something needs attention it gains a coloured dot, yellow for a warning and red when nginx is down, so a healthy environment stays quiet and a broken one is obvious from across the screen. Hovering gives you the counts and the list of problems without opening anything.

Clicking opens the panel:

- **Resources** — total CPU and memory across every lerd container, as meters, with the share of host memory and the container count.
- **Sites and services** — how many of each are running, paused sites left out of the count.
- **Workers** — a counter per worker type, queue, horizon, schedule, reverb, Stripe and framework workers such as Vite, each with its own glyph.
- **Environment** — nginx, `.test` resolution and the file watcher, plus every installed PHP version with the default in bold.
- **Services** — one row each with its status, version and port.
- **Needs attention** — what is actually wrong, in plain words: a failed service, a worker that died, DNS that stopped resolving. It only appears when there is something to say.

Two actions sit at the bottom. **Open dashboard** opens `http://lerd.localhost`. **Clean up** appears only when lerd reports reclaimable disk space, shows how much, and hands the work to lerd's own cleanup rather than calling podman itself.

## Requirements

Omarchy Quattro, and lerd running on the same machine. Nothing else, and no configuration.

## Install

```sh
omarchy plugin add https://github.com/lerd-env/lerd-omarchy-glance.git --enable
```

## Usage

Click the widget to open or close the panel, press Escape to close it. Clicking also forces a refresh; otherwise it polls every 30 seconds, and every 5 seconds while the panel is open.

Paused sites are left out of the counts, and a worker is only ever called unhealthy when lerd itself says so, so a queue worker you simply never started is not reported as broken.

## Configure

```sh
omarchy bar move sh.lerd.glance --section right
```

The plugin reads `http://127.0.0.1:7073`, the address lerd's dashboard already listens on, and the widget says so plainly when lerd is not running. If you serve lerd on another port, change the `endpoint` property at the top of `BarWidget.qml`.

## Privacy and permissions

Everything happens over loopback to the lerd instance already running as your user. The plugin sends no telemetry and contacts no third party. It changes nothing unless you press a button: the cleanup request, and the `xdg-open` that Open dashboard runs. That `xdg-open` is the only process it ever starts.

## Development

All the logic that turns the dashboard API into what you see lives in `Model.js`, free of QML imports, so it runs under node:

```sh
node --test test/model.test.mjs
```

`BarWidget.qml` owns the polling and hands a finished summary to `Panel.qml`; `Meter.qml`, `StatRow.qml`, `StatusDot.qml` and `Mark.qml` are the pieces both are drawn from, and `Theme.js` holds the state palette, which follows the lerd dashboard's own colours.

Validate a change the way the shell does before opening a pull request:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/sh.lerd.glance
qmllint -I "$OMARCHY_PATH/shell" ~/.config/omarchy/plugins/sh.lerd.glance/*.qml
```

## Remove

```sh
omarchy plugin remove sh.lerd.glance
```

## License

MIT
