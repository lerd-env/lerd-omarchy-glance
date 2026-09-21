import QtQuick
import qs.Commons
import "Theme.js" as Theme

// The Nerd Font glyph for a worker kind in that kind's colour, greyed when
// the worker is not running.
Text {
  property string kind: "queue"
  property bool running: true
  property bool lightSurface: false
  property string fontFamily: Style.font.family

  text: Theme.workerGlyph(kind)
  color: Theme.workerKindColor(kind, running, lightSurface)
  font.family: fontFamily
  font.pixelSize: Style.font.bodySmall
}
