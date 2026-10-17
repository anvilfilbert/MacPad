"""Sign, notarize, staple, and assess a prebuilt MacPad app and its DMG.

Run with the project-local interpreter after installing dmg-requirements.txt:
    python scripts/notarize-dmg.py APP IDENTITY_SHA1 TEAM KEYCHAIN_PROFILE OUTPUT

An owner-created Developer ID Application identity and existing notarytool
Keychain profile are required. This command never creates credentials, revokes
certificates, uploads to GitHub, or overwrites release files. Private submission
receipts stay in a restricted temporary directory outside the repository. If
Apple is still processing after the wait, use the recorded submission ID to
inspect/resume that submission rather than running another upload.

Manual continuation after a timeout (use the printed private working directory):
1. Read submission.json for its id and run xcrun notarytool wait ID with the
   same --keychain-profile PROFILE --timeout 10m --output-format json. Require
   the same id and status Accepted; otherwise inspect xcrun notarytool log ID.
2. Run xcrun stapler staple DMG and xcrun stapler validate DMG on the retained
   candidate, then codesign --verify --strict DMG and hdiutil verify DMG.
3. Mount the DMG read-only. Use dmg_contents.verify_app_copy to compare its
   MacPad.app with the retained signed app, run verify-developer-id.py on the
   mounted app with the expected team, and run spctl --assess --type execute
   --verbose=4 on that mounted app. Detach the image, then run spctl --assess
   --type open --context context:primary-signature --verbose=4 on the DMG.
   Every check must succeed. Do not bypass a failed assessment.
4. Copy only the verified DMG to a new destination, never overwrite a release,
   and generate its .dmg.sha256 using shasum -a 256 on the final stapled bytes.
   Verify that checksum again before any separately authorized publication.
"""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from uuid import UUID

from dmg_contents import mounted_disk_image, verify_app_copy


def require_identity(identity: str, team: str) -> None:
    if re.fullmatch(r"[A-Fa-f0-9]{40}", identity) is None:
        raise ValueError("The signing identity must be its explicit 40-character SHA-1 fingerprint")
    if re.fullmatch(r"[A-Z0-9]{10}", team) is None:
        raise ValueError("The developer team must be an explicit 10-character Team ID")
    identities = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        check=True, capture_output=True, text=True,
    ).stdout
    matching = [line for line in identities.splitlines() if identity.upper() in line]
    if len(matching) != 1 or '"Developer ID Application:' not in matching[0]:
        raise ValueError("No usable Developer ID Application identity matches the requested fingerprint")
    if f"({team})" not in matching[0]:
        raise ValueError("The requested Developer ID identity does not belong to the expected team")


def read_submission_id(payload: object) -> str:
    if not isinstance(payload, dict) or not isinstance(payload.get("id"), str):
        raise ValueError("Apple's notarization response does not contain a string submission ID")
    identifier = payload["id"]
    UUID(identifier)
    return identifier


def notarize(candidate: Path, profile: str, receipt_directory: Path) -> None:
    submitted = subprocess.run(
        ["xcrun", "notarytool", "submit", str(candidate), "--keychain-profile", profile,
         "--output-format", "json"],
        check=False, capture_output=True, text=True,
    )
    (receipt_directory / "submit.stdout").write_text(submitted.stdout)
    (receipt_directory / "submit.stderr").write_text(submitted.stderr)
    if submitted.returncode != 0:
        raise RuntimeError(
            f"notarytool submit exited {submitted.returncode}: {submitted.stderr}. "
            f"Private stdout/stderr are in {receipt_directory}. Inspect them before "
            "another submission; an upload may already have reached Apple."
        )
    (receipt_directory / "submission.json").write_text(submitted.stdout)
    identifier = read_submission_id(json.loads(submitted.stdout))
    print(f"Notarization submitted; private receipts: {receipt_directory}", flush=True)
    waited = subprocess.run(
        ["xcrun", "notarytool", "wait", identifier, "--keychain-profile", profile,
         "--timeout", "10m", "--output-format", "json"],
        check=False, capture_output=True, text=True,
    )
    (receipt_directory / "wait.stdout").write_text(waited.stdout)
    (receipt_directory / "wait.stderr").write_text(waited.stderr)
    if waited.returncode != 0:
        raise RuntimeError(
            f"notarytool wait exited {waited.returncode}: {waited.stderr}. "
            f"Submission {identifier} may still be processing. Inspect the receipts in "
            f"{receipt_directory}; do not submit another copy."
        )
    result: object = json.loads(waited.stdout)
    if read_submission_id(result) != identifier:
        raise ValueError("Apple's notarization wait response refers to a different submission")
    if not isinstance(result, dict) or result.get("status") != "Accepted":
        raise ValueError(f"Apple did not accept the notarization; inspect {receipt_directory}")


