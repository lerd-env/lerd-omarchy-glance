import QtQuick

// lerd's L, drawn rather than shipped as SVG because the real icon carries an
// embedded webfont Qt will not render, and monochrome so it takes the bar's
// foreground in either theme.
Item {
  id: mark
  property int size: 14
  property color foreground: "white"

  implicitWidth: size
  implicitHeight: size

  Text {
    anchors.centerIn: parent
    text: "L"
    color: mark.foreground
    font.pixelSize: mark.size
    font.bold: true
  }
}
