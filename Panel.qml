import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Theme.js" as Theme

// The popout. A thin header (mark, version, update, view toggle), then one of
// two views of the same summary — the dense table (400px) or the three
// columns (720px) — and the two actions at the bottom. The view choice is a
// widget setting, so it survives restarts the same way the clock's format
// does.
Panel {
  id: root
  moduleName: "sh.lerd.glance"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var summary: Model.unreachable()

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // "table" (dense, compact) or "columns" (wide). Persisted in settings.
  readonly property string view: String(setting("view", "table")) === "columns" ? "columns" : "table"
  readonly property string otherView: view === "columns" ? "table" : "columns"
  readonly property int viewWidth: Style.space(view === "columns" ? 720 : 400)

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function cleanup() {
    if (root.hostWidget) root.hostWidget.cleanup()
  }

  function openDashboard() {
    if (root.bar) root.bar.run("xdg-open http://lerd.localhost")
    root.close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  // Same dance as the clock: apply locally first so the toggle is instant,
  // then hand the entry to the shell, which writes shell.json and sends the
  // same value back through the bar.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function toggleView() {
    persistSettings({ view: root.otherView })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.viewWidth)
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "v") root.toggleView() }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // Header: the mark, the name, the version with an update dot, and
        // the toggle to the other view.
        Item {
          width: parent.width
          height: Style.space(24)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "lerd"
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.summary.update.current !== ""
              text: "v" + root.summary.update.current
              color: root.barForeground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)
              visible: root.summary.update.available

              StatusDot {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.warn
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.summary.update.latest + " available"
                color: root.barForeground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // The icon is the view you would switch to.
            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: Theme.icon(root.otherView === "columns" ? "view-columns" : "view-table")
              tooltipText: root.otherView === "columns" ? "Three columns (v)" : "Dense table (v)"
              foreground: root.barForeground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              size: Style.space(22)
              bordered: true
              onClicked: root.toggleView()
            }
          }
        }

        Text {
          width: parent.width
          visible: !root.summary.reachable
          text: "The dashboard is not running. Start it with lerd start."
          color: root.barForeground
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Loader {
          id: viewLoader
          width: parent.width
          visible: root.summary.reachable
          active: root.summary.reachable
          source: Qt.resolvedUrl(root.view === "columns" ? "ColumnsView.qml" : "DenseView.qml")
          onLoaded: {
            item.summary = Qt.binding(function() { return root.summary })
            item.foreground = Qt.binding(function() { return root.barForeground })
            item.fontFamily = Qt.binding(function() { return root.fontFamily })
            item.width = Qt.binding(function() { return viewLoader.width })
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.12
        }

        // Open dashboard always; Clean up only when lerd says there is
        // space to reclaim, and then side by side.
        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            width: root.summary.cleanup.available ? (parent.width - parent.spacing) / 2 : parent.width
            text: "Open dashboard"
            iconText: Theme.icon("external-link")
            bordered: true
            foreground: root.barForeground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.openDashboard()
          }

          Button {
            visible: root.summary.cleanup.available
            width: (parent.width - parent.spacing) / 2
            text: "Clean up · " + root.summary.cleanup.label
            iconText: Theme.icon("broom")
            bordered: true
            foreground: root.barForeground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.cleanup()
          }
        }
      }
    }
  }
}
