#!/usr/bin/env python3
"""
Build FitTracker (with the embedded watch app) and install it on the
connected iPhone. The watch app propagates to the paired Apple Watch
automatically as a companion app once it lands on the phone.

Run this with the "Run"/play button in VS Code (or `python3 build_and_run.py`).
No prompts, no arguments: it always does the same thing.
"""

import subprocess
import sys
from pathlib import Path

IOS_DIR = Path(__file__).resolve().parent
XCODEPROJ = IOS_DIR / "FitTracker.xcodeproj"
# Deliberately OUTSIDE ~/Desktop: this Mac has iCloud Drive "Desktop & Documents"
# sync on, and cloudd tags freshly-written build folders with FinderInfo/resource
# fork attributes while Xcode is signing them, which makes codesign fail with
# "resource fork, Finder information, or similar detritus not allowed".
DERIVED_DATA = Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData" / "FitTracker-manual"

SCHEME = "FitTrackerWatchHost"  # the ONLY scheme that embeds the watch app
CONFIGURATION = "Debug"
TEAM = "Y63UKFMUPH"
BUNDLE_ID = "com.marco.manzotti.fittracker"
IPHONE_UDID = "00008110-000425CC1A85401E"


def run(cmd, **kwargs):
    print(f"\n\033[1m$ {' '.join(cmd)}\033[0m")
    return subprocess.run(cmd, check=True, **kwargs)


def fail(message):
    print(f"\n\033[1;31m✗ {message}\033[0m")
    sys.exit(1)


def main():
    if not XCODEPROJ.exists():
        fail(f"Project not found at {XCODEPROJ}")

    try:
        subprocess.run(["xcodebuild", "-version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        fail(
            "xcodebuild can't find a full Xcode install.\n"
            "  Run once: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        )

    if DERIVED_DATA.exists():
        # Finder/iCloud sometimes tag build products with resource-fork/FinderInfo
        # extended attributes, which makes codesign refuse the .app bundle
        # ("resource fork, Finder information, or similar detritus not allowed").
        subprocess.run(["xattr", "-cr", str(DERIVED_DATA)], check=False)

    print("▶ Building FitTrackerWatchHost (iPhone app + embedded watch app)…")
    try:
        run(
            [
                "xcodebuild",
                "-project", str(XCODEPROJ),
                "-scheme", SCHEME,
                "-configuration", CONFIGURATION,
                "-destination", f"id={IPHONE_UDID}",
                "-derivedDataPath", str(DERIVED_DATA),
                "-allowProvisioningUpdates",
                f"DEVELOPMENT_TEAM={TEAM}",
                "build",
            ]
        )
    except subprocess.CalledProcessError:
        fail("Build failed. Scroll up for the xcodebuild error.")

    app_path = DERIVED_DATA / "Build" / "Products" / f"{CONFIGURATION}-iphoneos" / "FitTracker.app"
    if not app_path.exists():
        fail(f"Build succeeded but {app_path} was not found.")

    print("\n▶ Installing on iPhone…")
    try:
        run(
            [
                "xcrun", "devicectl", "device", "install", "app",
                "--device", IPHONE_UDID,
                str(app_path),
            ]
        )
    except subprocess.CalledProcessError:
        fail(
            "Install failed. Make sure the iPhone is connected/unlocked and trusts this Mac."
        )

    print("\n▶ Launching on iPhone…")
    try:
        run(
            [
                "xcrun", "devicectl", "device", "process", "launch",
                "--device", IPHONE_UDID,
                BUNDLE_ID,
            ]
        )
    except subprocess.CalledProcessError:
        # Not fatal: the install succeeded, launching is just a convenience.
        print("\033[1;33m⚠ Could not auto-launch, but the app is installed. Open it by hand.\033[0m")

    print(
        "\n\033[1;32m✓ Done.\033[0m FitTracker is installed on the iPhone; "
        "the watch app will sync over automatically via the companion pairing."
    )


if __name__ == "__main__":
    main()
