import QtQuick
import QtQuick.Shapes

// The Lerd containers, traced from lerd's tray icon (internal/tray/assets/
// running.svg) and drawn in one colour so they take the bar's foreground in
// either theme. Depth comes from opacity, as in the tray's mono icon.
Item {
  id: mark
  property int size: 14
  property color foreground: "white"

  // Sized to the containers themselves (30 x 34 units), not the tray's padded
  // square, so they match the bar's other icons.
  implicitWidth: Math.round(size * 30 / 34)
  implicitHeight: size

  Shape {
    x: -5.5 * scale
    y: -3.5 * scale
    width: 41
    height: 41
    scale: mark.size / 34
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer

    component Face: ShapePath {
      property real opacity: 1
      strokeWidth: -1
      fillColor: Qt.rgba(mark.foreground.r, mark.foreground.g, mark.foreground.b, mark.foreground.a * opacity)
      fillRule: ShapePath.OddEvenFill
    }

    // Side faces.
    Face { opacity: 0.7; PathSvg { path: "M28.5,24.5l7,3l0,10l-7,0l0,-13Z" } }
    Face { opacity: 0.7; PathSvg { path: "M14.5,26.357l0,-22.857l6,3l0,18.429l-6,1.428Z" } }
    // Fronts, with the windows cut out.
    Face { PathSvg { path: "M5.5,29.5l21,-5l0,13l-21,0l0,-8Zm9.5,-0.262l0,6.262l2,0l0,-6.738l-2,0.476Zm-5.75,1.369l0,4.893l2,0l0,-5.369l-2,0.476Zm11.5,-2.738l0,7.631l2,0l0,-8.107l-2,0.476Z" } }
    Face { PathSvg { path: "M5.5,28.5l0,-22l7,-3l0,23.333l-7,1.667Zm1.5,-6.435l0,2.026l4,-1.091l0,-2.095l-4,1.16Zm0,-12.156l0,2.026l4,-1.507l0,-2.095l-4,1.576Zm0,6.078l0,2.026l4,-1.299l0,-2.095l-4,1.368Z" } }
    // Windows.
    Face { opacity: 0.3; PathSvg { path: "M9.25,30.607l2,-0.476l0,5.369l-2,0l0,-4.893Z" } }
    Face { opacity: 0.3; PathSvg { path: "M15,29.238l2,-0.476l0,6.738l-2,0l0,-6.262Z" } }
    Face { opacity: 0.3; PathSvg { path: "M20.75,27.869l2,-0.476l0,8.107l-2,0l0,-7.631Z" } }
    Face { opacity: 0.3; PathSvg { path: "M7,9.909l4,-1.576l0,2.095l-4,1.507l0,-2.026Z" } }
    Face { opacity: 0.3; PathSvg { path: "M7,15.987l4,-1.368l0,2.095l-4,1.299l0,-2.026Z" } }
    Face { opacity: 0.3; PathSvg { path: "M7,22.065l4,-1.16l0,2.095l-4,1.091l0,-2.026Z" } }
  }
}
