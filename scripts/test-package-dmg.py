"""Exercise the real DMG builder; requires build/MacPad.app and dmg-requirements.txt."""

import hashlib
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from ds_store import DSStore
from dmg_contents import mounted_disk_image, verify_app_copy


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build" / "MacPad.app"
BUILDER = ROOT / "scripts" / "package-dmg.py"


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


class DiskImageIntegrationTests(unittest.TestCase):
    def test_busy_image_retains_mount_and_reports_detach_failure(self) -> None:
        with tempfile.TemporaryDirectory(prefix="macpad-busy-image-") as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "fixture.txt").write_text("disposable mount fixture")
            output = root / "busy.dmg"
            subprocess.run(
                ["hdiutil", "create", "-srcfolder", str(source), "-format", "UDZO", str(output)],
                check=True, capture_output=True,
            )
            holder: subprocess.Popen[bytes] | None = None
            mount: Path | None = None
            try:
                with self.assertRaisesRegex(RuntimeError, "hdiutil detach failed") as failure:
                    with mounted_disk_image(output) as mount:
                        holder = subprocess.Popen(["/bin/sleep", "60"], cwd=mount)
                self.assertIsNotNone(mount)
                self.assertTrue(mount.is_mount())
                self.assertIn(str(mount), str(failure.exception))
                self.assertIn("retained", str(failure.exception))
            finally:
                if holder is not None:
                    holder.terminate()
                    holder.wait(timeout=5)
                if mount is not None and mount.is_mount():
                    subprocess.run(["hdiutil", "detach", str(mount)], check=True, capture_output=True)
                    if mount.exists():
                        mount.rmdir()
                    mount.parent.rmdir()

    def test_app_bundle_root_cannot_be_an_external_symbolic_link(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        with tempfile.TemporaryDirectory(prefix="macpad-app-link-") as directory:
            linked_app = Path(directory) / "MacPad.app"
            linked_app.symlink_to(APP)
            with self.assertRaisesRegex(ValueError, "root must not be a symbolic link"):
                verify_app_copy(APP, linked_app)

    def test_staging_preserves_metadata_on_outward_symlink_targets(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        with tempfile.TemporaryDirectory(prefix="macpad-link-safety-") as directory:
            root = Path(directory)
            app = root / "MacPad.app"
            subprocess.run(["ditto", "--norsrc", str(APP), str(app)], check=True)
            external_directory = root / "outside"
            external_directory.mkdir()
            external_file = external_directory / "preserve.txt"
            external_file.write_text("unrelated data")
            attribute = "com.example.macpad.test"
            for target in [external_directory, external_file]:
                subprocess.run(["xattr", "-w", attribute, "preserve-me", str(target)], check=True)
                (app / "Contents" / "Resources" / target.name).symlink_to(target)
            output = root / "MacPad.dmg"
            result = subprocess.run(
                [sys.executable, str(BUILDER), str(app), str(output)],
                capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0, "The modified signature must be rejected")
            self.assertFalse(output.exists())
            for target in [external_directory, external_file]:
                metadata = subprocess.run(
                    ["xattr", "-p", attribute, str(target)],
                    check=True, capture_output=True, text=True,
                ).stdout.strip()
                self.assertEqual(metadata, "preserve-me")
            self.assertEqual(external_file.read_text(), "unrelated data")

    def test_mounted_image_with_a_changed_app_is_rejected(self) -> None:
        self.assertTrue(APP.is_dir(), "Build the real app with scripts/build-app.sh first")
        with tempfile.TemporaryDirectory(prefix="macpad-dmg-mismatch-") as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            app = source / "MacPad.app"
            subprocess.run(["ditto", "--norsrc", str(APP), str(app)], check=True)
            (app / "Contents" / "Resources" / "unexpected.txt").write_text("changed copy")
            output = root / "changed.dmg"
            subprocess.run(
                ["hdiutil", "create", "-srcfolder", str(source), "-format", "UDZO", str(output)],
                check=True, capture_output=True,
            )
            with mounted_disk_image(output) as mount:
                with self.assertRaisesRegex(ValueError, "does not match the input bundle"):
                    verify_app_copy(APP, mount / "MacPad.app")

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
