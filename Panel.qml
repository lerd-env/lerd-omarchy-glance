import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Theme.js" as Theme

Panel {
  id: root
  moduleName: "sh.lerd.glance"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var summary: Model.unreachable()

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(330))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // Header: the mark, the name, and the version with an update dot.
        Row {
          width: parent.width
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "lerd"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Item {
            width: parent.width - x - versionRow.width
            height: 1
            anchors.verticalCenter: parent.verticalCenter
          }

          Row {
            id: versionRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            visible: root.summary.update.current !== ""

            StatusDot {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.summary.update.available
              color: Theme.warn
            }

            Text {
              text: root.summary.update.available
                ? root.summary.update.latest + " available"
                : root.summary.update.current
              color: root.barForeground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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

        // Resources, laid out like the dashboard's two meters.
        Row {
          width: parent.width
          spacing: Style.space(10)
          visible: root.summary.reachable && root.summary.resources.available

          Meter {
            width: (parent.width - Style.space(10)) / 2
            label: "CPU"
            value: root.summary.resources.cpu.toFixed(2) + "%"
            percent: root.summary.resources.cpuBar
            fill: Theme.ok
            foreground: root.barForeground
            fontFamily: root.fontFamily
            caption: root.summary.resources.count + " containers"
          }

          Meter {
            width: (parent.width - Style.space(10)) / 2
            label: "Memory"
            value: root.summary.resources.memLabel
            percent: root.summary.resources.memPercent
            fill: Theme.idle
            foreground: root.barForeground
            fontFamily: root.fontFamily
            caption: root.summary.resources.memPercent.toFixed(1) + "% of " + root.summary.resources.hostLabel
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.12
          visible: root.summary.reachable
        }

        // Counts, workers and the environment, each as a left-right row.
        Column {
          width: parent.width
          spacing: Style.space(5)
          visible: root.summary.reachable

          StatRow {
            width: parent.width
            label: "Sites"
            value: root.summary.sites.up + "/" + root.summary.sites.total
            foreground: root.barForeground
            fontFamily: root.fontFamily
          }

          StatRow {
            width: parent.width
            label: "Services"
            value: root.summary.services.up + "/" + root.summary.services.total
            foreground: root.barForeground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.summary.workers.kinds

            StatRow {
              width: parent.width
              glyph: Theme.workerGlyph(modelData.kind)
              glyphColor: Theme.workerColor(modelData)
              label: Theme.workerLabel(modelData.kind)
              value: modelData.running + "/" + modelData.total
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }
          }

          Repeater {
            model: [
              { label: "nginx", on: root.summary.nginx },
              { label: "." + root.summary.tld + " resolution", on: root.summary.dns },
              { label: "watcher", on: root.summary.watcher }
            ]

            StatRow {
              width: parent.width
              label: modelData.label
              foreground: root.barForeground
              fontFamily: root.fontFamily

              StatusDot {
                color: Theme.flagColor(modelData.on)
              }
            }
          }

          StatRow {
            width: parent.width
            label: "PHP"
            foreground: root.barForeground
            fontFamily: root.fontFamily

            Repeater {
              model: root.summary.php

              Row {
                spacing: Style.space(3)

                StatusDot {
                  anchors.verticalCenter: parent.verticalCenter
                  size: 5
                  color: Theme.flagColor(modelData.running)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.version
                  color: root.barForeground
                  opacity: modelData.version === root.summary.phpDefault ? 1 : 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: modelData.version === root.summary.phpDefault
                }
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.12
          visible: root.summary.services.list.length > 0
        }

        // Services, one row each, the way the dashboard card lists them.
        Column {
          width: parent.width
          spacing: Style.space(3)
          visible: root.summary.services.list.length > 0

          Repeater {
            model: root.summary.services.list

            Item {
              width: parent.width
              height: serviceName.implicitHeight

              StatusDot {
                id: serviceDot
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.serviceColor(modelData)
              }

              Text {
                id: serviceName
                anchors.left: serviceDot.right
                anchors.leftMargin: Style.space(6)
                width: parent.width - Style.space(120)
                text: modelData.name
                color: root.barForeground
                opacity: modelData.up ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Text {
                anchors.right: servicePort.left
                anchors.rightMargin: Style.space(10)
                text: modelData.version
                color: root.barForeground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                id: servicePort
                anchors.right: parent.right
                text: modelData.port > 0 ? String(modelData.port) : ""
                color: root.barForeground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // Anything wrong, last, so it reads as the conclusion.
        Column {
          width: parent.width
          spacing: Style.space(3)
          visible: Model.issues(root.summary).length > 0

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          Text {
            width: parent.width
            text: "Needs attention"
            color: Theme.levelColor(root.summary.level)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Repeater {
            model: Model.issues(root.summary)

            Text {
              width: parent.width
              text: modelData
              color: root.barForeground
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        // Cleanup only appears when lerd says there is space to reclaim.
        Column {
          width: parent.width
          spacing: Style.space(5)
          visible: root.summary.cleanup.available

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.12
          }

          StatRow {
            width: parent.width
            label: "Reclaimable"
            value: root.summary.cleanup.label
            foreground: root.barForeground
            fontFamily: root.fontFamily
          }

          Button {
            width: parent.width
            text: "Clean up"
            bordered: true
            foreground: root.barForeground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.cleanup()
          }
        }

        Button {
          width: parent.width
          text: "Open dashboard"
          bordered: true
          foreground: root.barForeground
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          onClicked: root.openDashboard()
        }
      }
    }
  }
}
