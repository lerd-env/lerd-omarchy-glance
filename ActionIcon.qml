import QtQuick
import qs.Commons
import qs.Ui
import "Theme.js" as Theme

// One icon-only action. Three states, all read from the widget's actionState
// so the row shows what its own request is doing: idle, spinning while the
// request is in flight, and red with the refusal as its tooltip when lerd
// said no. Disabled while busy, which also drops the hover fill, so the
// spinning glyph is all that moves.
PanelActionButton {
  id: root

  property var request: null
  // The row's own foreground; the icon only leaves it to say it failed.
  property color baseColor: "white"
  // Which set of state colours the surface under this icon wants.
  property bool lightSurface: false
  readonly property color failColor: Theme.palette(lightSurface).bad
  // Anything with run(request) and actionState — the panel, which forwards
  // to the widget that owns the polling.
  property var panel: null

  readonly property string phase: (panel && request && panel.actionState[request.key]) || ""
  readonly property bool busy: phase === "busy"
  readonly property bool failed: phase !== "" && !busy

  visible: !!request
  enabled: !!request && !busy
  iconText: busy ? Theme.icon("spinner") : (request ? Theme.icon(request.icon) : "")
  tooltipText: failed ? phase : (request ? request.label : "")
  foreground: failed ? failColor : baseColor
  hoverColor: failed ? failColor : baseColor
  size: Style.space(20)
  fontSize: Style.font.bodySmall
  focusable: true

  onClicked: if (panel && request) panel.run(request)

  // The refusal is worth seeing without hovering, so the glyph itself carries
  // the colour until the widget forgets the error.
  Rectangle {
    anchors.fill: parent
    z: -1
    radius: Style.space(4)
    visible: root.failed
    color: root.failColor
    opacity: 0.16
  }

  RotationAnimator on rotation {
    running: root.busy
    loops: Animation.Infinite
    from: 0
    to: 360
    duration: 900
  }

  onBusyChanged: if (!busy) rotation = 0
}
