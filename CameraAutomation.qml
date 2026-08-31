import QtQuick
import QtMultimedia
import qs.Commons
import qs.Ui

Column {
  id: root
  property var controller: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool previewEnabled: false
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property var cameras: mediaDevices.videoInputs
  readonly property string selectedCameraId: controller ? controller.selectedCameraId : ""
  readonly property bool automationEnabled: controller ? controller.cameraAutomationEnabled : false
  readonly property bool cameraExternalUse: controller ? controller.cameraExternalUse : false
  property string previewError: ""
  spacing: Style.space(12)

  MediaDevices { id: mediaDevices }

  function cameraId(camera) { return String(camera.id) }
  function selectedCamera() {
    for (var i = 0; i < root.cameras.length; i++)
      if (cameraId(root.cameras[i]) === root.selectedCameraId) return root.cameras[i]
    return mediaDevices.defaultVideoInput
  }
  function cameraOptions() {
    var result = [{ value: "", label: root.cameras.length ? "Select a camera…" : "No cameras available" }]
    var selectionFound = root.selectedCameraId === ""
    for (var i = 0; i < root.cameras.length; i++) {
      var id = cameraId(root.cameras[i])
      result.push({ value: id, label: root.cameras[i].description || "Camera " + (i + 1) })
      if (id === root.selectedCameraId) selectionFound = true
    }
    if (!selectionFound)
      result.push({ value: root.selectedCameraId, label: "Previously selected camera (unavailable)" })
    return result
  }

  Text {
    width: parent.width
    text: "AVAILABLE CAMERAS"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Dropdown {
    width: parent.width
    label: "Camera used for light automation"
    value: root.selectedCameraId
    options: root.cameraOptions()
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) {
      if (root.controller) root.controller.setCamera(value)
    }
  }

  CursorSurface {
    visible: root.selectedCameraId !== ""
    width: parent.width
    implicitHeight: automationLabel.implicitHeight + Style.space(20)
    foreground: root.foreground
    bordered: true
    Text {
      id: automationLabel
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.right: automationToggle.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: "Turn lights automatically when camera is being used"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }
    ToggleSwitch {
      id: automationToggle
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      checked: root.automationEnabled
      busy: root.controller ? root.controller.busy : false
      foreground: root.foreground
      onToggled: if (root.controller) root.controller.setCameraAutomation(!root.automationEnabled)
    }
  }

  Rectangle {
    visible: root.selectedCameraId !== ""
    width: parent.width
    implicitHeight: width * 9 / 16
    color: "black"
    radius: Style.cornerRadius
    clip: true

    VideoOutput {
      id: videoPreview
      anchors.fill: parent
      visible: !root.cameraExternalUse && root.previewError === ""
      fillMode: VideoOutput.PreserveAspectCrop
    }

    Text {
      anchors.centerIn: parent
      width: parent.width - Style.space(32)
      horizontalAlignment: Text.AlignHCenter
      text: root.cameraExternalUse
        ? "Camera is being used by another application"
        : (root.previewError || "Starting camera preview…")
      color: "white"
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
      visible: root.cameraExternalUse || root.previewError !== "" || !previewCamera.active
    }
  }

  Camera {
    id: previewCamera
    cameraDevice: root.selectedCamera()
    active: root.previewEnabled && root.selectedCameraId !== "" && !root.cameraExternalUse
    onErrorOccurred: function(error, errorString) {
      root.previewError = errorString || "Camera preview is unavailable"
    }
    onActiveChanged: {
      if (active) root.previewError = ""
      if (root.controller) root.controller.setCameraPreviewActive(active)
    }
  }

  CaptureSession {
    camera: previewCamera
    videoOutput: videoPreview
  }

  Text {
    visible: root.cameras.length === 0
    width: parent.width
    text: "No cameras are currently available. Connect a camera and it will appear here automatically."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Text {
    visible: root.cameras.length > 0
    width: parent.width
    text: root.cameraExternalUse
      ? "Camera is being used by another application"
      : root.cameras.length + " camera" + (root.cameras.length === 1 ? "" : "s") + " available"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
