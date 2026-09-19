#!/bin/bash
# Source/native verification. No signing request, device use, commit or push.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mode=${1:-source}
if [ "$#" -gt 1 ] || { [ "$mode" != source ] && [ "$mode" != --android-only ] && [ "$mode" != --android-online ] && [ "$mode" != --ios-only ]; }; then
  printf 'Usage: bash tool/verify_soundscapes.sh [--android-only | --android-online | --ios-only]\n' >&2
  exit 2
fi
evidence=$(mktemp -d "../phase218-verification-XXXXXX")
evidence=$(cd "$evidence" && pwd)
trap 'result=$?; if [ "$result" -ne 0 ]; then printf "Verification stopped (exit %s). Logs: %s\n" "$result" "$evidence"; fi' EXIT
run() {
  local label=$1
  shift
  printf 'Running %s\n' "$label"
  "$@" 2>&1 | tee "$evidence/$label.log"
}
if [ "$mode" = --ios-only ]; then
  printf 'Unsigned iOS device-target compilation in a temporary copy. No connected device, simulator launch, installation, account sign-in or upload.\nLogs: %s\n' "$evidence"
  original_source=$PWD
  ios_source=$(mktemp -d /private/tmp/focushaven-phase218-ios-XXXXXX)
  printf '%s\n' "$ios_source" | tee "$evidence/temporary-source-path.txt"
  run ios-source-export python3 - "$ios_source" "$evidence/source-manifest.json" <<'PY'
import hashlib, json, subprocess, sys
from pathlib import Path
destination, manifest = map(Path, sys.argv[1:])
paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard']).split(b'\0')
files = {}
for raw in sorted(set(paths)):
    if not raw:
        continue
    path = Path(raw.decode())
    if path.is_symlink():
        raise SystemExit(f'STOP: source symlink requires review: {path}')
    if not path.is_file():
        continue
    content = path.read_bytes()
    target = destination / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)  # Copy bytes without File Provider metadata.
    target.chmod(path.stat().st_mode & 0o777)
    files[str(path)] = hashlib.sha256(content).hexdigest()
with manifest.open('x') as output:
    json.dump(files, output, indent=2, sort_keys=True)
print(f'Exported {len(files)} source files; ignored build files and signing secrets not copied.')
PY
  run xcode-version xcodebuild -version
  (
    cd "$ios_source"
    export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
    run ios-offline-dart-dependencies flutter pub get --offline --enforce-lockfile
    run ios-generated-localizations flutter gen-l10n
    # Swift package resolution may fetch missing dependencies from the configured
    # repositories. This is a build, not xcodebuild test/run/archive/export.
    run ios-unsigned-build flutter build ios --debug --no-codesign --no-pub --dart-define=ENABLE_SOUNDSCAPES_PREVIEW=true
  )
  test -d "$ios_source/build/ios/iphoneos/Runner.app"
  run ios-source-postflight python3 - "$original_source" "$ios_source" "$evidence" <<'PY'
