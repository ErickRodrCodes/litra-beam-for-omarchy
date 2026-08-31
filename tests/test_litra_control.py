import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock


SCRIPT = Path(__file__).parents[1] / "scripts/litra-control.py"
SPEC = importlib.util.spec_from_file_location("litra_control", SCRIPT)
litra_control = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = litra_control
SPEC.loader.exec_module(litra_control)


def fake_light(address, state):
    light = Mock()
    light.address = address
    light.state.return_value = state
    return light


class SyncNewLightsTest(unittest.TestCase):
    def test_new_light_copies_state_from_established_light(self):
        established = fake_light("AA:00", {
            "power": True, "brightness": 60, "temperature": 4200,
            "effective_maximum_percent": 100,
        })
        newcomer = fake_light("BB:00", {
            "effective_maximum_percent": 100,
        })

        litra_control.sync_new_lights([newcomer, established], ["AA-00"])

        newcomer.brightness.assert_called_once_with(60)
        newcomer.temperature.assert_called_once_with(4200)
        newcomer.power.assert_called_once_with(True)
        established.brightness.assert_not_called()

    def test_new_lower_ceiling_caps_the_whole_group(self):
        established = fake_light("AA:00", {
            "power": True, "brightness": 80, "temperature": 4000,
            "effective_maximum_percent": 100,
        })
        newcomer = fake_light("BB:00", {
            "effective_maximum_percent": 65,
        })

        litra_control.sync_new_lights([established, newcomer], ["AA:00"])

        established.brightness.assert_called_once_with(65)
        newcomer.brightness.assert_called_once_with(65)
        newcomer.temperature.assert_called_once_with(4000)
        newcomer.power.assert_called_once_with(True)

    def test_first_powered_light_in_ui_order_is_master(self):
        first = fake_light("BB:00", {
            "power": False, "brightness": 20, "temperature": 3000,
            "effective_maximum_percent": 100,
        })
        second = fake_light("CC:00", {
            "power": True, "brightness": 70, "temperature": 4500,
            "effective_maximum_percent": 100,
        })
        newcomer = fake_light("AA:00", {
            "power": False, "brightness": 10, "temperature": 2700,
            "effective_maximum_percent": 100,
        })

        # Discovery order puts the newly connected A first, while the UI's
        # established order is B then C. B is off, so C must be the master.
        litra_control.sync_new_lights(
            [newcomer, second, first],
            ["BB:00", "CC:00"],
        )

        newcomer.brightness.assert_called_once_with(70)
        newcomer.temperature.assert_called_once_with(4500)
        newcomer.power.assert_called_once_with(True)

    def test_does_nothing_without_an_established_source(self):
        newcomer = fake_light("BB:00", {"effective_maximum_percent": 100})

        litra_control.sync_new_lights([newcomer], [])

        newcomer.state.assert_not_called()
        newcomer.power.assert_not_called()


class InitialSyncTest(unittest.TestCase):
    def test_first_powered_light_is_master(self):
        first = fake_light("AA:00", {
            "power": False, "brightness": 20, "temperature": 3000,
            "effective_maximum_percent": 100,
        })
        second = fake_light("BB:00", {
            "power": True, "brightness": 75, "temperature": 4600,
            "effective_maximum_percent": 100,
        })

        litra_control.sync_from_first([first, second])

        for light in (first, second):
            light.brightness.assert_called_once_with(75)
            light.temperature.assert_called_once_with(4600)
            light.power.assert_called_once_with(True)


class SyncTopologyTest(unittest.TestCase):
    def test_single_light_turns_off_persisted_sync(self):
        settings = {"sync": True, "camera_id": "", "reconnect_interval_ms": 500}
        original = litra_control.save_sync
        saved = []
        litra_control.save_sync = saved.append
        try:
            result = litra_control.disable_sync_for_single_light(settings, 1)
        finally:
            litra_control.save_sync = original

        self.assertEqual(saved, [False])
        self.assertFalse(result["sync"])
        self.assertTrue(settings["sync"], "the caller's settings object is not mutated")

    def test_two_lights_preserve_sync(self):
        settings = {"sync": True, "camera_id": "", "reconnect_interval_ms": 500}
        original = litra_control.save_sync
        saved = []
        litra_control.save_sync = saved.append
        try:
            result = litra_control.disable_sync_for_single_light(settings, 2)
        finally:
            litra_control.save_sync = original

        self.assertEqual(saved, [])
        self.assertTrue(result["sync"])

    def test_second_light_does_not_enable_sync(self):
        settings = {"sync": False, "camera_id": "", "reconnect_interval_ms": 500}
        original = litra_control.save_sync
        saved = []
        litra_control.save_sync = saved.append
        try:
            result = litra_control.disable_sync_for_single_light(settings, 2)
        finally:
            litra_control.save_sync = original

        self.assertEqual(saved, [])
        self.assertFalse(result["sync"])


class CameraActivityTest(unittest.TestCase):
    @staticmethod
    def graph(consumer_pid):
        return [
            {"id": 10, "type": "PipeWire:Interface:Node", "info": {"props": {
                "api.v4l2.path": "/dev/video2",
            }}},
            {"id": 20, "type": "PipeWire:Interface:Node", "info": {"props": {
                "client.id": 30,
            }}},
            {"id": 30, "type": "PipeWire:Interface:Client", "info": {"props": {
                "application.process.id": str(consumer_pid),
            }}},
            {"id": 40, "type": "PipeWire:Interface:Link", "info": {
                "state": "active", "output-node-id": 10, "input-node-id": 20,
            }},
        ]

    def test_external_pipewire_consumer_is_active(self):
        self.assertTrue(litra_control.pipewire_camera_active(
            "/dev/video2", {100}, self.graph(200)))

    def test_own_preview_is_not_external_use(self):
        self.assertFalse(litra_control.pipewire_camera_active(
            "/dev/video2", {100}, self.graph(100)))

    def test_other_camera_does_not_match(self):
        self.assertFalse(litra_control.pipewire_camera_active(
            "/dev/video0", {100}, self.graph(200)))


if __name__ == "__main__":
    unittest.main()
