import QtQuick
import qs.Commons

// The dashboard's resource meter: a small caps label, the value on the right,
// and a thin track underneath.
Item {
  id: meter

  property string label: ""
  property string value: ""
  property string caption: ""
  property real percent: 0
  property color fill: "#10b981"
  property color foreground: "white"
  property string fontFamily: Style.font.family

  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(3)

    Item {
      width: parent.width
      height: labelText.implicitHeight

      Text {
        id: labelText
        text: meter.label
        color: meter.foreground
        opacity: 0.6
        font.family: meter.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        text: meter.value
        color: meter.foreground
        font.family: meter.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    Rectangle {
      width: parent.width
      height: Style.space(3)
      radius: height / 2
      // Alpha on the colour, not opacity, so the fill on top stays solid.
      color: Qt.rgba(meter.foreground.r, meter.foreground.g, meter.foreground.b, 0.12)

      Rectangle {
        width: Math.max(0, Math.min(1, meter.percent / 100)) * parent.width
        height: parent.height
        radius: parent.radius
        color: meter.fill
      }
    }

    Text {
      width: parent.width
      visible: meter.caption !== ""
      text: meter.caption
      color: meter.foreground
      opacity: 0.5
      font.family: meter.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
