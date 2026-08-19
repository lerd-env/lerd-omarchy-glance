import QtQuick
import qs.Commons

// The actions a row offers, drawn over the right edge of that row rather than
// taking a column of their own: reserving the width would squeeze the name on
// every row, for icons that are only there on hover. A request that is busy or
// failed keeps its icons up even when the pointer leaves, so a spinner is
// never lost by moving the mouse.
Row {
  id: root

  property var requests: []
  property var panel: null
  property bool revealed: false
  property color foreground: "white"

  readonly property bool sticky: {
    if (!panel) return false
    for (var i = 0; i < requests.length; i++) {
      if (panel.actionState[requests[i].key]) return true
    }
    return false
  }

  spacing: Style.space(1)
  opacity: revealed || sticky ? 1 : 0
  visible: opacity > 0

  Behavior on opacity { NumberAnimation { duration: 80 } }

  Repeater {
    model: root.requests
    delegate: ActionIcon {
      required property var modelData
      request: modelData
      panel: root.panel
      baseColor: root.foreground
      enabled: root.opacity > 0 && !busy
    }
  }
}
