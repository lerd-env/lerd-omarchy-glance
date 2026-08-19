import QtQuick
import qs.Commons
import "Theme.js" as Theme

// "● nginx" — a labelled state dot for the environment line.
Row {
  id: flag

  property string text: ""
  property bool on: true
  property color foreground: "white"
  property string fontFamily: Style.font.family

  spacing: Style.space(4)

  StatusDot {
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.flagColor(flag.on)
  }
  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: flag.text
    color: flag.foreground
    opacity: 0.8
    font.family: flag.fontFamily
    font.pixelSize: Style.font.caption
  }
}
