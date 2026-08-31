import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var bar: null
  property real value: 0
  property real effectiveMaximum: 100
  property real liveValue: value
  property bool dragging: false
  property color foreground: bar ? bar.foreground : Color.foreground
  readonly property real cappedMaximum: Math.max(0, Math.min(100, effectiveMaximum))
  readonly property real progress: Math.max(0, Math.min(1, liveValue / 100))
  signal moved(real value)
  signal released(real value)

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knob.height + Style.spacing.md)
  onValueChanged: if (!dragging) liveValue = Math.min(value, cappedMaximum)
  onEffectiveMaximumChanged: if (!dragging) liveValue = Math.min(value, cappedMaximum)

  Rectangle {
    id: fullTrack
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
    radius: height / 2
    color: Style.normalFillFor(root.foreground, Color.accent)
    opacity: 0.42
  }
  Rectangle {
    id: availableTrack
    anchors.left: fullTrack.left
    anchors.verticalCenter: fullTrack.verticalCenter
    width: fullTrack.width * root.cappedMaximum / 100
    height: fullTrack.height
    radius: fullTrack.radius
    color: Style.selectedFillFor(root.foreground, Color.accent)
    opacity: 0.7
  }
  Rectangle {
    anchors.left: fullTrack.left
    anchors.verticalCenter: fullTrack.verticalCenter
    width: fullTrack.width * root.progress
    height: fullTrack.height
    radius: fullTrack.radius
    color: root.foreground
  }
  Rectangle {
    visible: root.cappedMaximum < 100
    x: Math.round(fullTrack.width * root.cappedMaximum / 100) - width / 2
    anchors.verticalCenter: fullTrack.verticalCenter
    width: Math.max(2, Style.space(2))
    height: fullTrack.height + Style.space(10)
    radius: 1
    color: root.foreground
  }
  BorderSurface {
    id: knob
    width: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
    height: width
    radius: width / 2
    anchors.verticalCenter: fullTrack.verticalCenter
    x: Math.max(0, Math.min(fullTrack.width - width, fullTrack.width * root.progress - width / 2))
    color: root.foreground
    borderSpec: Border.flat(root.bar ? root.bar.background : Color.background, Math.max(1, Style.space(2)))
  }
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    function valueFromX(position) {
      var raw = Math.round(Math.max(0, Math.min(fullTrack.width, position)) / fullTrack.width * 100)
      return Math.min(raw, root.cappedMaximum)
    }
    onPressed: function(mouse) { root.dragging = true; root.liveValue = valueFromX(mouse.x); root.moved(root.liveValue) }
    onPositionChanged: function(mouse) { if (root.dragging) { root.liveValue = valueFromX(mouse.x); root.moved(root.liveValue) } }
    onReleased: function(mouse) { root.dragging = false; root.released(root.liveValue) }
    onWheel: function(wheel) {
      root.liveValue = Math.max(0, Math.min(root.cappedMaximum, root.liveValue + (wheel.angleDelta.y > 0 ? 1 : -1)))
      root.moved(root.liveValue)
      root.released(root.liveValue)
    }
  }
}
