import QtQuick
import qs.Commons

// The actions a row offers, drawn over the right edge of that row rather than
// taking a column of their own: reserving the width would squeeze the name on
// every row, for icons that are only there on hover. A request that is busy or
// failed keeps its icons up even when the pointer leaves, so a spinner is
// never lost by moving the mouse.
//
// `hovered` is what a row ORs into `revealed`. Icons carry their own
// MouseArea, which takes the hover away from whatever the row uses to notice
// the pointer; without this the icons would hide themselves the instant the
// pointer reached them, reappear, and flicker at the frame rate.
Row {
  id: root

  property var requests: []
  property var panel: null
  property bool revealed: false
  property color foreground: "white"
  readonly property bool hovered: rowHover.hovered

  readonly property bool sticky: {
    if (!panel) return false
    for (var i = 0; i < requests.length; i++) {
      if (panel.actionState[requests[i].key]) return true
    }
    return false
  }

  spacing: Style.space(1)
  // Shown or not shown, with nothing in between: a fade would leave the icons
  // hoverable while they are on their way out.
  visible: revealed || sticky

  // A pointer handler rather than a MouseArea, so it reports the pointer over
  // the icons instead of losing it to their own MouseAreas.
  HoverHandler { id: rowHover }

  Repeater {
    model: root.requests
    delegate: ActionIcon {
      required property var modelData
      request: modelData
      panel: root.panel
      baseColor: root.foreground
    }
  }
}
