"""Read-only asset, platform declaration and authority-boundary checks."""
from array import array
from pathlib import Path
import plistlib
import sys
import unittest
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'

class SoundscapeChecks(unittest.TestCase):
    def test_bundled_pcm(self):
        with wave.open(str(ROOT / 'assets/audio/soft_noise.wav'), 'rb') as source:
            self.assertEqual((source.getnchannels(), source.getsampwidth(), source.getframerate()), (1, 2, 24000))
            self.assertEqual(source.getnframes(), 720000)
            pcm = array('h', source.readframes(source.getnframes()))
        if sys.byteorder != 'little':
            pcm.byteswap()
        self.assertLessEqual(max(abs(value) for value in pcm), 14746)
        self.assertGreater(max(pcm) - min(pcm), 1000)
        self.assertLess(abs(sum(pcm) / len(pcm)), 100)

    def test_platform_background_audio(self):
        manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml')
        services = [item for item in manifest.findall('application/service')
                    if ANDROID + 'foregroundServiceType' in item.attrib]
        self.assertEqual(len(services), 1)
        self.assertEqual(services[0].get(ANDROID + 'name'), 'com.ryanheise.audioservice.AudioService')
        self.assertEqual(services[0].get(ANDROID + 'foregroundServiceType'), 'mediaPlayback')
        with (ROOT / 'ios/Runner/Info.plist').open('rb') as source:
            self.assertEqual(plistlib.load(source)['UIBackgroundModes'], ['audio'])

    def test_sound_has_no_product_owner_or_remote_source(self):
        for filename in ('soundscape_controller.dart', 'soundscape_audio.dart',
                         'soundscape_media.dart'):
            source = (ROOT / 'lib/services' / filename).read_text()
            for forbidden in ('timer_service.dart', 'focus_queue_service.dart',
                              'haven_action_engine.dart', 'firebase_',
                              'setUrl(', 'AudioSource.uri(', 'SharedPreferences'):
                self.assertNotIn(forbidden, source)
        self.assertIn("setAsset('assets/audio/soft_noise.wav')",
                      (ROOT / 'lib/services/soundscape_audio.dart').read_text())

    def test_media_branding_is_bundled_and_local(self):
        metadata = (ROOT / 'lib/services/soundscape_media.dart').read_text()
        self.assertIn("artist: 'FocusHaven'", metadata)
        self.assertIn("artwork.scheme != 'file'", metadata)
        self.assertIn('return file.absolute.uri', metadata)
        self.assertIn('assets/focushaven-lantern-icon.png',
                      (ROOT / 'pubspec.yaml').read_text())
        self.assertTrue((ROOT / 'assets/focushaven-lantern-icon.png').read_bytes()
                        .startswith(b'\x89PNG\r\n\x1a\n'))
        for forbidden in ('HttpClient', 'getSingleFile', 'https://', 'http://'):
            self.assertNotIn(forbidden, metadata)

if __name__ == '__main__':
    unittest.main(verbosity=2)
