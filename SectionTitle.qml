import QtQuick
import qs.Commons

// "SITES                 7/9 ●" — a small-caps section header with an
// optional count on the right and an optional state dot.
Item {
  id: root

  property string text: ""
  property string count: ""
  property string note: ""
  property color dotColor: "transparent"
  property bool showDot: false
  property color foreground: "white"
  property string fontFamily: Style.font.family

  implicitHeight: Style.space(18)

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.text.toUpperCase()
    color: root.foreground
    opacity: 0.55
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.6
  }

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.note !== ""
      text: root.note
      color: root.foreground
      opacity: 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.count !== ""
      text: root.count
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    StatusDot {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showDot
      color: root.dotColor
    }
  }
}
