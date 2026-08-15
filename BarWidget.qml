import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Theme.js" as Theme

BarWidget {
  id: root
  moduleName: "sh.lerd.glance"

  property string endpoint: "http://127.0.0.1:7073"
  property var summary: Model.unreachable()

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

  // lerd re-inspects the host and applies its own fresh plan, so the button
  // sends nothing but the CSRF header the dashboard API expects.
  function cleanup() {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) root.refresh()
    }
    xhr.open("POST", root.endpoint + "/api/disk")
    xhr.setRequestHeader("X-Lerd-CSRF", "1")
    xhr.send()
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
