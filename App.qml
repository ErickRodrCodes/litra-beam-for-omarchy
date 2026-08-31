import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  function open(payloadJson) { opened = true; if (service) service.reconnect(); Qt.callLater(function() { keyCatcher.forceActiveFocus() }) }
  function dismiss() { opened = false; if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "io.github.tbogard.litra-lights") }
  // Called by the shell host after hide(); do not call hide() again here.
  function close() { opened = false }
  function toggle() { if (opened) dismiss(); else open("{}") }
  Timer {
    id: reconnectTimer
    interval: root.service ? root.service.reconnectIntervalMs : 500
    repeat: true
    running: root.opened && root.service
    triggeredOnStart: true
    onTriggered: if (root.service) root.service.reconnect()
  }
  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "litra-lights"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    BorderSurface {
      width: Math.min(Style.space(680), parent.width - Style.gapsOut * 2)
      height: Math.min(view.implicitHeight + Style.spacing.panelPadding * 2, parent.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
      MouseArea { anchors.fill: parent; onClicked: {} }
      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) { view.goBack(); event.accepted = true }
          else if (event.text && event.text.length === 1) { view.handleTextKey(event.text); event.accepted = true }
        }
        LitraView {
          id: view
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          controller: root.service
          foreground: Color.foreground
          fontFamily: Style.font.family
          expanded: true
          previewEnabled: root.opened
          onDismissRequested: root.dismiss()
        }
      }
    }
  }
}