def release(app: Path, identity: str, team: str, profile: str, output: Path) -> None:
    require_identity(identity, team)
    if not app.is_dir() or app.name != "MacPad.app":
        raise FileNotFoundError(f"A prebuilt MacPad.app is required: {app}")
    checksum = output.with_suffix(".dmg.sha256")
    if output.suffix != ".dmg" or output.exists() or checksum.exists():
        raise ValueError(f"A new .dmg output and checksum path are required: {output}")
    if not profile.strip():
        raise ValueError("An existing notarytool Keychain profile name is required")
    working = Path(tempfile.mkdtemp(prefix="macpad-notarization-"))
    print(f"Private release working directory: {working}", flush=True)
    signed_app = working / "MacPad.app"
    subprocess.run(["ditto", "--norsrc", str(app), str(signed_app)], check=True)
    subprocess.run(["xattr", "-crs", str(signed_app)], check=True)
    subprocess.run(
        ["codesign", "--force", "--options", "runtime", "--timestamp", "--sign", identity, str(signed_app)],
        check=True,
    )
    scripts = Path(__file__).resolve().parent
    subprocess.run([sys.executable, str(scripts / "verify-developer-id.py"), str(signed_app), team], check=True)
    candidate = working / output.name
    subprocess.run([sys.executable, str(scripts / "package-dmg.py"), str(signed_app), str(candidate)], check=True)
    subprocess.run(["codesign", "--timestamp", "--sign", identity, str(candidate)], check=True)
    notarize(candidate, profile, working)
    subprocess.run(["xcrun", "stapler", "staple", str(candidate)], check=True)
    subprocess.run(["xcrun", "stapler", "validate", str(candidate)], check=True)
    subprocess.run(["codesign", "--verify", "--strict", str(candidate)], check=True)
    subprocess.run(["hdiutil", "verify", str(candidate)], check=True)
    with mounted_disk_image(candidate) as mount:
        contained_app = mount / "MacPad.app"
        verify_app_copy(signed_app, contained_app)
        subprocess.run(
            [sys.executable, str(scripts / "verify-developer-id.py"), str(contained_app), team],
            check=True,
        )
        subprocess.run(["spctl", "--assess", "--type", "execute", "--verbose=4", str(contained_app)], check=True)
    subprocess.run(
        ["spctl", "--assess", "--type", "open", "--context", "context:primary-signature", "--verbose=4", str(candidate)],
        check=True,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    with candidate.open("rb") as source, output.open("xb") as destination:
        shutil.copyfileobj(source, destination)
    # Signing and stapling alter the DMG; hash only the final, verified bytes.
    with output.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    with checksum.open("x") as destination:
        destination.write(f"{digest}  {output.name}\n")
    print(f"Verified signed and notarized DMG: {output}")
    print(f"Final SHA-256: {digest}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("identity")
    parser.add_argument("team")
    parser.add_argument("keychain_profile")
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    release(arguments.app.resolve(), arguments.identity, arguments.team,
            arguments.keychain_profile, arguments.output.resolve())


if __name__ == "__main__":
    main()
