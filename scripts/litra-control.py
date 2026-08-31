#!/usr/bin/env python3
"""Backend for the Litra Beam for Omarchy plugin."""

from __future__ import annotations

import argparse
import glob
import json
import os
import select
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

PRODUCTS = {0xB901: ("Litra Beam", 0x04), 0xC901: ("Litra Beam", 0x04)}
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "litra-lights/settings.json"
DEFAULT_RECONNECT_INTERVAL_MS = 500


class LitraError(RuntimeError):
    pass


def _field(text: str, key: str) -> str:
    prefix = key + "="
    return next((line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)), "")


@dataclass(frozen=True)
class Light:
    path: str
    address: str
    name: str
    feature: int
    transport: str

    def _report(self, function: int, *args: int) -> bytes:
        value = bytes((0x11, 0xFF, self.feature, function, *args))
        return value + bytes(20 - len(value))

    def write(self, function: int, *args: int) -> None:
        try:
            fd = os.open(self.path, os.O_WRONLY)
            try:
                os.write(fd, self._report(function, *args))
            finally:
                os.close(fd)
        except PermissionError as exc:
            raise LitraError(f"Permission denied for {self.path}") from exc
        except OSError as exc:
            raise LitraError(f"Could not control {self.name}: {exc}") from exc

    def query(self, function: int) -> bytes | None:
        try:
            fd = os.open(self.path, os.O_RDWR | os.O_NONBLOCK)
            try:
                # HID++ notifications and earlier replies share this queue.
                # Drain anything that predates this request, then accept only
                # a reply echoing both our illumination feature and function.
                while True:
                    try:
                        os.read(fd, 64)
                    except BlockingIOError:
                        break
                os.write(fd, self._report(function))
                deadline = time.monotonic() + 0.75
                while time.monotonic() < deadline:
                    ready, _, _ = select.select([fd], [], [], deadline - time.monotonic())
                    if not ready:
                        return None
                    reply = os.read(fd, 64)
                    if (len(reply) >= 5 and reply[0] == 0x11
                            and reply[2] == self.feature and reply[3] == function):
                        return reply
                return None
            finally:
                os.close(fd)
        except OSError:
            return None

    def state(self) -> dict:
        power = self.query(0x01)
        brightness_info = self.query(0x21)
        brightness = self.query(0x31)
        temperature = self.query(0x81)
        lumens = int.from_bytes(brightness[4:6], "big") if brightness and len(brightness) >= 6 else None
        minimum = int.from_bytes(brightness_info[5:7], "big") if brightness_info and len(brightness_info) >= 9 else 20
        maximum = int.from_bytes(brightness_info[7:9], "big") if brightness_info and len(brightness_info) >= 9 else 400
        # Feature v1 exposes effective maximum (power-dependent). Beam
        # firmware currently reports v0 and returns zero, so fall back to the
        # declared maximum instead of mistaking unrelated traffic for a cap.
        effective_reply = self.query(0xC1)
        effective_max = int.from_bytes(effective_reply[4:6], "big") if effective_reply and len(effective_reply) >= 6 else maximum
        if minimum <= 0 or maximum <= minimum:
            minimum, maximum = 20, 400
        if effective_max < minimum or effective_max > maximum:
            effective_max = maximum
        percent = round((lumens - minimum) * 100 / (maximum - minimum)) if lumens is not None else None
        effective_percent = round((effective_max - minimum) * 100 / (maximum - minimum))
        compact_address = self.address.upper().replace("-", ":")
        suffix = compact_address[-5:] if compact_address else ""
        return {
            "address": self.address,
            "name": self.name,
            "display_name": f"{self.name} · {suffix}" if suffix else self.name,
            "transport": self.transport,
            "power": bool(power[4]) if power else None,
            "brightness": max(0, min(100, percent)) if percent is not None else None,
            "brightness_lumens": lumens,
            "minimum_lumens": minimum,
            "maximum_lumens": maximum,
            "effective_maximum_lumens": effective_max,
            "effective_maximum_percent": max(1, min(100, effective_percent)),
            "temperature": int.from_bytes(temperature[4:6], "big") if temperature and len(temperature) >= 6 else None,
        }

    def power(self, enabled: bool) -> None:
        self.write(0x1C, 1 if enabled else 0)

    def brightness(self, percent: int) -> None:
        percent = max(0, min(100, percent))
        # Do not query capability immediately before this write. Some Beam v0
        # firmware (observed on B901) ignores a brightness write that directly
        # follows getBrightnessEffectiveMax, although both operations work in
        # isolation. The UI already constrains percentage to the effective
        # ceiling returned by status().
        minimum, maximum = 30, 400
        lumens = round(minimum + (maximum - minimum) * percent / 100)
        self.write(0x4C, lumens >> 8, lumens & 0xFF)

    def temperature(self, kelvin: int) -> None:
        kelvin = max(2700, min(6500, kelvin))
        self.write(0x9C, kelvin >> 8, kelvin & 0xFF)


