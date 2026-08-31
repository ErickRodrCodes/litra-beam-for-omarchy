import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.tbogard.litra-lights"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var litraService: null
  function open() { controller.show(); if (litraService) litraService.reconnect() }
  function close() { controller.hide() }
  function switchPanel(direction) { return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(hostWidget || root, direction) : false }

  Timer {
    id: reconnectTimer
    interval: root.litraService ? root.litraService.reconnectIntervalMs : 500
    repeat: true
    running: root.opened && root.litraService
    triggeredOnStart: true
    onTriggered: if (root.litraService) root.litraService.reconnect()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(view.implicitHeight, Style.space(620))
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: view.activate()
      onCloseRequested: view.goBack()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { view.handleTextKey(text) }
      LitraView {
        id: view
        width: parent.width
        controller: root.litraService
        bar: root.bar
        foreground: root.bar ? root.bar.foreground : Color.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        previewEnabled: root.opened
        onDismissRequested: root.close()
      }
    }
  }
}
