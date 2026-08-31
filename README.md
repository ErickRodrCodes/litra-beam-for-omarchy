# Litra Beam for Omarchy

An Omarchy shell plugin for controlling one or many Logitech Litra Beam lights over USB or Bluetooth. It follows the same service/view/bar/overlay architecture as the Yamaha MG-XU plugin.

The panel has **Lights**, **Camera**, and **Settings** tabs. Lights contains the direct and synchronized controls. Camera provides a live preview of the selected Qt Multimedia camera and remembers the selection. It detects both its own preview and direct V4L2 or PipeWire use by other applications; when the camera is externally busy, the preview reports that another application is using it. The persisted **Turn lights automatically when camera is being used** toggle powers all connected lights on while the selected camera is in use and powers them off when it is no longer in use.

The **Sync lights** toggle is shown when more than one light is connected and is off by default. If the connected group drops to one light, sync is automatically turned off and the remaining light is treated as an individual device. When sync is off, the panel lists every connected light and opens separate controls for the selected device. When enabled, the first powered-on light is the master: its current power, brightness, and temperature are immediately copied to the remaining lights, and subsequent changes apply to the group.

Brightness uses the HID++ illumination capability data. The slider stops at each light's `effective maximum`, which can be lower than its nominal 400-lumen maximum when the USB supply cannot provide enough power. In sync mode it stops at the lowest effective maximum in the group.

## Supported hardware

This plugin is currently developed and tested with the non-RGB **Logitech Litra Beam LED Streaming Light**, which is the hardware available to the project. RGB Litra models are not currently supported or represented by the existing controls.

RGB-specific features can be added once the project has access to an RGB model and can test its capabilities and behavior on real hardware.

## Install

```bash
git clone https://github.com/ErickRodrCodes/litra-beam-for-omarchy.git \
  ~/.config/omarchy/plugins/io.github.tbogard.litra-lights
omarchy plugin enable io.github.tbogard.litra-lights right
~/.config/omarchy/plugins/io.github.tbogard.litra-lights/scripts/install-app.sh
```

USB lights are detected automatically after they are connected. For Bluetooth, hold the light's Bluetooth button for approximately three seconds and pair it in Omarchy Bluetooth settings.

While the panel or app is open, it continuously checks for paired Bluetooth Litra devices and asks BlueZ to connect any that are not already connected. Newly connected lights appear without closing or reopening the UI; discovery stops when the UI closes. When synchronization is enabled, a newly connected light copies power, brightness, and temperature from the first powered-on established light in the UI list. The default retry interval is 500 ms and can be changed from the Settings tab.

## Validate

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml BarWidget.qml Panel.qml App.qml LitraView.qml LightControls.qml CameraAutomation.qml LitraSettings.qml PowerLimitedSlider.qml
python3 -m py_compile scripts/litra-control.py
```
