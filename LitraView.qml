pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var controller: null
  property var bar: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int selectedIndex: -1
  property int currentTab: 0
  property bool expanded: false
  property bool previewEnabled: false
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property var devices: controller ? controller.devices : []
  readonly property bool syncEnabled: controller ? controller.syncEnabled : false
  readonly property bool syncActive: syncEnabled && devices.length > 1
  signal dismissRequested()
  implicitHeight: content.implicitHeight

  function goBack() {
    if (currentTab === 0 && selectedIndex >= 0) selectedIndex = -1
    else dismissRequested()
  }
  function activate() {}
  function handleTextKey(t) { if ((t === "r" || t === "R") && controller) controller.refresh() }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(12)

    PanelHero {
      width: parent.width
      title: "Litra Beam for Omarchy"
      meta: root.controller ? root.controller.message : "Loading…"
      foreground: root.foreground
      iconComponent: Component { Text { text: "󰛨"; color: root.foreground; font.pixelSize: Style.font.display } }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: ["Lights", "Camera", "Settings"]
        CursorSurface {
          required property string modelData
          required property int index
          width: (root.width - Style.space(16)) / 3
          implicitHeight: tabLabel.implicitHeight + Style.space(20)
          foreground: root.foreground
          bordered: true
          opacity: root.currentTab === index ? 1 : 0.62
          Text {
            id: tabLabel
            anchors.centerIn: parent
            text: modelData
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: root.currentTab === index
          }
          Rectangle {
            visible: root.currentTab === index
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(2, Style.space(2))
            color: root.foreground
            radius: height / 2
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.currentTab = index
              root.selectedIndex = -1
            }
          }
        }
      }
    }

    Column {
      visible: root.currentTab === 0
      width: parent.width
      spacing: Style.space(12)

      CursorSurface {
        visible: root.devices.length > 1
        width: parent.width
        implicitHeight: globalSyncLabel.implicitHeight + Style.space(20)
        foreground: root.foreground
        bordered: true
        Text {
          id: globalSyncLabel
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "Sync lights"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        ToggleSwitch {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          checked: root.syncEnabled
          busy: root.controller ? root.controller.busy : false
          enabled: root.devices.length > 0
          foreground: root.foreground
          onToggled: if (root.controller) root.controller.setSync(!root.syncEnabled)
        }
      }

      Text {
        visible: root.syncActive
        width: parent.width
        text: "The first powered-on light is the master. Power, brightness, and temperature changes apply to all lights."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Item {
        visible: root.selectedIndex >= 0 && !root.syncActive
        width: parent.width
        implicitHeight: backText.implicitHeight + Style.space(12)
        Text { id: backText; text: "‹  All Litra lights"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedIndex = -1 }
      }

      Column {
        visible: root.selectedIndex < 0 && !root.syncActive
        width: parent.width
        spacing: Style.space(10)
        PanelSeparator { width: parent.width; foreground: root.foreground }
        Text { text: root.devices.length ? "CONNECTED LIGHTS" : "NO CONNECTED LIGHTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
        Text {
          visible: root.devices.length === 0
          width: parent.width
          text: "Open the Settings tab for connection and pairing instructions."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
        Repeater {
          model: root.devices
          CursorSurface {
          required property var modelData
          required property int index
          width: root.width
          implicitHeight: Math.max(deviceLabel.implicitHeight, transportIcon.implicitHeight) + Style.space(20)
          foreground: root.foreground
          bordered: true
          Text {
            id: transportIcon
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.transport === "usb" ? "󰕓" : modelData.transport === "bluetooth" ? "󰂯" : "󰘳"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
          Text {
            id: deviceLabel
            anchors.left: transportIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: arrow.left
            anchors.verticalCenter: parent.verticalCenter
            text: (modelData.display_name || modelData.name) + "\n"
              + (modelData.address || "Connected")
              + "  ·  " + (modelData.brightness_lumens !== null ? modelData.brightness_lumens + " lm" : "— lm")
              + "  ·  " + (modelData.brightness !== null ? modelData.brightness + "%" : "—%")
              + "  ·  " + (modelData.temperature !== null ? modelData.temperature + " K" : "— K")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text { id: arrow; anchors.right: parent.right; anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.dim; font.pixelSize: Style.font.subtitle }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedIndex = index }
          }
        }
      }

      LightControls {
      visible: root.syncActive
      width: parent.width
      controller: root.controller
      device: root.devices.length ? root.devices[0] : null
      bar: root.bar
      foreground: root.foreground
      fontFamily: root.fontFamily
      brightnessMaximum: root.controller ? root.controller.synchronizedBrightnessMaximum() : 100
      syncGroup: true
      groupMaximumLumens: root.controller ? root.controller.synchronizedMaximumLumens() : 0
      groupNominalLumens: root.controller ? root.controller.synchronizedNominalLumens() : 0
      powerWarning: root.controller ? root.controller.syncPowerWarning() : ""
      groupCount: root.devices.length
      }
      LightControls {
      visible: !root.syncActive && root.selectedIndex >= 0 && root.selectedIndex < root.devices.length
      width: parent.width
      controller: root.controller
      device: root.selectedIndex >= 0 && root.selectedIndex < root.devices.length ? root.devices[root.selectedIndex] : null
      bar: root.bar
      foreground: root.foreground
      fontFamily: root.fontFamily
      brightnessMaximum: device && device.effective_maximum_percent ? device.effective_maximum_percent : 100
      }
      Item {
      width: parent.width
      implicitHeight: actionStatus.implicitHeight
      Text {
        id: actionStatus
        text: "Applying changes…"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        opacity: root.controller && root.controller.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
      }
      }
    }

    CameraAutomation {
      visible: root.currentTab === 1
      previewEnabled: root.previewEnabled && root.currentTab === 1
      width: parent.width
      controller: root.controller
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    LitraSettings {
      visible: root.currentTab === 2
      width: parent.width
      controller: root.controller
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
