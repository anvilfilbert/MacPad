"""Prepare an allowlisted, privacy-checked artifact; never upload databases.

Raw means unfiltered findings, not unredacted runner paths. Both SARIF copies
retain all findings; only environment path prefixes are replaced. Missing
summary.json means the audit did not complete, even if partial logs exist.
No signing, credentials, author metadata, or environment dump is collected.
"""

import hashlib
import json
import os
import re
import sys
from pathlib import Path


def sanitize(text: str, prefixes: tuple[tuple[str, str], ...]) -> str:
    result = text
    for prefix, replacement in sorted(prefixes, key=lambda pair: len(pair[0]), reverse=True):
        result = result.replace(prefix, replacement)
    forbidden = (
        r"/(?:Users|home)/[^/\s]+",
        r"github_pat_[A-Za-z0-9_]+|gh[opusr]_[A-Za-z0-9_]{20,}",
        r"AKIA[0-9A-Z]{16}|BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY",
        r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    )
    if any(re.search(pattern, result) for pattern in forbidden):
        raise ValueError("Artifact privacy check failed; inspect locally, do not upload")
    return result


def evidence_files(root: Path) -> tuple[tuple[Path, Path], ...]:
    files: list[tuple[Path, Path]] = []
    for directory, label in (
        (root / "evidence", Path(".")),
        (root / "codeql.db/log", Path("database-logs")),
        (root / "codeql.db/diagnostic", Path("extractor-diagnostics")),
    ):
        for path in sorted(directory.rglob("*")):
            if path.is_symlink():
                raise ValueError("Unexpected symbolic link in audit evidence")
            if path.is_file() and path.suffix in {".log", ".json", ".jsonl", ".txt", ".csv", ".sarif", ".qls", ".ql"}:
                files.append((path, label / path.relative_to(directory)))
    for name in ("codeql-database.yml", "baseline-info.json"):
        path = root / "codeql.db" / name
        if path.is_file():
            files.append((path, Path("database-metadata") / name))
    if not files:
        raise ValueError("No audit evidence exists; refusing empty artifact")
    return tuple(files)


def main(root: Path, destination: Path) -> None:
    prefixes = (
        (str(root), "$AUDIT_ROOT"),
        (os.environ["GITHUB_WORKSPACE"], "$WORKSPACE"),
        (os.environ["RUNNER_TEMP"], "$RUNNER_TEMP"),
        (str(Path.home()), "$RUNNER_HOME"),
    )
    # Validate every file before creating the upload directory.
    prepared = tuple(
        (relative, sanitize(source.read_text(encoding="utf-8"), prefixes))
        for source, relative in evidence_files(root)
    )
    destination.mkdir()
    hashes: dict[str, str] = {}
    for relative, content in prepared:
        output = destination / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(content, encoding="utf-8")
        hashes[str(relative)] = hashlib.sha256(content.encode("utf-8")).hexdigest()
    (destination / "artifact-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
