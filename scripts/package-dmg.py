"""Build MacPad's branded DMG without Finder automation or signing claims.

Create build/dmg-env with venv, install scripts/dmg-requirements.txt there, then
run its Python interpreter with this script, an app bundle, and an output DMG.
The caller must sign the app first and notarize/staple the finished DMG before
publishing. Neither an existing DMG nor its checksum is overwritten.
"""

import argparse
import hashlib
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path

import dmgbuild


def validate_app(app: Path) -> None:
    if not app.is_dir():
        raise FileNotFoundError(f"MacPad.app bundle does not exist: {app}")
    if app.name != "MacPad.app":
        raise ValueError(f"Expected a MacPad.app bundle, received: {app}")
    with (app / "Contents" / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if not isinstance(info, dict) or info.get("CFBundleIdentifier") != "com.anvilfilbert.MacPad":
        raise ValueError(f"The app must use the approved MacPad bundle identifier: {app}")
    executable = app / "Contents" / "MacOS" / "MacPad"
    if not executable.is_file():
        raise FileNotFoundError(f"The MacPad executable is missing from: {app}")
    architectures = subprocess.run(
        ["lipo", "-archs", str(executable)], check=True, capture_output=True, text=True,
    ).stdout.split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise ValueError(f"Universal MacPad requires arm64 and x86_64; found {architectures}: {app}")


def package_disk_image(app: Path, output: Path) -> None:
    validate_app(app)
    checksum = output.with_suffix(".dmg.sha256")
    if output.suffix != ".dmg":
        raise ValueError(f"The output must have a .dmg extension: {output}")
    if output.exists() or checksum.exists():
        raise FileExistsError(f"Refusing to overwrite an existing release or checksum: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="macpad-dmg-") as directory:
        staging = Path(directory)
        staged_app = staging / "MacPad.app"
        # File Provider metadata must not enter the signed bundle on the volume.
        subprocess.run(["ditto", "--norsrc", str(app), str(staged_app)], check=True)
        subprocess.run(["xattr", "-cr", str(staged_app)], check=True)
        validate_app(staged_app)
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(staged_app)], check=True)
        artwork = Path(__file__).resolve().with_name("render-dmg-background.swift")
        for scale in [1, 2]:
            filename = "background.png" if scale == 1 else f"background@{scale}x.png"
            subprocess.run(["swift", str(artwork), str(staging / filename), str(scale)], check=True)
        staged_dmg = staging / output.name
        dmgbuild.build_dmg(
            str(staged_dmg),
            "MacPad",
            settings={
                "format": "UDZO",
                "filesystem": "HFS+",
                "files": [str(staged_app)],
                "symlinks": {"Applications": "/Applications"},
                "icon": str(staged_app / "Contents" / "Resources" / "AppIcon.icns"),
                "background": str(staging / "background.png"),
                "window_rect": ((200, 160), (720, 440)),
                "default_view": "icon-view",
                "icon_locations": {"MacPad.app": (190, 225), "Applications": (530, 225)},
                "icon_size": 112,
                "text_size": 14,
                "grid_spacing": 80,
                "show_status_bar": False,
                "show_tab_view": False,
                "show_toolbar": False,
                "show_pathbar": False,
                "show_sidebar": False,
            },
        )
        subprocess.run(["hdiutil", "verify", str(staged_dmg)], check=True)
        with staged_dmg.open("rb") as source, output.open("xb") as destination:
            shutil.copyfileobj(source, destination)
    with output.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    with checksum.open("x") as destination:
        destination.write(f"{digest}  {output.name}\n")
    print(f"Packaged {output}; signing and notarization are separate release gates.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    package_disk_image(arguments.app.resolve(), arguments.output.resolve())


if __name__ == "__main__":
    main()
