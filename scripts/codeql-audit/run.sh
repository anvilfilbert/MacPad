#!/usr/bin/env bash
# CI-only traced build. Never run on the unsupported local macOS 27 host.
set -euo pipefail
AUDIT_SOURCE="$1"
AUDIT_REF="$2"
AUDIT_ROOT="$3"
AUDIT_HELPERS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Create logs before checking invariants, without reusing any existing output.
mkdir "$AUDIT_ROOT"
mkdir "$AUDIT_ROOT/evidence" "$AUDIT_ROOT/evidence/raw" "$AUDIT_ROOT/evidence/results"
exec > "$AUDIT_ROOT/evidence/build.log" 2>&1

fail_preflight() {
  printf 'Preflight failed: %s\n' "$1" >&2
  exit 1
}

[[ "${GITHUB_ACTIONS:-}" == true ]] || fail_preflight 'CI context: expected GITHUB_ACTIONS=true; observed not true. No extraction attempted.'
ACTUAL_PLATFORM="$(uname -s)"
[[ "$ACTUAL_PLATFORM" == Darwin ]] || fail_preflight "Platform: expected Darwin; observed $ACTUAL_PLATFORM."
ACTUAL_OS="$(sw_vers -productVersion)"
[[ "$ACTUAL_OS" == 15.* ]] || fail_preflight "Runner OS: expected macOS 15.x; observed $ACTUAL_OS."
[[ "$AUDIT_REF" =~ ^[a-f0-9]{40}$ ]] || fail_preflight 'Source ref: expected 40 lowercase hexadecimal characters; observed invalid format.'
ACTUAL_REF="$(git -C "$AUDIT_SOURCE" rev-parse HEAD)"
[[ "$ACTUAL_REF" == "$AUDIT_REF" ]] || fail_preflight "Source head: expected $AUDIT_REF; observed $ACTUAL_REF."
ACTUAL_STATUS="$(git -C "$AUDIT_SOURCE" status --porcelain --untracked-files=all)"
[[ -z "$ACTUAL_STATUS" ]] || fail_preflight "Clean checkout: expected 0 changed/untracked entries; observed $(printf '%s\n' "$ACTUAL_STATUS" | wc -l | tr -d ' ')."
[[ "${DEVELOPER_DIR:-}" == /Applications/Xcode_16.4.app/Contents/Developer ]] || fail_preflight 'Toolchain selection: expected Xcode_16.4.app/Contents/Developer; observed a different or unset path.'
ACTUAL_XCODE="$(xcodebuild -version)"
ACTUAL_SWIFT="$(xcrun swift --version)"
[[ "$ACTUAL_XCODE" == *"Xcode 16.4"* ]] || fail_preflight "Xcode version: expected 16.4; observed $ACTUAL_XCODE."
[[ "$ACTUAL_SWIFT" == *"Swift version 6.1"* ]] || fail_preflight "Swift version: expected 6.1.x; observed $ACTUAL_SWIFT."
set -x
xcodebuild -version
xcrun swift --version
python3 --version
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$AUDIT_SOURCE/Resources/Info.plist")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$AUDIT_SOURCE/Resources/Info.plist")"
[[ "$ACTUAL_VERSION" == "$AUDIT_VERSION" && "$ACTUAL_BUILD" == "$AUDIT_BUILD" ]] || fail_preflight "Product identity: expected $AUDIT_VERSION ($AUDIT_BUILD); observed $ACTUAL_VERSION ($ACTUAL_BUILD)."
printf 'source=%s\nhelpers=%s\nrun=%s\nattempt=%s\nimage=%s\nversion=%s\nbuild=%s\n' \
  "$AUDIT_REF" "$AUDIT_HELPER_REF" "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT" "$ImageVersion" "$ACTUAL_VERSION" "$ACTUAL_BUILD" \
  > "$AUDIT_ROOT/evidence/provenance.txt"
