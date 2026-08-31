import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var shell: null
  property var manifest: null
  readonly property string pluginDir: manifest && manifest.__sourceDir ? manifest.__sourceDir : Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.tbogard.litra-lights"
  property var devices: []
  property bool syncEnabled: false
  property string selectedCameraId: ""
  property bool cameraAutomationEnabled: false
  property bool cameraExternalUse: false
  property bool cameraPreviewActive: false
  property var automationPowerTarget: null
  property bool automationInitialized: false
  readonly property bool cameraInUse: cameraExternalUse || cameraPreviewActive
  property int reconnectIntervalMs: 500
  property bool busy: false
  property string message: "Looking for Litra lights…"
  property bool topologyRefreshPending: false
  readonly property int count: devices.length

  function synchronizedBrightnessMaximum() {
    if (!devices.length) return 100
    var result = 100
    for (var i = 0; i < devices.length; i++)
      result = Math.min(result, devices[i].effective_maximum_percent || 100)
    return result
  }

  function synchronizedMaximumLumens() {
    if (!devices.length) return 0
    var result = devices[0].effective_maximum_lumens || devices[0].maximum_lumens || 0
    for (var i = 1; i < devices.length; i++)
      result = Math.min(result, devices[i].effective_maximum_lumens || devices[i].maximum_lumens || result)
    return result
  }

  function synchronizedNominalLumens() {
    if (!devices.length) return 0
    var result = devices[0].maximum_lumens || 0
    for (var i = 1; i < devices.length; i++)
      result = Math.min(result, devices[i].maximum_lumens || result)
    return result
  }

  function syncPowerWarning() {
    if (!syncEnabled || devices.length < 2) return ""
    var ceiling = synchronizedMaximumLumens()
    var limited = []
    for (var i = 0; i < devices.length; i++) {
      var effective = devices[i].effective_maximum_lumens || devices[i].maximum_lumens || 0
      var nominal = devices[i].maximum_lumens || effective
      if (effective < nominal)
        limited.push((devices[i].address || devices[i].name) + " · " + effective + " lm max")
    }
    if (!limited.length) return ""
    var masterLumens = devices[0].brightness_lumens || 0
    if (masterLumens > ceiling)
      return "Cannot match the master at " + masterLumens + " lm. Power-limited: " + limited.join(", ")
    return "Sync brightness is capped at " + ceiling + " lm by: " + limited.join(", ")
  }


  function refresh() {
    if (statusProcess.running || actionProcess.running || reconnectProcess.running) return
    statusProcess.command = [pluginDir + "/scripts/litra-control.py", "status"]
    statusProcess.running = true
  }

  function reconnect() {
    if (busy || statusProcess.running || actionProcess.running || reconnectProcess.running) return
    if (!devices.length) message = "Waiting for Litra lights…"
    var command = [pluginDir + "/scripts/litra-control.py", "reconnect"]
    for (var i = 0; i < devices.length; i++)
      if (devices[i].address) command.push(String(devices[i].address))
    reconnectProcess.command = command
    reconnectProcess.running = true
  }

  function applyStatus(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      devices = data.devices || []
      syncEnabled = data.sync === true
      selectedCameraId = String(data.camera_id || "")
      cameraAutomationEnabled = data.camera_automation === true
      if (!automationInitialized) {
        automationInitialized = true
        if (cameraAutomationEnabled) {
          automationPowerTarget = cameraInUse
          flushAutomationPower()
        }
      }
      reconnectIntervalMs = Math.max(500, Number(data.reconnect_interval_ms || 500))
      message = devices.length ? devices.length + " connected light" + (devices.length === 1 ? "" : "s") : "No connected Litra lights"
    } catch (error) {
      message = "Could not read Litra status"
    }
  }

  function applyReconnect(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      var discovered = (data.device_ids || []).map(function(value) { return String(value) }).sort()
      var current = devices.map(function(device) { return String(device.address || "") }).sort()
      topologyRefreshPending = JSON.stringify(discovered) !== JSON.stringify(current)
    } catch (error) {
      topologyRefreshPending = false
    }
  }

  function run(args) {
    if (busy) return
    busy = true
    actionProcess.command = [pluginDir + "/scripts/litra-control.py"].concat(args)
    actionProcess.running = true
  }

  function checkCameraActivity() {
    if (!selectedCameraId || cameraActivityProcess.running) {
      if (!selectedCameraId) setCameraExternalUse(false)
      return
    }
    cameraActivityProcess.command = [pluginDir + "/scripts/litra-control.py", "camera-active", selectedCameraId]
    cameraActivityProcess.running = true
  }

  function applyCameraActivity(text) {
    try {
      var active = JSON.parse(String(text || "{}")).active === true
      setCameraExternalUse(active)
    } catch (error) {
      setCameraExternalUse(false)
    }
  }

  function setCameraExternalUse(active) {
    var wasInUse = cameraInUse
    cameraExternalUse = active
    cameraUseChanged(wasInUse)
  }

  function setCameraPreviewActive(active) {
    var wasInUse = cameraInUse
    cameraPreviewActive = active
    cameraUseChanged(wasInUse)
  }

  function cameraUseChanged(wasInUse) {
    if (cameraAutomationEnabled && wasInUse !== cameraInUse) {
      if (cameraInUse) {
        automationOffTimer.stop()
        automationPowerTarget = true
        flushAutomationPower()
      } else {
        automationOffTimer.restart()
      }
    }
  }

  function flushAutomationPower() {
    if (automationPowerTarget === null || busy) return
    var enabled = automationPowerTarget === true
    automationPowerTarget = null
    run(["camera-power", enabled ? "on" : "off"])
  }

  function optimistic(address, field, value) {
    var next = []
    for (var i = 0; i < devices.length; i++) {
      var copy = Object.assign({}, devices[i])
      if (syncEnabled || copy.address === address) copy[field] = value
      next.push(copy)
    }
    devices = next
  }

  function setSync(enabled) {
    syncEnabled = enabled
    run(["sync", enabled ? "on" : "off"])
  }
  function setCamera(cameraId) {
    setCameraPreviewActive(false)
    selectedCameraId = cameraId
    setCameraExternalUse(false)
    run(["camera", cameraId])
  }
  function setCameraAutomation(enabled) {
    cameraAutomationEnabled = enabled
    if (!enabled) automationOffTimer.stop()
    automationPowerTarget = enabled ? cameraInUse : null
    run(["camera-automation", enabled ? "on" : "off"])
  }
  function setReconnectInterval(milliseconds) {
    reconnectIntervalMs = Math.max(500, Math.round(milliseconds))
    run(["reconnect-interval", String(reconnectIntervalMs)])
  }
  function setPower(address, enabled) {
    optimistic(address, "power", enabled)
    run(["power", address, enabled ? "1" : "0"])
  }
  function setBrightness(address, value) {
    optimistic(address, "brightness", Math.round(value))
    run(["brightness", address, String(Math.round(value))])
  }
  function setTemperature(address, value) {
    optimistic(address, "temperature", Math.round(value))
    run(["temperature", address, String(Math.round(value))])
  }

  Timer { interval: 4000; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.checkCameraActivity() }
  Timer {
    id: automationOffTimer
    interval: 500
    repeat: false
    onTriggered: {
      if (root.cameraAutomationEnabled && !root.cameraInUse) {
        root.automationPowerTarget = false
        root.flushAutomationPower()
      }
    }
  }
  Process {
    id: statusProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
  }
  Process {
    id: actionProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyStatus(text) }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (String(text).trim()) root.message = String(text).trim() }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.refresh()
      else Qt.callLater(function() { root.flushAutomationPower() })
    }
  }
  Process {
    id: cameraActivityProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyCameraActivity(text) }
  }
  Process {
    id: reconnectProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyReconnect(text) }
    onExited: function() {
      if (root.topologyRefreshPending) {
        root.topologyRefreshPending = false
        Qt.callLater(function() { root.refresh() })
      }
    }
  }
  Component.onCompleted: refresh()
}
