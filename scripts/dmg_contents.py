"""Verify the actual mounted app against the input bundle before releasing a DMG."""

import hashlib
import stat
import subprocess
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path


def bundle_manifest(app: Path) -> dict[str, tuple[int, str]]:
    if app.is_symlink():
        raise ValueError(f"The app bundle root must not be a symbolic link: {app}")
    if not app.is_dir():
        raise FileNotFoundError(f"The app bundle is missing: {app}")
    manifest: dict[str, tuple[int, str]] = {}
    for entry in sorted(app.rglob("*")):
        mode = entry.lstat().st_mode
        if stat.S_ISLNK(mode):
            content = str(entry.readlink())
        elif stat.S_ISREG(mode):
            with entry.open("rb") as source:
                content = hashlib.file_digest(source, "sha256").hexdigest()
        elif stat.S_ISDIR(mode):
            content = ""
        else:
            raise ValueError(f"Unsupported special file in app bundle: {entry}")
        manifest[str(entry.relative_to(app))] = (mode, content)
    return manifest


def verify_app_copy(expected: Path, actual: Path) -> None:
    if bundle_manifest(expected) != bundle_manifest(actual):
        raise ValueError(f"The DMG app does not match the input bundle: {actual}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(actual)], check=True)


@contextmanager
def mounted_disk_image(image: Path) -> Iterator[Path]:
    directory = Path(tempfile.mkdtemp(prefix="macpad-dmg-check-"))
    mount = directory / "mounted"
    attached = subprocess.run(
        ["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(image)],
        check=False, capture_output=True, text=True,
    )
    if attached.returncode != 0:
        raise RuntimeError(
            f"hdiutil attach failed for {image} at {mount} (exit {attached.returncode}): "
            f"{attached.stdout}\n{attached.stderr}. Working directory retained: {directory}"
        )
    try:
        yield mount
    finally:
        detached = subprocess.run(
            ["hdiutil", "detach", str(mount)], check=False, capture_output=True, text=True,
        )
        if detached.returncode != 0:
            raise RuntimeError(
                f"hdiutil detach failed for {image} at {mount} (exit {detached.returncode}): "
                f"{detached.stdout}\n{detached.stderr}. Mount and working directory retained."
            )
        if mount.exists():
            mount.rmdir()
        directory.rmdir()
