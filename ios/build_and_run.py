#!/usr/bin/env python3
"""
Build FitTracker (with the embedded watch app) in Release and install it on the
connected iPhone.

    python3 build_and_run.py           # iPhone only
    python3 build_and_run.py --watch   # also build and install the Apple Watch app

The watch app does NOT reach the watch on its own with the free team: the profile
made for the phone build lists only the iPhone. `--watch` builds the watch scheme
for the watch itself (which registers it and regenerates the profile), installs it
there, then builds the phone app so the embedded copy carries the same profile.

Set FIT_TRACKER_CONFIGURATION=Debug for a debuggable (much slower) build.
Every build carries the commit count as its build number and the short hash,
shown at the bottom of Settings and on the watch.
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
CONFIGURATION = os.environ.get("FIT_TRACKER_CONFIGURATION", "Release")
TEAM = os.environ.get("DEVELOPMENT_TEAM", "Y63UKFMUPH")
BUNDLE_ID = "com.marco.manzotti.fittracker"
WATCH_SCHEME = "FitTrackerWatch"
# devicectl's tunnelState for a device it knows about but cannot reach.
UNREACHABLE_TUNNEL_STATE = "unavailable"


def run(cmd, **kwargs):
    print(f"\n\033[1m$ {' '.join(cmd)}\033[0m")
    return subprocess.run(cmd, check=True, **kwargs)


def fail(message):
    print(f"\n\033[1;31m✗ {message}\033[0m")
    sys.exit(1)


def reachable_udid(device, device_type):
    """UDID of a real device of this type devicectl can talk to right now, else None."""
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    if hardware.get("deviceType") != device_type or hardware.get("reality") != "physical":
        return None
    # A paired device that is unplugged or off the network reports "unavailable".
    # An idle watch reports "disconnected": devicectl wakes it on demand.
    if connection.get("tunnelState") in (None, UNREACHABLE_TUNNEL_STATE):
        return None
    return hardware.get("udid")


def listed_devices():
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
            return json.loads(listing.read_text())["result"]["devices"]
        except (subprocess.CalledProcessError, FileNotFoundError, OSError, KeyError, ValueError):
            fail("Could not list Apple devices. Connect and unlock the iPhone, then retry.")


def connected(device_type, override_env, label):
    """The one reachable device of this type, or the UDID in `override_env`."""
    override = os.environ.get(override_env)
    if override:
        return override
    candidates = [udid for udid in (reachable_udid(d, device_type) for d in listed_devices()) if udid]
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        fail(f"More than one {label} is connected. Set {override_env} to the UDID you want.")
    fail(f"No reachable {label} found. Connect and unlock it (the watch: on the wrist, unlocked, "
         f"near the paired iPhone) and trust this Mac.")


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=IOS_DIR, check=True, capture_output=True, text=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def version_settings():
    """Build number = commit count, plus the short hash ("+" when ios/ has uncommitted
    changes), so Settings tells exactly which code is on the phone."""
    count = git("rev-list", "--count", "HEAD") or "1"
    short = git("rev-parse", "--short", "HEAD") or "dev"
    if git("status", "--porcelain", "--", "."):
        short += "+"
    return [f"CURRENT_PROJECT_VERSION={count}", f"FT_GIT_HASH={short}"]


def xcodebuild(scheme, udid):
    run(
        [
            "xcodebuild",
            "-project", str(XCODEPROJ),
            "-scheme", scheme,
            "-configuration", CONFIGURATION,
            "-destination", f"id={udid}",
            "-derivedDataPath", str(DERIVED_DATA),
            "-allowProvisioningUpdates",
            f"DEVELOPMENT_TEAM={TEAM}",
            *version_settings(),
            "build",
        ]
    )


def install(udid, app_path, label):
    if not app_path.exists():
        fail(f"Build succeeded but {app_path} was not found.")
    print(f"\n▶ Installing on {label}…")
    try:
        run(["xcrun", "devicectl", "device", "install", "app", "--device", udid, str(app_path)])
    except subprocess.CalledProcessError:
        fail(f"Install on {label} failed. Make sure it is connected/unlocked and trusts this Mac.")


def install_watch_app():
    watch_udid = connected("appleWatch", "FIT_TRACKER_WATCH", "Apple Watch")
    print(f"▶ Watch: {watch_udid}")
    try:
        xcodebuild(WATCH_SCHEME, watch_udid)
    except subprocess.CalledProcessError:
        fail("Watch build failed. Scroll up for the xcodebuild error (it can take up to 20 minutes).")
    install(watch_udid, DERIVED_DATA / "Build" / "Products" / f"{CONFIGURATION}-watchos" / "FitTrackerWatch.app",
            "Apple Watch")


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

    iphone_udid = connected("iPhone", "FIT_TRACKER_DEVICE", "iPhone")
    print(f"▶ Device: {iphone_udid} · {CONFIGURATION}")
    if "--watch" in sys.argv[1:]:
        install_watch_app()

    print(f"▶ Building {SCHEME} from the current source…")
    try:
        xcodebuild(SCHEME, iphone_udid)
    except subprocess.CalledProcessError:
        fail("Build failed. Scroll up for the xcodebuild error.")
    install(iphone_udid, DERIVED_DATA / "Build" / "Products" / f"{CONFIGURATION}-iphoneos" / "FitTracker.app", "iPhone")

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

    watch_note = "and on the Apple Watch" if "--watch" in sys.argv[1:] else "(watch untouched: use --watch)"
    print(f"\n\033[1;32m✓ Done.\033[0m FitTracker is installed on the iPhone {watch_note}.")


if __name__ == "__main__":
    main()