def discover() -> list[Light]:
    result = []
    for path in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            uevent = Path(path, "device/uevent").read_text()
        except OSError:
            continue
        hid_id = _field(uevent, "HID_ID").upper()
        if "0000046D" not in hid_id and ":046D:" not in hid_id:
            continue
        product = next((pid for pid in PRODUCTS if f"{pid:04X}" in hid_id), None)
        if product is None:
            continue
        model, feature = PRODUCTS[product]
        bus = hid_id.split(":", 1)[0][-4:]
        transport = "bluetooth" if bus == "0005" else "usb" if bus == "0003" else "hid"
        result.append(Light("/dev/" + Path(path).name, _field(uevent, "HID_UNIQ"), _field(uevent, "HID_NAME") or model, feature, transport))
    return result


def load_settings() -> dict:
    try:
        data = json.loads(STATE.read_text())
        return {
            "sync": bool(data.get("sync", False)),
            "camera_id": str(data.get("camera_id", "")),
            "camera_automation": bool(data.get("camera_automation", False)),
            "reconnect_interval_ms": max(500, min(30000, int(data.get("reconnect_interval_ms", DEFAULT_RECONNECT_INTERVAL_MS)))),
        }
    except (OSError, TypeError, ValueError):
        return {"sync": False, "camera_id": "", "camera_automation": False,
                "reconnect_interval_ms": DEFAULT_RECONNECT_INTERVAL_MS}


def save_settings(settings: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(settings) + "\n")
    temporary.replace(STATE)


def save_sync(enabled: bool) -> None:
    settings = load_settings()
    settings["sync"] = enabled
    save_settings(settings)


def save_camera(camera_id: str) -> None:
    settings = load_settings()
    settings["camera_id"] = camera_id
    save_settings(settings)


def save_camera_automation(enabled: bool) -> None:
    settings = load_settings()
    settings["camera_automation"] = enabled
    save_settings(settings)


def save_reconnect_interval(milliseconds: int) -> None:
    settings = load_settings()
    settings["reconnect_interval_ms"] = max(500, min(30000, milliseconds))
    save_settings(settings)


def disable_sync_for_single_light(settings: dict, light_count: int) -> dict:
    """Persist direct-control mode when no synchronized group remains."""
    if settings["sync"] and light_count <= 1:
        save_sync(False)
        settings = dict(settings)
        settings["sync"] = False
    return settings


def bluetooth_devices(state: str) -> list[tuple[str, str]]:
    """Return address/name pairs from a BlueZ device-state listing."""
    try:
        result = subprocess.run(
            ["bluetoothctl", "devices", state],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []

    devices = []
    for line in result.stdout.splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) == 3 and parts[0] == "Device":
            devices.append((parts[1], parts[2]))
    return devices


def paired_litra_addresses() -> list[str]:
    """Return Bluetooth addresses for paired Litra lights."""
    return [address for address, name in bluetooth_devices("Paired")
            if "litra" in name.lower()]


def process_family(pid: int) -> set[int]:
    """Return a process and its ancestors so our preview can be ignored."""
    result = set()
    while pid > 1 and pid not in result:
        result.add(pid)
        try:
            stat = Path(f"/proc/{pid}/stat").read_text()
            pid = int(stat.rsplit(")", 1)[1].split()[1])
        except (OSError, IndexError, ValueError):
            break
    return result