bash "$AUDIT_HELPERS/install-tools.sh" "$AUDIT_ROOT/tools"
CODEQL="$AUDIT_ROOT/tools/codeql/codeql"
"$CODEQL" version --format=json > "$AUDIT_ROOT/evidence/codeql-version.json"
"$CODEQL" resolve qlpacks --format=json > "$AUDIT_ROOT/evidence/packs.json"
cp "$AUDIT_HELPERS/run-all.qls" "$AUDIT_ROOT/evidence/raw/run-all.qls"
cp -R "$AUDIT_HELPERS/diagnostics" "$AUDIT_ROOT/diagnostics"
# Use only dependency versions shipped in the digest-verified bundle.
# Custom queries resolve against these packs without a registry update.
python3 "$AUDIT_ROOT/tools/verify_query_suite.py" "$AUDIT_HELPERS/run-all.qls" --codeql "$CODEQL"
"$CODEQL" resolve queries --format=json "$AUDIT_HELPERS/run-all.qls" > "$AUDIT_ROOT/evidence/queries.json"
"$CODEQL" resolve queries --format=json \
  codeql/swift-queries:codeql-suites/swift-security-and-quality.qls \
  codeql/swift-queries:codeql-suites/swift-security-experimental.qls \
  > "$AUDIT_ROOT/evidence/official-queries.json"
git -C "$AUDIT_SOURCE" ls-files 'Sources/*.swift' > "$AUDIT_ROOT/evidence/expected-files.txt"

# An unused scratch directory guarantees compilation, rather than a cached no-op.
cd "$AUDIT_SOURCE"
"$CODEQL" database create "$AUDIT_ROOT/codeql.db" --language=swift \
  --source-root="$AUDIT_SOURCE" --build-mode=manual \
  --command="swift build --scratch-path '$AUDIT_ROOT/swift-build' --disable-dependency-cache"
python3 "$AUDIT_ROOT/tools/check_db_quality.py" "$AUDIT_ROOT/codeql.db" --max-error-ratio 0 --format=json \
  > "$AUDIT_ROOT/evidence/database-quality.json"

for query in extracted-files sources sinks calls; do
  "$CODEQL" query run --database="$AUDIT_ROOT/codeql.db" --threads=2 --ram=6000 \
    --common-caches="$AUDIT_ROOT/ql-cache" --search-path="$AUDIT_ROOT/tools/codeql/qlpacks" \
    --output="$AUDIT_ROOT/$query.bqrs" "$AUDIT_ROOT/diagnostics/$query.ql"
  "$CODEQL" bqrs decode --format=csv --output="$AUDIT_ROOT/evidence/$query.csv" "$AUDIT_ROOT/$query.bqrs"
done
python3 "$AUDIT_HELPERS/check_evidence.py" "$AUDIT_ROOT/evidence"
"$CODEQL" database analyze "$AUDIT_ROOT/codeql.db" "$AUDIT_HELPERS/run-all.qls" \
  --threads=2 --ram=6000 --threat-model=local --format=sarifv2.1.0 \
  --no-sarif-group-rules-by-pack \
  --common-caches="$AUDIT_ROOT/ql-cache" \
  --sarif-category="macpad-audit/$AUDIT_LABEL/$AUDIT_REF" \
  --output="$AUDIT_ROOT/evidence/raw/results.sarif"
cp "$AUDIT_ROOT/evidence/raw/results.sarif" "$AUDIT_ROOT/evidence/results/results.sarif"
python3 "$AUDIT_HELPERS/summarize_results.py" "$AUDIT_ROOT/evidence" "$CODEQL"

# Keep official results intact. Supplemental local flows are review candidates,
# not automatically vulnerabilities: user-chosen file paths are normal in MacPad.
mkdir -p "$AUDIT_ROOT/evidence/supplement/raw" "$AUDIT_ROOT/evidence/supplement/results"
"$CODEQL" resolve queries --format=json "$AUDIT_ROOT/diagnostics/local-path-flow.ql" \
  > "$AUDIT_ROOT/evidence/supplement/queries.json"
cp "$AUDIT_ROOT/diagnostics/local-path-flow.ql" "$AUDIT_ROOT/evidence/supplement/local-path-flow.ql"
"$CODEQL" database analyze "$AUDIT_ROOT/codeql.db" "$AUDIT_ROOT/diagnostics/local-path-flow.ql" \
  --threads=2 --ram=6000 --format=sarifv2.1.0 \
  --no-sarif-group-rules-by-pack \
  --common-caches="$AUDIT_ROOT/ql-cache" --search-path="$AUDIT_ROOT/tools/codeql/qlpacks" \
  --sarif-category="macpad-local-input-review/$AUDIT_LABEL/$AUDIT_REF" \
  --output="$AUDIT_ROOT/evidence/supplement/raw/results.sarif"
cp "$AUDIT_ROOT/evidence/supplement/raw/results.sarif" "$AUDIT_ROOT/evidence/supplement/results/results.sarif"
python3 "$AUDIT_HELPERS/summarize_local_inputs.py" "$AUDIT_ROOT/evidence"
