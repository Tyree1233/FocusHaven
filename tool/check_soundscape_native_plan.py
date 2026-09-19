"""Reject artifact/signing/device tasks in the native compilation dry run.

Library AAR/class-JAR and resource intermediates are compilation inputs, not
installable app artifacts. Do not reject those merely for containing 'bundle'.
"""

import re
import sys
from pathlib import Path


def check_plan(text, *, preview=False):
    tasks = re.findall(r"^(:\S+)\s+SKIPPED\s*$", text, re.MULTILINE)
    required = {
        ":app:compileDebugKotlin",
        ":app:processDebugResources",
        ":app:testDebugUnitTest",
    }
    if preview:
        required = {":app:assembleDebug", ":app:packageDebug", ":app:validateSigningDebug"}
    if not required.issubset(tasks) or "BUILD SUCCESSFUL" not in text:
        raise ValueError("Native task plan incomplete or unsuccessful")
    for task in tasks:
        if preview and task in {
            ":app:assembleDebug", ":app:packageDebug", ":app:validateSigningDebug",
            ":app:writeDebugSigningConfigVersions",
            ":app:createDebugApkListingFileRedirect",
        }:
            continue
        name = task.rsplit(":", 1)[-1].lower()
        if (
            task.startswith(":wear:")
            or "release" in name
            or "sign" in name
            or name.startswith(("assemble", "install", "uninstall", "connected"))
            or (task.startswith(":app:") and name.startswith("bundle")
                and "class" not in name)
            or (task.startswith(":app:") and name in {
                "packagedebug", "packageprofile", "packagedebugandroidtest",
                "createdebugapklistingfileredirect",
            })
        ):
            raise ValueError(f"Artifact/signing/device/other-product task refused: {task}")
    return len(tasks)


if __name__ == "__main__":
    try:
        preview = len(sys.argv) == 3 and sys.argv[2] == "--debug-preview"
        if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and not preview):
            raise ValueError("Usage: check_soundscape_native_plan.py PLAN [--debug-preview]")
        count = check_plan(Path(sys.argv[1]).read_text(), preview=preview)
    except (OSError, ValueError, IndexError) as error:
        sys.exit(f"STOP: {error}")
    boundary = "one phone debug APK; no release, bundle, Wear or device task" if preview else "native compilation only, no app packaging/signing/device task"
    print(f"PASS: {count} planned tasks; {boundary}.")
