"""Exercise the real DMG builder; requires build/MacPad.app and dmg-requirements.txt."""

import hashlib
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from ds_store import DSStore


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build" / "MacPad.app"
BUILDER = ROOT / "scripts" / "package-dmg.py"


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


class DiskImageIntegrationTests(unittest.TestCase):
    def test_single_architecture_app_is_rejected_without_creating_output(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        with tempfile.TemporaryDirectory(prefix="macpad-thin-app-") as directory:
            app = Path(directory) / "MacPad.app"
            subprocess.run(["ditto", "--norsrc", str(APP), str(app)], check=True)
            executable = app / "Contents" / "MacOS" / "MacPad"
            thin = Path(directory) / "MacPad-arm64"
            subprocess.run(["lipo", str(executable), "-thin", "arm64", "-output", str(thin)], check=True)
            thin.replace(executable)
            subprocess.run(["xattr", "-cr", str(app)], check=True)
            subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
            output = Path(directory) / "MacPad.dmg"
            result = subprocess.run(
                [sys.executable, str(BUILDER), str(app), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Universal MacPad requires arm64 and x86_64", result.stderr)
            self.assertFalse(output.exists())

    def test_release_preflight_refuses_unknown_identity_without_touching_app(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        original = sha256(APP / "Contents" / "MacOS" / "MacPad")
        with tempfile.TemporaryDirectory(prefix="macpad-signing-gate-") as directory:
            output = Path(directory) / "MacPad.dmg"
            result = subprocess.run(
                [
                    sys.executable, str(ROOT / "scripts" / "notarize-dmg.py"),
                    str(APP), "0000000000000000000000000000000000000000",
                    "TESTTEAM01", "missing-notary-profile", str(output),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No usable Developer ID Application identity matches", result.stderr)
            self.assertFalse(output.exists())
            self.assertEqual(sha256(APP / "Contents" / "MacOS" / "MacPad"), original)

    def test_public_release_gate_rejects_the_real_ad_hoc_app(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "verify-developer-id.py"), str(APP), "TESTTEAM"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Developer ID Application signature is required", result.stderr)

    def test_missing_app_is_rejected_without_creating_output(self) -> None:
        with tempfile.TemporaryDirectory(prefix="macpad-dmg-missing-") as directory:
            output = Path(directory) / "MacPad.dmg"
            result = subprocess.run(
                [sys.executable, str(BUILDER), str(Path(directory) / "Missing.app"), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("MacPad.app bundle does not exist", result.stderr)
            self.assertFalse(output.exists())

    def test_dmg_preserves_app_and_opens_as_drag_to_applications(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        with tempfile.TemporaryDirectory(prefix="macpad-dmg-integration-") as directory:
            output = Path(directory) / "MacPad.dmg"
            result = subprocess.run(
                [sys.executable, str(BUILDER), str(APP), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            subprocess.run(["hdiutil", "verify", str(output)], check=True, capture_output=True)
            mount = Path(directory) / "mounted"
            subprocess.run(
                ["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(output)],
                check=True,
                capture_output=True,
            )
            try:
                self.assertEqual((mount / "Applications").readlink(), Path("/Applications"))
                self.assertEqual(
                    sha256(APP / "Contents" / "MacOS" / "MacPad"),
                    sha256(mount / "MacPad.app" / "Contents" / "MacOS" / "MacPad"),
                )
                signature = subprocess.run(
                    ["codesign", "--verify", "--deep", "--strict", str(mount / "MacPad.app")],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(signature.returncode, 0, signature.stdout + signature.stderr)
                with DSStore.open(str(mount / ".DS_Store"), "r") as store:
                    self.assertEqual(store["MacPad.app"]["Iloc"], (190, 225))
                    self.assertEqual(store["Applications"]["Iloc"], (530, 225))
                    self.assertEqual(store["."]["vSrn"], (b"long", 1))
                    self.assertEqual(store["."]["icvp"]["backgroundType"], 2)
                self.assertTrue((mount / ".background.tiff").is_file())
                checksum = output.with_suffix(".dmg.sha256")
                self.assertEqual(checksum.read_text(), f"{sha256(output)}  MacPad.dmg\n")
                with (mount / "MacPad.app" / "Contents" / "Info.plist").open("rb") as source:
                    info = plistlib.load(source)
                self.assertEqual(info["CFBundleIdentifier"], "com.anvilfilbert.MacPad")
            finally:
                subprocess.run(["hdiutil", "detach", str(mount)], check=True, capture_output=True)
            original = sha256(output)
            duplicate = subprocess.run(
                [sys.executable, str(BUILDER), str(APP), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertEqual(sha256(output), original)


if __name__ == "__main__":
    unittest.main()
