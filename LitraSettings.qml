import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  property var controller: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property int reconnectIntervalMs: controller ? controller.reconnectIntervalMs : 500
  spacing: Style.space(12)

  Text {
    width: parent.width
    text: "DEVICE DISCOVERY"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Dropdown {
    width: parent.width
    label: "Reconnect interval"
    value: String(root.reconnectIntervalMs)
    options: [
      { value: "500", label: "0.5 seconds" },
      { value: "1000", label: "1 second" },
      { value: "2000", label: "2 seconds" },
      { value: "5000", label: "5 seconds" },
      { value: "10000", label: "10 seconds" }
    ]
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) {
      if (root.controller) root.controller.setReconnectInterval(Number(value))
    }
  }

  Text {
    width: parent.width
    text: "While this panel is open, paired Litra lights are checked at this rate. Already connected lights are left alone."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  Text {
    width: parent.width
    text: "CONNECTING LIGHTS"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Text {
    width: parent.width
    text: "• USB — Connect the light with a USB cable; detected automatically"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    text: "• Bluetooth — Turn on the light, hold its Bluetooth button, and pair it in Omarchy Bluetooth settings"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    text: "Listed but not connected: remove the light from the paired-device list in Omarchy Bluetooth settings. Then hold its Bluetooth button and pair it again."
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }
}
