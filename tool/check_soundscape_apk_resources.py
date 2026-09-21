"""Read-only check of dynamically resolved media icons in a finished APK.

Run after APK packaging and before accepting or installing a candidate:
  python3 -B tool/check_soundscape_apk_resources.py APP.apk --aapt2 /path/to/aapt2
No build, signing, device access, or APK modification is performed.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import zipfile

REQUIRED_ICONS = (
    'audio_service_play_arrow',
    'audio_service_pause',
    'audio_service_stop',
)
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def verify_resources(dump, apk):
    """Require named resource IDs and their actual packaged PNG payloads."""
    resources = {}
    current = None
    for line in dump.splitlines():
        entry = re.fullmatch(r'\s*resource (0x[0-9a-fA-F]+) (\S+).*', line)
        if entry:
            current = entry.group(2)
            resources[current] = (int(entry.group(1), 16), [])
        elif line.lstrip().startswith('Package '):
            current = None
        elif current is not None:
            file_entry = re.fullmatch(r'\s*\([^)]*\) \(file\) (\S+) type=PNG\s*', line)
            if file_entry:
                resources[current][1].append(file_entry.group(1))

    errors = []
    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        for icon in REQUIRED_ICONS:
            resource_id, paths = resources.get('drawable/' + icon, (0, []))
            if not resource_id or not paths:
                errors.append(f'{icon}: missing drawable ID or PNG configurations')
                continue
            for path in paths:
                if path not in names:
                    errors.append(f'{icon}: missing packaged file {path}')
                elif not archive.read(path).startswith(PNG_SIGNATURE):
                    errors.append(f'{icon}: invalid PNG payload {path}')
    if errors:
        raise ValueError('; '.join(errors))
    return REQUIRED_ICONS


def check_apk(apk, aapt2):
    completed = subprocess.run(
        [str(aapt2), 'dump', 'resources', str(apk)],
        check=True, capture_output=True, text=True, timeout=60,
    )
    return verify_resources(completed.stdout, apk)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt2', required=True, type=Path)
    args = parser.parse_args()
    try:
        icons = check_apk(args.apk, args.aapt2)
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        print(f'STOP: packaged media-control resource check failed: {error}', file=sys.stderr)
        return 1
    print('PASS: packaged media-control IDs and PNG files: ' + ', '.join(icons))
    return 0


if __name__ == '__main__':
    sys.exit(main())
