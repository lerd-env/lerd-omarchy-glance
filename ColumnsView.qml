import QtQuick
import qs.Commons
import "Model.js" as Model
import "Actions.js" as Actions
import "Theme.js" as Theme

// The wide view: the dashboard's two meters across the top, then Sites,
// Services and Environment + Workers side by side, each column scrolling on
// its own, and anything that needs attention underneath as the conclusion.
Item {
  id: root

  property var summary: Model.unreachable()
  property color foreground: "white"
  property string fontFamily: Style.font.family
  // Anything with run(request) and actionState; the panel forwards to the
  // widget that owns the polling. Null in a preview, and then the rows are
  // simply not actionable.
  property var panel: null

  readonly property var issues: Model.issues(summary)
  readonly property var split: Model.splitServices(summary.services.list)
  readonly property int colGap: Style.space(14)
  readonly property int colWidth: Math.floor((width - colGap * 2) / 3)
  readonly property int colHeight: Style.space(340)

  implicitHeight: body.implicitHeight

  // A row that knows when the pointer is over it, so it can trade its
  // trailing detail for the actions it offers. The hover area takes no
  // buttons, so a click meant for an icon on top of it still lands there.
  component Row_: Item {
    id: hoverRow
    readonly property bool hovered: hoverArea.containsMouse
    width: parent ? parent.width : 100
    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(4)
      anchors.rightMargin: -Style.space(4)
      radius: Style.space(4)
      visible: hoverRow.hovered
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
    }
    MouseArea {
      id: hoverArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }
  }

  // A single caption-sized line: label on the left, value on the right.
  component Line: Item {
    id: line
    property string label: ""
    property string value: ""
    property real dim: 0.5
    width: parent ? parent.width : 100
    height: Style.space(18)
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: line.label
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: line.value
      color: root.foreground
      opacity: line.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(10)

    // ── Resources ─────────────────────────────────────────────────────────
    Row {
      width: parent.width
      spacing: Style.space(12)
      visible: root.summary.resources.available

      Meter {
        width: (parent.width - parent.spacing) / 2
        label: "CPU"
        value: root.summary.resources.cpu.toFixed(2) + "%"
        percent: root.summary.resources.cpuBar
        fill: Theme.ok
        foreground: root.foreground
        fontFamily: root.fontFamily
        caption: root.summary.resources.count + " containers"
      }
      Meter {
        width: (parent.width - parent.spacing) / 2
        label: "Memory"
        value: root.summary.resources.memLabel
        percent: root.summary.resources.memPercent
        fill: Theme.idle
        foreground: root.foreground
        fontFamily: root.fontFamily
        caption: root.summary.resources.memPercent.toFixed(1) + "% of " + root.summary.resources.hostLabel
      }
    }

    Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.12 }

    Row {
      width: parent.width
      spacing: root.colGap

      // ── Sites ───────────────────────────────────────────────────────────
      Column {
        width: root.colWidth
        spacing: Style.space(4)

        SectionTitle { width: parent.width; text: "Sites"; count: root.summary.sites.up + "/" + root.summary.sites.total; foreground: root.foreground; fontFamily: root.fontFamily }

        Flickable {
          width: parent.width
          height: root.colHeight
          contentWidth: width
          contentHeight: siteCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: siteCol
            width: parent.width
            Repeater {
              model: root.summary.sitesList
              delegate: Row_ {
                id: siteRow
                required property var modelData
                width: siteCol.width
                height: Style.space(34)
                Column {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)
                  Row {
                    spacing: Style.space(6)
                    StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.siteStateColor(siteRow.modelData.state) }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: siteRow.modelData.name
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                  Row {
                    x: Style.space(12)
                    spacing: Style.space(5)
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "PHP " + siteRow.modelData.php + (siteRow.modelData.state !== "up" ? " · " + siteRow.modelData.state : "")
                      color: root.foreground
                      opacity: 0.5
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Repeater {
                      model: siteRow.modelData.workers
                      delegate: WorkerGlyph {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        kind: modelData.kind
                        running: modelData.running
                        fontFamily: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }

                ActionRow {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  requests: Actions.siteActions(siteRow.modelData)
                  panel: root.panel
                  foreground: root.foreground
                  revealed: siteRow.hovered
                }
              }
            }
          }
        }
      }

      // ── Services ────────────────────────────────────────────────────────
      Column {
        width: root.colWidth
        spacing: Style.space(4)

        SectionTitle { width: parent.width; text: "Services"; count: root.summary.services.up + "/" + root.summary.services.total; foreground: root.foreground; fontFamily: root.fontFamily }

        Flickable {
          width: parent.width
          height: root.colHeight
          contentWidth: width
          contentHeight: svcCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: svcCol
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              model: root.split.shared
              delegate: Row_ {
                id: svcRow
                required property var modelData
                width: svcCol.width
                height: Style.space(22)
                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.serviceColor(svcRow.modelData) }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: svcRow.modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !svcRow.modelData.up
                    text: svcRow.modelData.broken ? "failed" : svcRow.modelData.status
                    color: Theme.serviceColor(svcRow.modelData)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !svcActions.visible
                  text: svcRow.modelData.version + (svcRow.modelData.port > 0 ? "  :" + svcRow.modelData.port : "")
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                ActionRow {
                  id: svcActions
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  requests: Actions.serviceActions(svcRow.modelData)
                  panel: root.panel
                  foreground: root.foreground
                  revealed: svcRow.hovered
                }
              }
            }

            SectionTitle {
              visible: root.split.workerCount > 0
              width: parent.width
              text: "Worker containers"
              count: String(root.split.workerCount)
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.split.bySite
              delegate: Column {
                id: siteGroup
                required property var modelData
                width: svcCol.width
                spacing: 0
                Text {
                  height: Style.space(16)
                  verticalAlignment: Text.AlignVCenter
                  text: siteGroup.modelData.site
                  color: root.foreground
                  opacity: 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Repeater {
                  model: siteGroup.modelData.rows
                  delegate: Row_ {
                    id: wRow
                    required property var modelData
                    width: svcCol.width
                    height: Style.space(20)
                    Row {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)
                      WorkerGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: wRow.modelData.kind
                        running: wRow.modelData.up
                        fontFamily: root.fontFamily
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: wRow.modelData.name
                        color: root.foreground
                        opacity: wRow.modelData.up ? 0.9 : 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                    Row {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)
                      visible: !workerActions.visible
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !wRow.modelData.up
                        text: wRow.modelData.broken ? "failed" : wRow.modelData.status
                        color: Theme.serviceColor(wRow.modelData)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.serviceColor(wRow.modelData) }
                    }

                    ActionRow {
                      id: workerActions
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      requests: Actions.workerActions(wRow.modelData)
                      panel: root.panel
                      foreground: root.foreground
                      revealed: wRow.hovered
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ── Environment + Workers ───────────────────────────────────────────
      Column {
        width: root.colWidth
        spacing: Style.space(4)

        SectionTitle {
          width: parent.width
          text: "Environment"
          showDot: true
          dotColor: Theme.levelColor(root.summary.level)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Column {
          width: parent.width
          spacing: Style.space(2)
          StatRow { width: parent.width; label: "nginx"; foreground: root.foreground; fontFamily: root.fontFamily; StatusDot { color: Theme.flagColor(root.summary.nginx) } }
          StatRow { width: parent.width; label: "." + root.summary.tld + " resolution"; foreground: root.foreground; fontFamily: root.fontFamily; StatusDot { color: Theme.flagColor(root.summary.dns) } }
          StatRow { width: parent.width; label: "watcher"; foreground: root.foreground; fontFamily: root.fontFamily; StatusDot { color: Theme.flagColor(root.summary.watcher) } }
          StatRow {
            width: parent.width
            label: "PHP"
            foreground: root.foreground
            fontFamily: root.fontFamily
            Repeater {
              model: root.summary.php
              delegate: Row {
                id: phpItem
                required property var modelData
                spacing: Style.space(3)
                StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.flagColor(phpItem.modelData.running) }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: phpItem.modelData.version
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: phpItem.modelData.version === root.summary.phpDefault
                }
              }
            }
          }
          StatRow { visible: root.summary.nodeDefault !== ""; width: parent.width; label: "Node"; value: root.summary.nodeDefault; foreground: root.foreground; fontFamily: root.fontFamily }
        }

        Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.12 }

        SectionTitle { width: parent.width; text: "Workers"; foreground: root.foreground; fontFamily: root.fontFamily }

        Repeater {
          model: root.summary.workers.kinds
          delegate: Item {
            id: kindRow
            required property var modelData
            readonly property int down: modelData.total - modelData.running
            width: parent.width
            height: Style.space(20)
            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              WorkerGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: kindRow.modelData.kind
                running: kindRow.modelData.running > 0
                fontFamily: root.fontFamily
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.workerLabel(kindRow.modelData.kind)
                color: root.foreground
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: kindRow.modelData.running + "/" + kindRow.modelData.total
              color: kindRow.down > 0 ? Theme.warn : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }

        // Heal is the one bulk verb worth offering: it is lerd's own answer
        // to the workers it just reported unhealthy, so it only appears when
        // there are some.
        Row_ {
          visible: root.summary.workers.down.length > 0
          width: parent.width
          height: Style.space(20)
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Heal " + root.summary.workers.down.length + " unhealthy"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          ActionRow {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            requests: [Actions.heal()]
            panel: root.panel
            foreground: root.foreground
            revealed: true
          }
        }
      }
    }

    Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.12 }

    // ── Needs attention, last, so it reads as the conclusion ─────────────
    Column {
      width: parent.width
      spacing: Style.space(3)

      SectionTitle {
        width: parent.width
        text: root.issues.length > 0 ? "Needs attention" : "Nothing needs attention"
        count: root.issues.length > 0 ? String(root.issues.length) : ""
        showDot: true
        dotColor: Theme.levelColor(root.summary.level)
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Grid {
        width: parent.width
        columns: 2
        columnSpacing: root.colGap
        rowSpacing: Style.space(2)
        Repeater {
          model: root.issues
          delegate: Row {
            id: issueRow
            required property var modelData
            width: (parent.width - root.colGap) / 2
            spacing: Style.space(6)
            StatusDot { anchors.verticalCenter: parent.verticalCenter; color: /failed|down|not running/.test(issueRow.modelData) ? Theme.bad : Theme.warn }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(12)
              text: issueRow.modelData
              color: root.foreground
              opacity: 0.85
              elide: Text.ElideRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
