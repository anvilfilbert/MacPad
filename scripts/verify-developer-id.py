"""Fail closed unless an app has a valid timestamped Developer ID signature.

Usage: python3 scripts/verify-developer-id.py path/to/MacPad.app EXPECTED_TEAM_ID
This verifies signing only. Gatekeeper and a stapled notarization ticket must
also pass before the final DMG can be published.
"""

import argparse
import re
import subprocess
from pathlib import Path


def verify_developer_id(app: Path, team: str) -> None:
    details = subprocess.run(
        ["codesign", "--display", "--verbose=4", str(app)],
        check=True,
        capture_output=True,
        text=True,
    ).stderr
    if "Authority=Developer ID Application:" not in details:
        raise ValueError(f"Developer ID Application signature is required: {app}")
    if f"TeamIdentifier={team}" not in details.splitlines():
        raise ValueError(f"The app signature does not match expected team {team}: {app}")
    if re.search(r"\bflags=[^\n]*\bruntime\b", details) is None:
        raise ValueError(f"The app signature is missing Hardened Runtime: {app}")
    if re.search(r"^Timestamp=.+", details, re.MULTILINE) is None:
        raise ValueError(f"The app signature is missing a secure timestamp: {app}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print("Developer ID signature, team, Hardened Runtime and timestamp verified.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("team")
    arguments = parser.parse_args()
    verify_developer_id(arguments.app.resolve(), arguments.team)


if __name__ == "__main__":
    main()
