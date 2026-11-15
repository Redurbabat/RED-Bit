#!/usr/bin/env python3
"""Gegenproben für die reguläre IPA; synthetische Pakete, kein Gerätenachweis."""
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('regular_ipa', ROOT / 'scripts/verify-regular-ios-ipa.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = 'a' * 40


def binary(platform=2, kind=2):
    command = struct.pack('<6I', 0x32, 24, platform, 18 << 16, 27 << 16, 0)
    return struct.pack('<8I', 0xFEEDFACF, 0x0100000C, 0, kind, 1, len(command), 0, 0) + command


class RegularIPATest(unittest.TestCase):
    def package(self, folder, changes=None, widget=True, framework=True, platform=2, profile=False, widget_build='13'):
        path = Path(folder) / 'regular.ipa'
        app = dict(CFBundleIdentifier='com.babat.bbtbit', CFBundleDisplayName='RED Bit',
                   CFBundleExecutable='RedBit', CFBundleSupportedPlatforms=['iPhoneOS'],
                   CFBundleShortVersionString='1.0.4', CFBundleVersion='13',
                   RedBitRevision=SHA[:12], UIBackgroundModes=['audio'])
        app.update(changes or {})
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('Payload/RedBit.app/Info.plist', plistlib.dumps(app))
            archive.writestr('Payload/RedBit.app/RedBit', binary(platform))
            if widget:
                info = dict(CFBundleIdentifier='com.babat.bbtbit.widget', CFBundleExecutable='RedBitWidget',
                            CFBundleShortVersionString='1.0.4', CFBundleVersion=widget_build)
                archive.writestr('Payload/RedBit.app/PlugIns/RedBitWidget.appex/Info.plist', plistlib.dumps(info))
                archive.writestr('Payload/RedBit.app/PlugIns/RedBitWidget.appex/RedBitWidget', binary())
            for name in ['NativeCoreFFI', 'RedBitShared'] if framework else []:
                root = 'Payload/RedBit.app/Frameworks/' + name + '.framework/'
                archive.writestr(root + 'Info.plist', plistlib.dumps(dict(CFBundleExecutable=name)))
                archive.writestr(root + name, binary(kind=6))
            if profile:
                archive.writestr('Payload/RedBit.app/embedded.mobileprovision', b'fixture')
        return path

    def test_regular_package_and_checksum(self):
        with tempfile.TemporaryDirectory() as folder:
            path = self.package(folder)
            result = module.verify(path, SHA)
            self.assertEqual(result['status'], 'BESTANDEN')
            self.assertEqual(result['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertIn('externe Signierung', result['signing'])

    def test_test_identity_and_distribution_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for changes in [dict(CFBundleIdentifier='com.babat.redbit.freetest'), dict(BBTTestDistribution='SideStore')]:
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    module.verify(self.package(folder, changes=changes), SHA)

    def test_revision_and_audio_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for changes in [dict(RedBitRevision='b' * 12), dict(UIBackgroundModes=[])]:
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    module.verify(self.package(folder, changes=changes), SHA)

    def test_absent_widget_and_frameworks_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for options in [dict(widget=False), dict(framework=False)]:
                with self.subTest(options=options), self.assertRaises((ValueError, KeyError)):
                    module.verify(self.package(folder, **options), SHA)

    def test_widget_version_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                module.verify(self.package(folder, widget_build='12'), SHA)

    def test_universal_device_slices_supported(self):
        payload = binary(kind=6)
        offset = 4096
        universal = struct.pack('>7I', 0xCAFEBABE, 1, 0x0100000C, 0, offset, len(payload), 12)
        universal += bytes(offset - len(universal)) + payload
        seen = []
        module.inspect_device_binary(universal, lambda data, executable: seen.append(data))
        self.assertEqual(seen, [payload])

    def test_truncated_or_foreign_universal_slices_rejected(self):
        for cpu, size in [(0x01000007, 32), (0x0100000C, 99999)]:
            data = struct.pack('>7I', 0xCAFEBABE, 1, cpu, 0, 4096, size, 12)
            data += bytes(4096 - len(data)) + binary()
            with self.subTest(cpu=cpu), self.assertRaises(ValueError):
                module.inspect_device_binary(data, lambda *_: None)

    def test_simulator_and_profile_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for options in [dict(platform=7), dict(profile=True)]:
                with self.subTest(options=options), self.assertRaises(ValueError):
                    module.verify(self.package(folder, **options), SHA)


if __name__ == '__main__':
    unittest.main()
