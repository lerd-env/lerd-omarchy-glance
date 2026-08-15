import QtQuick
import qs.Commons

// One line of the summary: an optional glyph and a label on the left, the value
// and anything else on the right, so the whole block reads as two columns.
Item {
  id: row

  property string glyph: ""
  property color glyphColor: "white"
  property string label: ""
  property string value: ""
  property color foreground: "white"
  property string fontFamily: Style.font.family
  default property alias trailing: extra.data

  implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)

  Row {
    id: left
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: row.glyph !== ""
      text: row.glyph
      color: row.glyphColor
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      color: row.foreground
      opacity: 0.7
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Row {
    id: right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: row.value !== ""
      text: row.value
      color: row.foreground
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Row {
      id: extra
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
    }
  }
}