def pipewire_camera_active(camera_id: str, own_processes: set[int], objects: list[dict]) -> bool:
    nodes = {item.get("id"): item for item in objects
             if item.get("type") == "PipeWire:Interface:Node"}
    clients = {item.get("id"): item for item in objects
               if item.get("type") == "PipeWire:Interface:Client"}
    camera_nodes = set()
    for node_id, node in nodes.items():
        props = node.get("info", {}).get("props", {})
        if props.get("api.v4l2.path") == camera_id or props.get("object.path") == f"v4l2:{camera_id}":
            camera_nodes.add(node_id)

    for item in objects:
        if item.get("type") != "PipeWire:Interface:Link":
            continue
        info = item.get("info", {})
        if info.get("state") != "active" or info.get("output-node-id") not in camera_nodes:
            continue
        consumer = nodes.get(info.get("input-node-id"), {})
        consumer_props = consumer.get("info", {}).get("props", {})
        client = clients.get(consumer_props.get("client.id"), {})
        client_props = client.get("info", {}).get("props", {})
        try:
            consumer_pid = int(client_props.get("application.process.id", -1))
        except (TypeError, ValueError):
            consumer_pid = -1
        if consumer_pid not in own_processes:
            return True
    return False


def direct_camera_active(camera_id: str, own_processes: set[int]) -> bool:
    if not camera_id.startswith("/dev/video"):
        return False
    try:
        result = subprocess.run(["fuser", camera_id], capture_output=True, text=True,
                                timeout=2, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return False
    pids = set()
    for value in (result.stdout + " " + result.stderr).split():
        try:
            pids.add(int(value.rstrip("mcefrF")))
        except ValueError:
            continue
    return bool(pids - own_processes)


def camera_active(camera_id: str) -> bool:
    own_processes = process_family(os.getppid())
    pipewire_active = False
    try:
        result = subprocess.run(["pw-dump"], capture_output=True, text=True,
                                timeout=3, check=False)
        if result.returncode == 0:
            pipewire_active = pipewire_camera_active(
                camera_id, own_processes, json.loads(result.stdout))
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass
    return pipewire_active or direct_camera_active(camera_id, own_processes)


def normalized_address(address: str) -> str:
    return address.replace(":", "").replace("-", "").casefold()


def sync_new_lights(lights: list[Light], previous_addresses: list[str]) -> None:
    """Bring newly connected lights into an existing synchronized group."""
    previous = {normalized_address(address) for address in previous_addresses}
    by_address = {normalized_address(light.address): light for light in lights}
    # Preserve the UI's listing order when choosing a master. HID node order
    # can change during reconnect and may otherwise put the newcomer first.
    established = [by_address[address] for address in map(normalized_address, previous_addresses)
                   if address in by_address]
    newcomers = [light for light in lights if normalized_address(light.address) not in previous]
    if not established or not newcomers:
        return

    established_states = [(light, light.state()) for light in established]
    _, source = next(
        ((light, state) for light, state in established_states if state["power"] is True),
        established_states[0],
    )
    newcomer_states = [light.state() for light in newcomers]
    if source["power"] is None or source["brightness"] is None or source["temperature"] is None:
        raise LitraError("Could not read an existing light to synchronize the reconnected light")

    ceilings = [source["effective_maximum_percent"]]
    ceilings.extend(state["effective_maximum_percent"] for state in newcomer_states)
    ceilings = [ceiling for ceiling in ceilings if ceiling is not None]
    synchronized_brightness = min(source["brightness"], min(ceilings, default=100))

    # A newcomer with a lower effective maximum changes the group's common
    # ceiling, so lower the established lights as well when necessary.
    if synchronized_brightness < source["brightness"]:
        for light in established:
            light.brightness(synchronized_brightness)
    for light in newcomers:
        light.brightness(synchronized_brightness)
        light.temperature(source["temperature"])
        light.power(source["power"])


def reconnect(previous_addresses: list[str]) -> int:
    """Ask BlueZ to reconnect paired lights and reconcile sync newcomers."""
    connected = {address.casefold() for address, _ in bluetooth_devices("Connected")}
    for address in paired_litra_addresses():
        if address.casefold() in connected:
            continue
        try:
            subprocess.run(
                ["bluetoothctl", "--timeout", "5", "connect", address],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=7,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
    lights = discover()
    settings = disable_sync_for_single_light(load_settings(), len(lights))
    if settings["sync"]:
        sync_new_lights(lights, previous_addresses)
    print(json.dumps({"device_ids": [light.address for light in lights]}))
    return 0


def find_light(lights: list[Light], address: str) -> Light:
    wanted = address.replace(":", "").replace("-", "").lower()
    for light in lights:
        actual = light.address.replace(":", "").replace("-", "").lower()
        if actual == wanted:
            return light
    raise LitraError("The selected light is no longer connected")


def sync_from_first(lights: list[Light]) -> None:
    if not lights:
        return
    states = [light.state() for light in lights]
    source = next((state for state in states if state["power"] is True), states[0])
    if source["power"] is None or source["brightness"] is None or source["temperature"] is None:
        raise LitraError("Could not read the first light; synchronization was not enabled")
    ceilings = [state["effective_maximum_percent"] for state in states
                if state["effective_maximum_percent"] is not None]
    group_ceiling = min(ceilings) if ceilings else 100
    synchronized_brightness = min(source["brightness"], group_ceiling)
    # Include the master: if it was brighter than the weakest light can reach,
    # enabling sync must bring it down to the group ceiling before the group is
    # considered synchronized.
    for light in lights:
        light.brightness(synchronized_brightness)
        light.temperature(source["temperature"])
        light.power(source["power"])


def target_lights(lights: list[Light], address: str, sync: bool) -> list[Light]:
    if not lights:
        raise LitraError("No connected Litra Beam lights were found")
    return lights if sync else [find_light(lights, address)]


def status() -> int:
    settings = load_settings()
    lights = discover()
    settings = disable_sync_for_single_light(settings, len(lights))
    devices = [light.state() for light in lights]
    print(json.dumps({
        "sync": settings["sync"],
        "camera_id": settings["camera_id"],
        "camera_automation": settings["camera_automation"],
        "reconnect_interval_ms": settings["reconnect_interval_ms"],
        "devices": devices,
        "count": len(devices),
    }))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    reconnect_parser = commands.add_parser("reconnect")
    reconnect_parser.add_argument("previous_address", nargs="*")
    sync_parser = commands.add_parser("sync")
    sync_parser.add_argument("value", choices=("on", "off"))
    camera_parser = commands.add_parser("camera")
    camera_parser.add_argument("id")
    camera_automation_parser = commands.add_parser("camera-automation")
    camera_automation_parser.add_argument("value", choices=("on", "off"))
    camera_active_parser = commands.add_parser("camera-active")
    camera_active_parser.add_argument("id")
    camera_power_parser = commands.add_parser("camera-power")
    camera_power_parser.add_argument("value", choices=("on", "off"))
    reconnect_interval_parser = commands.add_parser("reconnect-interval")
    reconnect_interval_parser.add_argument("milliseconds", type=int)
    for name in ("power", "brightness", "temperature"):
        item = commands.add_parser(name)
        item.add_argument("address")
        item.add_argument("value", type=int)
    args = parser.parse_args()
    try:
        if args.command == "status":
            return status()
        if args.command == "reconnect":
            return reconnect(args.previous_address)
        if args.command == "camera-active":
            print(json.dumps({"active": camera_active(args.id)}))
            return 0
        lights = discover()
        if args.command == "sync":
            enabled = args.value == "on"
            if enabled:
                if len(lights) < 2:
                    raise LitraError("Connect at least two Litra lights before enabling sync")
                sync_from_first(lights)
            save_sync(enabled)
            return status()
        if args.command == "camera":
            save_camera(args.id)
            return status()
        if args.command == "camera-automation":
            save_camera_automation(args.value == "on")
            return status()
        if args.command == "camera-power":
            enabled = args.value == "on"
            for light in lights:
                # Power writes are idempotent and more reliable than gating
                # on a read from a freshly reconnected light.
                light.power(enabled)
            return status()
        if args.command == "reconnect-interval":
            save_reconnect_interval(args.milliseconds)
            return status()
        synced = load_settings()["sync"]
        targets = target_lights(lights, args.address, synced)
        if args.command == "power":
            for light in targets:
                light.power(bool(args.value))
        elif args.command == "brightness":
            for light in targets:
                light.brightness(args.value)
        else:
            for light in targets:
                light.temperature(args.value)
        return status()
    except LitraError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
