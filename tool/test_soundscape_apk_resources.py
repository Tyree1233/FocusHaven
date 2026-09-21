"""Resource keep-rule and finished-APK guard regressions; no Android device."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

from check_soundscape_apk_resources import (
    PNG_SIGNATURE, REQUIRED_ICONS, check_apk, verify_resources,
)

ROOT = Path(__file__).resolve().parents[1]


class MediaResourceChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.apk = Path(temporary.name) / 'fixture.apk'
        self.dump = '\n'.join(
            f'    resource 0x7f0800{i:02x} drawable/{icon}\n'
            f'      (mdpi) (file) res/drawable-mdpi-v4/{icon}.png type=PNG'
            for i, icon in enumerate(REQUIRED_ICONS, 1)
        )
        self.write_apk()

    def write_apk(self, missing=None, invalid=None):
        with zipfile.ZipFile(self.apk, 'w') as archive:
            for icon in REQUIRED_ICONS:
                if icon != missing:
                    archive.writestr(
                        f'res/drawable-mdpi-v4/{icon}.png',
                        b'invalid' if icon == invalid else PNG_SIGNATURE + b'fixture',
                    )

    def test_exact_three_resource_keep_rules(self):
        root = ET.parse(ROOT / 'android/app/src/main/res/raw/com_focushaven_app_soundscape_keep.xml').getroot()
        self.assertEqual(root.tag, 'resources')
        self.assertEqual(len(root), 0)
        self.assertEqual(set(root.attrib), {'{http://schemas.android.com/tools}keep'})
        rules = root.get('{http://schemas.android.com/tools}keep').split(',')
        self.assertEqual(sorted(rules), sorted('@drawable/' + icon for icon in REQUIRED_ICONS))

    def test_raw_resource_filenames_are_android_compatible(self):
        for path in (ROOT / 'android/app/src/main/res/raw').iterdir():
            with self.subTest(path=path.name):
                self.assertRegex(path.stem, r'^[a-z][a-z0-9_]*$')

    def test_controls_still_match_preserved_icons(self):
        source = (ROOT / 'lib/services/soundscape_audio.dart').read_text()
        self.assertEqual(set(re.findall(r'MediaControl\.(\w+)', source)), {'play', 'pause', 'stop'})

    def test_complete_resources_pass(self):
        self.assertEqual(verify_resources(self.dump, self.apk), REQUIRED_ICONS)

    def test_each_missing_or_renamed_icon_fails(self):
        for icon in REQUIRED_ICONS:
            with self.subTest(icon=icon), self.assertRaisesRegex(ValueError, icon):
                verify_resources(self.dump.replace('drawable/' + icon, 'drawable/other_' + icon), self.apk)

    def test_wrong_resource_type_fails(self):
        with self.assertRaises(ValueError):
            verify_resources(self.dump.replace(' drawable/', ' mipmap/'), self.apk)

    def test_name_without_configuration_fails(self):
        dump = '\n'.join(line for line in self.dump.splitlines() if '(file)' not in line)
        with self.assertRaises(ValueError):
            verify_resources(dump, self.apk)

    def test_zero_resource_id_fails(self):
        with self.assertRaises(ValueError):
            verify_resources(self.dump.replace('0x7f080001', '0x00000000'), self.apk)

    def test_missing_or_invalid_payload_fails(self):
        for icon in REQUIRED_ICONS:
            for failure in ('missing', 'invalid'):
                with self.subTest(icon=icon, failure=failure):
                    self.write_apk(**{failure: icon})
                    with self.assertRaisesRegex(ValueError, icon):
                        verify_resources(self.dump, self.apk)

    def test_empty_output_fails(self):
        with self.assertRaises(ValueError):
            verify_resources('', self.apk)

    def test_tool_failure_not_accepted(self):
        with patch('check_soundscape_apk_resources.subprocess.run',
                   side_effect=subprocess.CalledProcessError(1, ['aapt2'])):
            with self.assertRaises(subprocess.CalledProcessError):
                check_apk(self.apk, Path('/unused/aapt2'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
