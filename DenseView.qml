import QtQuick
import qs.Commons
import "Model.js" as Model
import "Actions.js" as Actions
import "Theme.js" as Theme

// The dense view: htop density in a 400px column. One line of meters, then a
// single table of fixed-height rows grouped by section — Attention, Sites,
// Workers, Services (shared, then the worker units under their site), Env —
// inside one clipped Flickable so the panel never grows past the screen.
Item {
  id: root

  property var summary: Model.unreachable()
  property color foreground: "white"
  // True when the popup card is a light surface, which picks the darker set
  // of the same state colours.
  property bool lightSurface: false
  readonly property var stateColors: Theme.palette(root.lightSurface)
  property string fontFamily: Style.font.family
  // Anything with run(request) and actionState; the panel forwards to the
  // widget that owns the polling. Null in a preview, and then the rows are
  // simply not actionable.
  property var panel: null

  readonly property var issues: Model.issues(summary)
  readonly property var split: Model.splitServices(summary.services.list)
  readonly property var kinds: summary.workers.kinds
  readonly property int workersRunning: kinds.reduce(function(n, k) { return n + k.running }, 0)
  readonly property int workersTotal: kinds.reduce(function(n, k) { return n + k.total }, 0)

  readonly property int rowH: Style.space(20)
  readonly property int tableMax: Style.space(640)
  readonly property int colName: Style.space(112)
  readonly property int colPhp: Style.space(26)
  readonly property int colState: Style.space(36)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)
  readonly property color band: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  readonly property color zebra: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.018)

  implicitHeight: body.implicitHeight

  function shortState(state) {
    if (state === "suspended") return "susp"
    if (state === "paused") return "pause"
    return state || "down"
  }

  function pctColor(p) {
    if (p >= 85) return root.stateColors.bad
    if (p >= 60) return root.stateColors.warn
    return root.stateColors.ok
  }

  // ── pieces ───────────────────────────────────────────────────────────────

  // A meter as a run of blocks, so it reads at caption size.
  component Blocks: Row {
    id: blocks
    property real percent: 0
    property int count: 8
    property color fill: root.stateColors.ok
    readonly property int filled: Math.round(Math.max(0, Math.min(100, percent)) / 100 * count)
    spacing: 1
    Repeater {
      model: blocks.count
      delegate: Rectangle {
        required property int index
        width: Style.space(4)
        height: Style.space(7)
        radius: 1
        color: index < blocks.filled ? blocks.fill : root.faint
      }
    }
  }

  // Section band: "SITES ........ 7/9".
  component SecHdr: Rectangle {
    id: hdr
    property string text: ""
    property string count: ""
    property string note: ""
    width: parent ? parent.width : 100
    height: root.rowH
    color: root.band
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.faint }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: hdr.text.toUpperCase()
      color: root.foreground
      opacity: 0.55
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
    Row {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: hdr.note !== ""
        text: hdr.note
        color: root.foreground
        opacity: 0.45
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: hdr.count !== ""
        text: hdr.count
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  // Indented sub-header: "shared", "containers", site names.
  component SubHdr: Item {
    id: sub
    property string text: ""
    property int indent: Style.space(16)
    width: parent ? parent.width : 100
    height: Style.space(16)
    Text {
      x: sub.indent
      anchors.verticalCenter: parent.verticalCenter
      text: sub.text
      color: root.foreground
      opacity: 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.5
    }
  }

  // Table cell: fixed width, elided, mono.
  component Cell: Text {
    property real dim: 1
    color: root.foreground
    opacity: dim
    elide: Text.ElideRight
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  // A table row: a zebra stripe, and it knows when the pointer is over it so
  // the row can trade its trailing detail for the actions it offers. The
  // pointer is tracked with a HoverHandler, not a MouseArea: an action icon
  // sitting on the row carries its own MouseArea, which would take the hover
  // away from a MouseArea here and leave the row hiding the very icon the
  // pointer just reached.
  component TableRow: Item {
    id: tableRow
    property int index: 0
    readonly property bool hovered: hoverArea.hovered
    width: parent ? parent.width : 100
    height: root.rowH
    Rectangle { anchors.fill: parent; color: tableRow.index % 2 ? root.zebra : "transparent" }
    Rectangle {
      anchors.fill: parent
      visible: tableRow.hovered
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
    }
    HoverHandler { id: hoverArea }
  }

  // One-letter environment flag: filled when on, outlined when off.
  component EnvFlag: Rectangle {
    id: flag
    property string letter: ""
    property bool on: false
    width: Style.space(15)
    height: Style.space(14)
    radius: 2
    color: on ? root.stateColors.ok : "transparent"
    border.width: on ? 0 : 1
    border.color: root.faint
    Text {
      anchors.centerIn: parent
      text: flag.letter
      color: flag.on ? "#0b0c10" : root.foreground
      opacity: flag.on ? 1 : 0.5
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(6)

    // ── meters, one line: CPU on the left edge, memory on the right ─────
    Item {
      width: parent.width
      height: Style.space(16)
      visible: root.summary.resources.available

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "CPU"; color: root.foreground; opacity: 0.5
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Blocks { anchors.verticalCenter: parent.verticalCenter; percent: root.summary.resources.cpuBar; fill: root.pctColor(root.summary.resources.cpu) }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.summary.resources.cpu.toFixed(2) + "%"; color: root.foreground
          font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "MEM"; color: root.foreground; opacity: 0.5
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Blocks { anchors.verticalCenter: parent.verticalCenter; percent: root.summary.resources.memPercent; fill: root.pctColor(root.summary.resources.memPercent) }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.summary.resources.memLabel; color: root.foreground
          font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.summary.resources.memPercent.toFixed(1) + "% of " + root.summary.resources.hostLabel
          color: root.foreground; opacity: 0.45
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }

    // ── the table ───────────────────────────────────────────────────────
    Flickable {
      id: table
      width: parent.width
      height: Math.min(root.tableMax, tableCol.implicitHeight)
      contentWidth: width
      contentHeight: tableCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      // Thin position marker at the right edge, only when there is more.
      Rectangle {
        visible: table.contentHeight > table.height
        z: 2
        anchors.right: parent.right
        width: 2
        radius: 1
        y: table.visibleArea.yPosition * table.height
        height: Math.max(Style.space(12), table.visibleArea.heightRatio * table.height)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
      }

      Column {
        id: tableCol
        width: parent.width
        spacing: 0

        // ATTENTION ──────────────────────────────────────────────────────
        // The section is the warning; with nothing wrong there is nothing to say.
        SecHdr { visible: root.issues.length > 0; text: "Attention"; count: String(root.issues.length) }
        Repeater {
          model: root.issues
          delegate: TableRow {
            id: issueRow
            required property var modelData
            required property int index
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "!"
                color: /failed|down|not running/.test(issueRow.modelData) ? root.stateColors.bad : root.stateColors.warn
                font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
              }
              Cell {
                anchors.verticalCenter: parent.verticalCenter
                width: tableCol.width - Style.space(28)
                text: issueRow.modelData
              }
            }
          }
        }
        // SITES ──────────────────────────────────────────────────────────
        SecHdr { visible: root.summary.sitesList.length > 0; text: "Sites"; count: root.summary.sites.up + "/" + root.summary.sites.total }
        Repeater {
          model: root.summary.sitesList
          delegate: TableRow {
            id: siteRow
            required property var modelData
            required property int index
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.siteStateColor(siteRow.modelData.state, root.lightSurface) }
              Cell { anchors.verticalCenter: parent.verticalCenter; width: root.colName; text: siteRow.modelData.name; font.underline: siteRow.hovered }
              Cell { anchors.verticalCenter: parent.verticalCenter; width: root.colPhp; text: siteRow.modelData.php; dim: 0.55; font.pixelSize: Style.font.caption }
              Cell {
                anchors.verticalCenter: parent.verticalCenter
                width: root.colState
                text: root.shortState(siteRow.modelData.state)
                color: Theme.siteStateColor(siteRow.modelData.state, root.lightSurface)
                dim: siteRow.modelData.state === "up" ? 0.7 : 1
                font.pixelSize: Style.font.caption
              }
            }
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)
              visible: !siteActions.visible
              Repeater {
                model: siteRow.modelData.workers
                delegate: WorkerGlyph {
                  required property var modelData
                  lightSurface: root.lightSurface
                  anchors.verticalCenter: parent.verticalCenter
                  kind: modelData.kind
                  running: modelData.running
                  fontFamily: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            ActionRow {
              id: siteActions
              lightSurface: root.lightSurface
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              requests: Actions.siteActions(siteRow.modelData)
              panel: root.panel
              foreground: root.foreground
              revealed: siteRow.hovered || siteActions.hovered
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
              enabled: !siteActions.hovered
              onTapped: root.panel.openUrl(Actions.siteUrl(siteRow.modelData))
            }
          }
        }

        // WORKERS ────────────────────────────────────────────────────────
        SecHdr { visible: root.kinds.length > 0; text: "Workers"; count: root.workersRunning + "/" + root.workersTotal }
        Repeater {
          model: root.kinds
          delegate: TableRow {
            id: kindRow
            required property var modelData
            required property int index
            readonly property int down: modelData.total - modelData.running
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              WorkerGlyph {
                lightSurface: root.lightSurface
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(12)
                kind: kindRow.modelData.kind
                running: kindRow.modelData.running > 0
                fontFamily: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Cell { anchors.verticalCenter: parent.verticalCenter; width: root.colName; text: Theme.workerLabel(kindRow.modelData.kind); dim: 0.85 }
            }
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              Cell {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(30)
                horizontalAlignment: Text.AlignRight
                text: kindRow.modelData.running + "/" + kindRow.modelData.total
                color: kindRow.down > 0 ? root.stateColors.warn : root.stateColors.ok
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // Heal is the one bulk verb worth offering: it is lerd's own answer to
        // the workers it just reported unhealthy, so it only appears when
        // there are some.
        TableRow {
          id: healRow
          visible: root.summary.workers.down.length > 0
          Cell {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: root.colName
            text: "heal " + root.summary.workers.down.length + " unhealthy"
            dim: 0.5
            font.pixelSize: Style.font.caption
          }
          ActionRow {
            lightSurface: root.lightSurface
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            requests: [Actions.heal()]
            panel: root.panel
            foreground: root.foreground
            revealed: true
          }
        }

        // ENV ────────────────────────────────────────────────────────────
        SecHdr { text: "Env"; count: root.summary.nodeDefault !== "" ? "node " + root.summary.nodeDefault : "" }
        TableRow {
          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)
            EnvFlag { anchors.verticalCenter: parent.verticalCenter; letter: "N"; on: root.summary.nginx }
            EnvFlag { anchors.verticalCenter: parent.verticalCenter; letter: "D"; on: root.summary.dns }
            EnvFlag { anchors.verticalCenter: parent.verticalCenter; letter: "W"; on: root.summary.watcher }
            Item { width: Style.space(4); height: 1 }
            Cell {
              anchors.verticalCenter: parent.verticalCenter
              text: "nginx · ." + root.summary.tld + " dns · watcher"
              dim: 0.4
              font.pixelSize: Style.font.caption
            }
          }
        }
        TableRow {
          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Cell { anchors.verticalCenter: parent.verticalCenter; width: Style.space(28); text: "PHP"; dim: 0.5; font.pixelSize: Style.font.caption }
            Repeater {
              model: root.summary.php
              delegate: Row {
                id: phpItem
                required property var modelData
                readonly property bool isDefault: modelData.version === root.summary.phpDefault
                spacing: Style.space(3)
                StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.flagColor(phpItem.modelData.running, root.lightSurface) }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: phpItem.modelData.version
                  color: root.foreground
                  opacity: phpItem.isDefault ? 1 : 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: phpItem.isDefault
                }
              }
            }
          }
        }
        // SERVICES ───────────────────────────────────────────────────────
        SecHdr {
          visible: root.split.shared.length > 0 || root.split.workerCount > 0
          text: "Services"
          count: root.summary.services.up + "/" + root.summary.services.total
          note: root.summary.resources.available ? root.summary.resources.count + " containers" : ""
        }
        SubHdr { visible: root.split.shared.length > 0; text: "shared" }
        Repeater {
          model: root.split.shared
          delegate: TableRow {
            id: svcRow
            required property var modelData
            required property int index
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.serviceColor(svcRow.modelData, root.lightSurface) }
              Cell { anchors.verticalCenter: parent.verticalCenter; width: root.colName; text: svcRow.modelData.name }
              Cell {
                anchors.verticalCenter: parent.verticalCenter
                visible: !svcRow.modelData.up
                width: Style.space(60)
                text: svcRow.modelData.broken ? "failed" : svcRow.modelData.status
                color: Theme.serviceColor(svcRow.modelData, root.lightSurface)
                font.pixelSize: Style.font.caption
              }
            }
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)
              visible: !svcActions.visible
              Cell { anchors.verticalCenter: parent.verticalCenter; width: Style.space(76); horizontalAlignment: Text.AlignRight; text: svcRow.modelData.version; dim: 0.5; font.pixelSize: Style.font.caption }
              Cell { anchors.verticalCenter: parent.verticalCenter; width: Style.space(44); horizontalAlignment: Text.AlignRight; text: svcRow.modelData.port > 0 ? ":" + svcRow.modelData.port : ""; dim: 0.5; font.pixelSize: Style.font.caption }
            }

            ActionRow {
              id: svcActions
              lightSurface: root.lightSurface
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              requests: Actions.serviceActions(svcRow.modelData)
              panel: root.panel
              foreground: root.foreground
              revealed: svcRow.hovered || svcActions.hovered
            }
          }
        }

        SubHdr { visible: root.split.workerCount > 0; text: "workers · " + root.split.workerCount }
        Repeater {
          model: root.split.bySite
          delegate: Column {
            id: siteGroup
            required property var modelData
            width: tableCol.width
            spacing: 0
            SubHdr { text: siteGroup.modelData.site; indent: Style.space(24) }
            Repeater {
              model: siteGroup.modelData.rows
              delegate: TableRow {
                id: wRow
                required property var modelData
                required property int index
                Row {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(24)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  WorkerGlyph {
                    lightSurface: root.lightSurface
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(12)
                    kind: wRow.modelData.kind
                    running: wRow.modelData.up
                    fontFamily: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  Cell { anchors.verticalCenter: parent.verticalCenter; width: Style.space(190); text: wRow.modelData.name; dim: wRow.modelData.up ? 0.9 : 0.6 }
                }
                Row {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  visible: !workerActions.visible
                  Cell {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wRow.modelData.up ? "" : (wRow.modelData.broken ? "failed" : wRow.modelData.status)
                    color: Theme.serviceColor(wRow.modelData, root.lightSurface)
                    font.pixelSize: Style.font.caption
                  }
                  StatusDot { anchors.verticalCenter: parent.verticalCenter; color: Theme.serviceColor(wRow.modelData, root.lightSurface) }
                }

                ActionRow {
                  id: workerActions
                  lightSurface: root.lightSurface
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  requests: Actions.workerActions(wRow.modelData)
                  panel: root.panel
                  foreground: root.foreground
                  revealed: wRow.hovered || workerActions.hovered
                }
              }
            }
          }
        }

      }
    }
  }
}