import hashlib, json, sys
from pathlib import Path
original, copied, evidence = map(Path, sys.argv[1:])
manifest = json.loads((evidence / 'source-manifest.json').read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
changed_original = [name for name, sha in manifest.items() if digest(original / name) != sha]
changed_copy = [name for name, sha in manifest.items() if digest(copied / name) != sha]
(evidence / 'build-copy-changes.json').write_text(json.dumps(changed_copy, indent=2))
if changed_original:
    raise SystemExit(f'STOP: original source changed during verification: {changed_original}')
if digest(copied / 'pubspec.lock') != manifest['pubspec.lock']:
    raise SystemExit('STOP: Dart dependency lock changed')
changed_locks = [name for name in changed_copy if name.endswith('Package.resolved')]
if changed_locks:
    raise SystemExit(f'STOP: Swift package lock changed; review before accepting build: {changed_locks}')
print('PASS: original source and dependency locks unchanged.')
print('Build-copy generated/migrated tracked-file changes:', changed_copy)
PY
  run whitespace git diff --check
  printf 'Unsigned iOS debug build passed; playback, VoiceOver and signed release/device validation remain unverified.\nTemporary build retained: %s\nLogs: %s\n' "$ios_source" "$evidence"
  exit 0
fi
if [ "$mode" = --android-only ] || [ "$mode" = --android-online ]; then
  printf 'Android compilation/resources/unit tests only. No APK, signing or device. Logs: %s\n' "$evidence"
  if [ "$mode" = --android-online ]; then
    printf 'Authorized online resolution: existing Android dependencies may download from configured repositories. No version edits, refresh-dependencies or SDK auto-download.\n'
  else
    printf 'Offline resolution only. Missing cached dependencies will stop verification.\n'
  fi
  # Gradle evaluates signing configuration even for compilation. Refuse the
  # presence of that private file without opening it (including dangling links).
  if [ -e android/key.properties ] || [ -L android/key.properties ]; then
    printf 'STOP: this native check requires a checkout without android/key.properties.\n' >&2
    exit 1
  fi
  if [ ! -f .dart_tool/package_config.json ]; then
    printf 'STOP: run the source verification first to resolve dependencies.\n' >&2
    exit 1
  fi
  flutter_sdk=$(sed -n 's/^flutter.sdk=//p' android/local.properties)
  wrapper_source="$flutter_sdk/bin/cache/artifacts/gradle_wrapper"
  for relative in gradlew gradle/wrapper/gradle-wrapper.jar; do
    if [ ! -f "$wrapper_source/$relative" ]; then
      printf 'STOP: installed Flutter wrapper file missing: %s\n' "$relative" >&2
      exit 1
    fi
    if [ -L "android/$relative" ]; then
      printf 'STOP: unexpected wrapper symlink: %s\n' "$relative" >&2
      exit 1
    elif [ -e "android/$relative" ]; then
      cmp "android/$relative" "$wrapper_source/$relative"
    else
      cp "$wrapper_source/$relative" "android/$relative"
    fi
  done
  java_home='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
  test -x "$java_home/bin/java"
  gradle=(env "JAVA_HOME=$java_home" /bin/bash ./gradlew --no-daemon --console=plain
    -Pandroid.builder.sdkDownload=false
    -Ptarget-platform=android-arm64
    "-Pdart-defines=$(printf ENABLE_SOUNDSCAPES_PREVIEW=true | base64 | tr -d '\n')"
    :app:compileDebugKotlin :app:processDebugResources :app:testDebugUnitTest)
  if [ "$mode" = --android-only ]; then
    gradle+=(--offline)
  fi
  (
    cd android
    run android-task-plan "${gradle[@]}" --dry-run
  )
  run android-plan-check python3 tool/check_soundscape_native_plan.py "$evidence/android-task-plan.log"
  (
    cd android
    run android-compilation-and-unit-tests "${gradle[@]}"
  )
  run whitespace git diff --check
  printf 'Android debug compilation/resources/unit tests passed. No APK was requested; release builds and device playback remain unverified.\nLogs: %s\n' "$evidence"
  exit 0
fi
printf 'Source-only soundscape verification. Logs: %s\n' "$evidence"
run asset-and-boundaries python3 tool/check_soundscape_asset.py
run offline-dependencies flutter pub get --offline
run generated-localizations flutter gen-l10n
selected=(
  lib/config/feature_flags.dart lib/main.dart lib/providers/app_providers.dart
  lib/screens/timer_screen.dart lib/services/voice_transcription_service.dart
  lib/services/soundscape_controller.dart lib/services/soundscape_audio.dart
  lib/services/soundscape_media.dart test/soundscape_media_test.dart
  lib/widgets/soundscape_card.dart test/soundscape_controller_test.dart
  test/soundscape_card_test.dart test/support/fake_soundscape_output.dart
  test/voice_transcription_service_test.dart
  test/android_ongoing_notification_contract_test.dart
)
run format-selected dart format "${selected[@]}"
run format-check dart format --output=none --set-exit-if-changed "${selected[@]}"
run sound-and-voice-tests flutter test --no-pub test/soundscape_controller_test.dart test/soundscape_card_test.dart test/soundscape_media_test.dart test/voice_transcription_service_test.dart test/android_ongoing_notification_contract_test.dart
run application-analysis flutter analyze --no-pub
run complete-suite flutter test --no-pub
run whitespace git diff --check
printf 'Source verification passed. Native builds, playback/listening, lock-screen, interruptions, accessibility and localization review remain pending.\nLogs: %s\n' "$evidence"
