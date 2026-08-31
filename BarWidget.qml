import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.tbogard.litra-lights"
  readonly property var litraService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property int lightCount: litraService ? litraService.count : 0
  readonly property bool syncEnabled: litraService ? litraService.syncEnabled : false
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.litraService = root.litraService
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onLitraServiceChanged: injectPanel()
  Loader { id: panelLoader; active: true; source: Qt.resolvedUrl("Panel.qml"); visible: false; onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) } }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Text {
        anchors.centerIn: parent
        text: "󰛨"
        color: root.bar ? root.bar.foreground : Color.foreground
        font.pixelSize: Style.space(12)
      }
    }
    opacity: root.lightCount ? 1.0 : 0.55
    tooltipText: root.lightCount ? "Litra: " + root.lightCount + " connected" + (root.syncEnabled && root.lightCount > 1 ? " · synced" : "") : "Litra: no lights connected"
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
  }
}
