import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Actions.js" as Actions
import "Theme.js" as Theme

BarWidget {
  id: root
  moduleName: "sh.lerd.glance"

  property string endpoint: "http://127.0.0.1:7073"
  property var summary: Model.unreachable()

  // What each action is doing right now, keyed by request: "busy" while it is
  // in flight, or the message lerd refused with, kept around long enough to
  // read. Rows bind to this, so the state shows on the row it belongs to and
  // survives switching views.
  property var actionState: ({})

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.settings = root.settings
    panelLoader.item.summary = root.summary
  }

  function getJson(path, callback) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status !== 200) {
        callback(null)
        return
      }
      try {
        callback(JSON.parse(xhr.responseText))
      } catch (e) {
        callback(null)
      }
    }
    xhr.open("GET", root.endpoint + path)
    xhr.send()
  }

  // The endpoints are independent, so they are fetched together and the summary
  // is only replaced once all of them have answered. Only the first three decide
  // whether lerd is reachable; the rest are extras.
  function refresh() {
    var pending = 7
    var payload = {}
    var failed = false

    function settle(key, value, required) {
      if (value === null && required) failed = true
      else payload[key] = value
      if (--pending > 0) return
      root.summary = failed ? Model.unreachable() : Model.summarize(payload)
      if (panelLoader.item) panelLoader.item.summary = root.summary
    }

    getJson("/api/status", function(v) { settle("status", v, true) })
    getJson("/api/sites", function(v) { settle("sites", v, true) })
    getJson("/api/services", function(v) { settle("services", v, true) })
    getJson("/api/workers/health", function(v) { settle("health", v, false) })
    getJson("/api/stats", function(v) { settle("stats", v, false) })
    getJson("/api/version", function(v) { settle("version", v, false) })
    getJson("/api/disk", function(v) { settle("disk", v, false) })
  }

  // lerd answers 200 even when it refuses, so the body is what decides, and
  // the request carries the CSRF header every mutation needs. Nothing here
  // knows which endpoint belongs to which row; Actions.js owns that.
  function run(request) {
    if (!request || root.actionState[request.key] === "busy") return
    root.setActionState(request.key, "busy")

    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      var result = xhr.status === 200
        ? Actions.verdict(xhr.responseText)
        : { ok: false, error: xhr.status === 0 ? "lerd is not answering" : "lerd answered " + xhr.status }
      root.setActionState(request.key, result.ok ? null : result.error)
      if (!result.ok) forgetError.restart()
      root.refreshBurst()
    }
    xhr.open(request.method, root.endpoint + request.path)
    xhr.setRequestHeader("X-Lerd-CSRF", "1")
    xhr.send()
  }

  // Replaced wholesale rather than mutated, so bindings on actionState see
  // the change.
  function setActionState(key, value) {
    var next = {}
    for (var k in root.actionState) next[k] = root.actionState[k]
    if (value === null) delete next[key]
    else next[key] = value
    root.actionState = next
  }

  // Some verbs return before the unit is up — queue:start hands off to a
  // goroutine — so a single refresh would paint the state we just left.
  function refreshBurst() {
    root.refresh()
    burst.round = 0
    burst.restart()
  }

  function cleanup() {
    root.run(Actions.cleanup())
  }

  Timer {
    id: burst
    property int round: 0
    interval: 1500
    repeat: true
    onTriggered: {
      root.refresh()
      if (++round >= 2) stop()
    }
  }

  // Errors are worth reading, not worth keeping: they clear on their own so a
  // stale red icon never outlives the problem.
  Timer {
    id: forgetError
    interval: 6000
    onTriggered: {
      var next = {}
      for (var k in root.actionState) if (root.actionState[k] === "busy") next[k] = "busy"
      root.actionState = next
    }
  }

  function tooltip() {
    if (!root.summary.reachable) return "lerd is not running"
    var lines = [
      "Sites " + root.summary.sites.up + "/" + root.summary.sites.total
        + "   Services " + root.summary.services.up + "/" + root.summary.services.total,
      "CPU " + root.summary.resources.cpu.toFixed(1) + "%"
        + "   Memory " + root.summary.resources.memLabel
    ]
    return lines.concat(Model.issues(root.summary)).join("\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: refresh()

  Timer {
    interval: root.opened ? 5000 : 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: root.tooltip()
    iconComponent: Component {
      Item {
        Mark {
          id: mark
          anchors.centerIn: parent
          size: Math.round(Math.min(parent.width, parent.height))
          foreground: button.foreground
        }

        // Same idea as the dashboard's rail logo: the mark alone when all is
        // well, a coloured dot on the corner when it is not.
        StatusDot {
          size: Math.max(5, Math.round(mark.size * 0.34))
          visible: root.summary.level !== "ok"
          color: Theme.levelColor(root.summary.level)
          border.width: 1
          border.color: root.bar ? root.bar.background : "black"
          anchors.right: mark.right
          anchors.top: mark.top
          anchors.rightMargin: -size / 3
          anchors.topMargin: -size / 3
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.refresh()
        root.toggle()
      }
    }
  }
}
