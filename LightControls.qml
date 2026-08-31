pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  property var controller: null
  property var device: null
  property var bar: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real brightnessMaximum: device && device.effective_maximum_percent ? device.effective_maximum_percent : 100
  property bool syncGroup: false
  property real groupMaximumLumens: 0
  property real groupNominalLumens: 0
  property string powerWarning: ""
  property int groupCount: 0
  readonly property color dim: Qt.darker(foreground, 1.5)
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  PanelHero {
    width: parent.width
    title: root.syncGroup ? "Synchronized Litra lights" : (device ? (device.display_name || device.name) : "Litra Beam")
    meta: root.syncGroup
      ? (root.groupCount + " LIGHTS  ·  FIRST POWERED-ON IS MASTER")
      : (device ? (device.address || "Connected") : "Unavailable")
    foreground: root.foreground
    iconComponent: Component {
      Row {
        spacing: Style.space(6)
        Text {
          visible: !root.syncGroup && root.device !== null
          text: root.device && root.device.transport === "usb" ? "󰕓" : root.device && root.device.transport === "bluetooth" ? "󰂯" : "󰘳"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
        Text {
          text: root.device && root.device.power === false ? "󰹏" : "󰛨"
          color: root.foreground
          opacity: root.device && root.device.power === false ? 0.45 : root.device && root.device.power === true ? 1.0 : 0.65
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }
  CursorSurface {
    width: parent.width
    implicitHeight: powerLabel.implicitHeight + Style.space(20)
    foreground: root.foreground
    bordered: true
    Text {
      id: powerLabel
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: "Power"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    ToggleSwitch {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      checked: root.device && root.device.power === true
      busy: root.controller ? root.controller.busy : false
      enabled: root.device !== null
      foreground: root.foreground
      onToggled: if (root.controller && root.device) root.controller.setPower(root.device.address, !checked)
    }
  }
  Text {
    width: parent.width
    text: root.syncGroup
      ? "GROUP EFFECTIVE MAXIMUM  " + (root.groupMaximumLumens || "—") + " lm  ·  NOMINAL " + (root.groupNominalLumens || "—") + " lm  ·  " + Math.round(root.brightnessMaximum) + "%"
      : root.device
      ? "EFFECTIVE MAXIMUM  " + (root.device.effective_maximum_lumens || "—") + " lm  ·  NOMINAL " + (root.device.maximum_lumens || "—") + " lm  ·  " + Math.round(root.brightnessMaximum) + "%"
      : "POWER CAPACITY  —"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    wrapMode: Text.WordWrap
  }
  BorderSurface {
    visible: root.powerWarning !== ""
    width: parent.width
    implicitHeight: warningText.implicitHeight + Style.space(20)
    color: "transparent"
    borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
    radius: Style.cornerRadius
    Text {
      id: warningText
      anchors.fill: parent
      anchors.margins: Style.space(10)
      text: "⚠  " + root.powerWarning
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
  }
  Item {
    width: parent.width
    implicitHeight: brightnessTitle.implicitHeight
    PanelSectionHeader { id: brightnessTitle; text: "BRIGHTNESS"; foreground: root.foreground; fontFamily: root.fontFamily; anchors.left: parent.left }
    Text { anchors.right: parent.right; text: Math.round(brightness.dragging ? brightness.liveValue : (root.device && root.device.brightness !== null ? root.device.brightness : 50)) + "%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
  }
  PowerLimitedSlider {
    id: brightness
    width: parent.width
    bar: root.bar
    effectiveMaximum: root.brightnessMaximum
    value: root.device && root.device.brightness !== null ? root.device.brightness : 50
    onReleased: function(value) { if (root.controller && root.device) root.controller.setBrightness(root.device.address, value) }
  }
  Text {
    visible: root.brightnessMaximum < 100
    width: parent.width
    text: root.syncGroup
      ? "The synchronized slider stops at the maximum every connected light can reach."
      : "The brightness control stops here because this light’s current USB power source cannot provide the full output."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Item {
    width: parent.width
    implicitHeight: temperatureTitle.implicitHeight
    PanelSectionHeader { id: temperatureTitle; text: "COLOR TEMPERATURE"; foreground: root.foreground; fontFamily: root.fontFamily; anchors.left: parent.left }
    Text { anchors.right: parent.right; text: Math.round(temperature.dragging ? temperature.liveValue : (root.device && root.device.temperature !== null ? root.device.temperature : 4000)) + " K"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
  }
  PanelSlider {
    id: temperature
    width: parent.width
    bar: root.bar
    minimum: 2700; maximum: 6500; step: 100; integer: true; tickCount: 5
    value: root.device && root.device.temperature !== null ? root.device.temperature : 4000
    onReleased: function(value) { if (root.controller && root.device) root.controller.setTemperature(root.device.address, Math.round(value / 100) * 100) }
  }
  Row {
    width: parent.width
    Text { text: "WARM"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth) ; height: 1 }
    Text { text: "COOL"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
  }
}
