#!/usr/bin/env python3
"""
Build FitTracker (with the embedded watch app) and install it on the
connected iPhone. The watch app propagates to the paired Apple Watch
automatically as a companion app once it lands on the phone.

Run this with the "Run"/play button in VS Code (or `python3 build_and_run.py`).
No prompts, no arguments: it always does the same thing.
"""

import json
import subprocess
import sys
import os
import tempfile
from pathlib import Path

IOS_DIR = Path(__file__).resolve().parent
XCODEPROJ = IOS_DIR / "FitTracker.xcodeproj"
# Deliberately OUTSIDE ~/Desktop: this Mac has iCloud Drive "Desktop & Documents"
# sync on, and cloudd tags freshly-written build folders with FinderInfo/resource
# fork attributes while Xcode is signing them, which makes codesign fail with
# "resource fork, Finder information, or similar detritus not allowed".
DERIVED_DATA = Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData" / "FitTracker-manual"

SCHEME = os.environ.get("FIT_TRACKER_SCHEME", "FitTrackerWatchHost")
CONFIGURATION = os.environ.get("FIT_TRACKER_CONFIGURATION", "Debug")
TEAM = os.environ.get("DEVELOPMENT_TEAM", "Y63UKFMUPH")
BUNDLE_ID = "com.marco.manzotti.fittracker"
# devicectl's tunnelState for a device it knows about but cannot reach.
UNREACHABLE_TUNNEL_STATE = "unavailable"


def run(cmd, **kwargs):
    print(f"\n\033[1m$ {' '.join(cmd)}\033[0m")
    return subprocess.run(cmd, check=True, **kwargs)


def fail(message):
    print(f"\n\033[1;31m✗ {message}\033[0m")
    sys.exit(1)


def reachable_iphone_udid(device):
    """UDID of a real iPhone devicectl can talk to right now, else None."""
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    if hardware.get("deviceType") != "iPhone" or hardware.get("reality") != "physical":
        return None
    # A paired phone that is unplugged or off the network reports "unavailable".
    if connection.get("tunnelState") in (None, UNREACHABLE_TUNNEL_STATE):
        return None
    return hardware.get("udid")


def connected_iphone():
    """Return the connected iPhone UDID, or an explicit FIT_TRACKER_DEVICE."""
    override = os.environ.get("FIT_TRACKER_DEVICE")
    if override:
        return override

    # The JSON listing, not the human table: the table's State column reads
    # "unavailable" for a phone that is paired but not plugged in, and a substring
    # test for "available" picks exactly that one.
    with tempfile.TemporaryDirectory() as tmp:
        listing = Path(tmp) / "devices.json"
        try:
            subprocess.run(
                ["xcrun", "devicectl", "list", "devices", "--json-output", str(listing)],
                check=True, capture_output=True, text=True,
            )
            devices = json.loads(listing.read_text())["result"]["devices"]
        except (subprocess.CalledProcessError, FileNotFoundError, OSError, KeyError, ValueError):
            fail("Could not list Apple devices. Connect and unlock the iPhone, then retry.")

    candidates = [
        udid for udid in (reachable_iphone_udid(device) for device in devices) if udid
    ]

    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        fail("More than one iPhone is connected. Set FIT_TRACKER_DEVICE to the UDID you want.")
    fail("No connected iPhone found. Connect it by cable, unlock it, and trust this Mac.")


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

    iphone_udid = connected_iphone()
    print(f"▶ Device: {iphone_udid}")
    print(f"▶ Building {SCHEME} from the current source…")
    try:
        run(
            [
                "xcodebuild",
                "-project", str(XCODEPROJ),
                "-scheme", SCHEME,
                "-configuration", CONFIGURATION,
                "-destination", f"id={iphone_udid}",
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
                "--device", iphone_udid,
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
                "--device", iphone_udid,
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
