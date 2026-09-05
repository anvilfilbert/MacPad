#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOT_ROOT="$ROOT_DIR/StoreAssets/Screenshots"
TEMP_PARENT="/private/tmp"
TEMP_ROOT="$(/usr/bin/mktemp -d "$TEMP_PARENT/macpad-store-screenshot-validation.XXXXXX")"
VISION_SOURCE="$TEMP_ROOT/vision-scan.swift"
SCAN_OUTPUT="$TEMP_ROOT/vision-scan.txt"
SCAN_ERRORS="$TEMP_ROOT/vision-scan-errors.txt"

cleanup() {
  local status=$?
  trap - EXIT

  case "$TEMP_ROOT" in
    "$TEMP_PARENT"/macpad-store-screenshot-validation.*)
      if ! /bin/rm -rf -- "$TEMP_ROOT"; then
        echo "Could not remove screenshot-validation temporary path: $TEMP_ROOT" >&2
        [[ "$status" -ne 0 ]] || status=1
      fi
      ;;
    *)
      echo "Refusing to remove unexpected screenshot-validation temporary path: $TEMP_ROOT" >&2
      status=1
      ;;
  esac

  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  echo "Store screenshot validation failed: $1" >&2
  exit 1
}

property_value() {
  local properties="$1"
  local property_name="$2"

  /usr/bin/printf '%s\n' "$properties" | /usr/bin/awk -v expected="$property_name" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      prefix = expected ": "
      if (index(line, prefix) == 1) {
        print substr(line, length(prefix) + 1)
        exit
      }
    }
  '
}

validate_image_properties() {
  local image_path="$1"
  local extension="$2"
  local properties
  if ! properties="$(/usr/bin/sips -g pixelWidth -g pixelHeight -g format -g space -g hasAlpha -g profile "$image_path" 2>&1)"; then
    fail "could not read image properties for $image_path: $properties"
  fi

  local width
  local height
  local format
  local color_space
  local has_alpha
  local profile
  width="$(property_value "$properties" pixelWidth)"
  height="$(property_value "$properties" pixelHeight)"
  format="$(property_value "$properties" format)"
  color_space="$(property_value "$properties" space)"
  has_alpha="$(property_value "$properties" hasAlpha)"
  profile="$(property_value "$properties" profile)"

  [[ "$width" =~ ^[0-9]+$ ]] || fail "$image_path has unreadable pixel width '$width'"
  [[ "$height" =~ ^[0-9]+$ ]] || fail "$image_path has unreadable pixel height '$height'"
  [[ "$width" == "1440" && "$height" == "900" ]] || fail "$image_path is ${width}x${height}; expected exactly 1440x900"
  (( width * 10 == height * 16 )) || fail "$image_path does not have the required 16:10 aspect ratio"

  case "$extension" in
    png)
      [[ "$format" == "png" ]] || fail "$image_path has PNG filename extension but '$format' image data"
      ;;
    jpg|jpeg)
      [[ "$format" == "jpeg" ]] || fail "$image_path has JPEG filename extension but '$format' image data"
      ;;
    *)
      fail "$image_path uses unsupported extension '$extension'"
      ;;
  esac

  [[ "$color_space" == "RGB" ]] || fail "$image_path uses '$color_space' color space; expected RGB"
  [[ "$has_alpha" == "no" ]] || fail "$image_path has an alpha channel; screenshots must be opaque"
  [[ "$profile" == "sRGB IEC61966-2.1" ]] || fail "$image_path has profile '$profile'; expected embedded sRGB IEC61966-2.1"
}

write_vision_scanner() {
  /bin/cat >"$VISION_SOURCE" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import Vision

enum ScreenshotScanError: LocalizedError {
    case argumentCount
    case imageSource(String)
    case imageDecode(String)
    case metadata(String)
    case missingOCRResults(String)
    case noRecognizedText(String)
    case missingTextCandidate(String)

    var errorDescription: String? {
        switch self {
        case .argumentCount:
            return "No screenshot paths were provided to the Vision scanner."
        case let .imageSource(path):
            return "ImageIO could not open screenshot: \(path)"
        case let .imageDecode(path):
            return "ImageIO could not decode screenshot: \(path)"
        case let .metadata(path):
            return "ImageIO could not read screenshot metadata: \(path)"
        case let .missingOCRResults(path):
            return "Vision returned no OCR result collection for screenshot: \(path)"
        case let .noRecognizedText(path):
            return "Vision recognized no visible text in screenshot: \(path)"
        case let .missingTextCandidate(path):
            return "Vision returned a text observation without a recognition candidate for screenshot: \(path)"
        }
    }
}

func singleLine(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\t", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
}

func scanScreenshot(path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw ScreenshotScanError.imageSource(path)
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ScreenshotScanError.imageDecode(path)
    }
    guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) else {
        throw ScreenshotScanError.metadata(path)
    }

    let filename = singleLine(url.lastPathComponent)
    print("\(filename)\tFILENAME\t\(filename)")
    print("\(filename)\tMETADATA\t\(singleLine(String(describing: metadata)))")

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US", "de-DE"]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])

    guard let observations = request.results else {
        throw ScreenshotScanError.missingOCRResults(path)
    }
    guard !observations.isEmpty else {
        throw ScreenshotScanError.noRecognizedText(path)
    }
    for observation in observations {
        guard let candidate = observation.topCandidates(1).first else {
            throw ScreenshotScanError.missingTextCandidate(path)
        }
        print("\(filename)\tOCR\t\(singleLine(candidate.string))")
    }
    print("\(filename)\tOCR_COMPLETE\t\(observations.count)")
}

do {
    let paths = Array(CommandLine.arguments.dropFirst())
    guard !paths.isEmpty else {
        throw ScreenshotScanError.argumentCount
    }
    for path in paths {
        try scanScreenshot(path: path)
    }
} catch {
    let nsError = error as NSError
    let detail = "Vision screenshot scan failed: domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)\n"
    FileHandle.standardError.write(Data(detail.utf8))
    exit(1)
}
SWIFT
}

reject_sensitive_pattern() {
  local label="$1"
  local pattern="$2"
  local matching_line
  local matching_file
  local grep_status=0

  matching_line="$(LC_ALL=C /usr/bin/grep -Eim 1 -- "$pattern" "$SCAN_OUTPUT")" || grep_status=$?
  case "$grep_status" in
    0)
      matching_file="$(/usr/bin/printf '%s\n' "$matching_line" | /usr/bin/cut -f 1)"
      fail "$matching_file contains $label in its filename, image metadata, or visible OCR text"
      ;;
    1)
      return 0
      ;;
    *)
      fail "privacy regex scan failed with grep status $grep_status while checking for $label"
      ;;
  esac
}

reject_sensitive_literal() {
  local label="$1"
  local literal="$2"
  [[ ${#literal} -ge 3 ]] || fail "cannot safely scan for $label because the trusted literal is shorter than 3 characters"

  local matching_line
  local matching_file
  local grep_status=0

  matching_line="$(LC_ALL=C /usr/bin/grep -Fim 1 -- "$literal" "$SCAN_OUTPUT")" || grep_status=$?
  case "$grep_status" in
    0)
      matching_file="$(/usr/bin/printf '%s\n' "$matching_line" | /usr/bin/cut -f 1)"
      fail "$matching_file contains $label in its filename, image metadata, or visible OCR text"
      ;;
    1)
      return 0
      ;;
    *)
      fail "privacy literal scan failed with grep status $grep_status while checking for $label"
      ;;
  esac
}

validate_sensitive_content() {
  local account_name
  local full_name
  account_name="$(/usr/bin/id -un)"
  full_name="$(/usr/bin/id -F)"

  reject_sensitive_literal "the current macOS account name" "$account_name"
  reject_sensitive_literal "the current macOS user's full name" "$full_name"
  reject_sensitive_pattern "a common absolute macOS filesystem path" '(^|[^[:alnum:]_])/(Users|private|tmp|Volumes|var|opt|etc|usr|bin|sbin|Applications|Library|System)(/|[[:space:]]|$)'
  reject_sensitive_pattern "a local file URL" 'file:///[^[:space:]]+'
  reject_sensitive_pattern "a home-relative filesystem path" '(^|[^[:alnum:]_])~[/\\]'
  reject_sensitive_pattern "a dot-relative filesystem path" '(^|[^[:alnum:]_])\.\.?[/\\]'
  reject_sensitive_pattern "an email address" '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}'
  reject_sensitive_pattern "an IPv4 address" '(^|[^[:digit:]])([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}([^[:digit:]]|$)'
  reject_sensitive_pattern "a compressed IPv6-shaped address" '(^|[^[:xdigit:]:])(([[:xdigit:]]{1,4}:){0,6}[[:xdigit:]]{1,4})?::(([[:xdigit:]]{1,4}:){0,6}[[:xdigit:]]{1,4})?([^[:xdigit:]:]|$)'
  reject_sensitive_pattern "an uncompressed eight-group IPv6-shaped address" '(^|[^[:xdigit:]:])([[:xdigit:]]{1,4}:){7}[[:xdigit:]]{1,4}([^[:xdigit:]:]|$)'
  reject_sensitive_pattern "a credential assignment" '(api[ _-]?key|access[ _-]?token|auth[ _-]?token|client[ _-]?secret|password|passwd|credential)[[:space:]:=]+[^[:space:]]{4,}'
  reject_sensitive_pattern "a bearer credential" 'bearer[[:space:]]+[[:alnum:]_.=-]{8,}'
  reject_sensitive_pattern "a known token prefix" '(gh[pousr]_[[:alnum:]]{20,}|sk-[[:alnum:]_-]{16,}|AKIA[[:upper:][:digit:]]{16})'
  reject_sensitive_pattern "a long token-like string" '(^|[^[:alnum:]_])[[:alnum:]_=-]{32,}([^[:alnum:]_]|$)'
  reject_sensitive_pattern "a hidden workspace path segment" '((^|[[:space:]])\.[[:alnum:]_-]+[/\\]|[/\\]\.[[:alnum:]_-]+([/\\[:space:]]|$))'
  reject_sensitive_pattern "a build or output workspace path segment" '((^|[[:space:]])(build|dist|out|outputs?|artifacts?|DerivedData)[/\\]|[/\\](build|dist|out|outputs?|artifacts?|DerivedData)([/\\[:space:]]|$))'
  reject_sensitive_pattern "a non-fixture work-artifact extension" '\.(md|xlsx|csv|jsonl|ndjson|env|pem|key|p12|cer|mobileprovision)([^[:alnum:]]|$)'
}

[[ -d "$SCREENSHOT_ROOT" && ! -L "$SCREENSHOT_ROOT" ]] || fail "missing regular screenshot directory: $SCREENSHOT_ROOT"

shopt -s nullglob dotglob
for root_entry in "$SCREENSHOT_ROOT"/*; do
  root_name="$(/usr/bin/basename "$root_entry")"
  case "$root_name" in
    en|de)
      [[ -d "$root_entry" && ! -L "$root_entry" ]] || fail "$root_entry must be a regular directory, not a file or symlink"
      ;;
    *)
      fail "unexpected entry in $SCREENSHOT_ROOT: $root_name; only en and de directories are allowed"
      ;;
  esac
done

expected_stems=(01-menu-bar 02-editor-tabs 03-safe-conflict)
allowed_extensions=(png jpg jpeg)
images=()

for language in en de; do
  language_directory="$SCREENSHOT_ROOT/$language"
  [[ -d "$language_directory" && ! -L "$language_directory" ]] || fail "missing regular language directory: $language_directory"

  for entry in "$language_directory"/*; do
    [[ -f "$entry" && ! -L "$entry" ]] || fail "$entry must be a regular image file, not a directory or symlink"

    filename="$(/usr/bin/basename "$entry")"
    case "$filename" in
      01-menu-bar.png|01-menu-bar.jpg|01-menu-bar.jpeg|\
      02-editor-tabs.png|02-editor-tabs.jpg|02-editor-tabs.jpeg|\
      03-safe-conflict.png|03-safe-conflict.jpg|03-safe-conflict.jpeg)
        ;;
      *)
        fail "unexpected screenshot file: $entry; expected only the three approved scene stems with lowercase .png, .jpg, or .jpeg"
        ;;
    esac
  done

  for stem in "${expected_stems[@]}"; do
    match_count=0
    matched_image=""
    for extension in "${allowed_extensions[@]}"; do
      candidate="$language_directory/$stem.$extension"
      if [[ -e "$candidate" || -L "$candidate" ]]; then
        match_count=$((match_count + 1))
        matched_image="$candidate"
      fi
    done

    [[ "$match_count" -eq 1 ]] || fail "$language_directory must contain exactly one allowed image for scene '$stem'; found $match_count"
    image_path="$matched_image"
    [[ -f "$image_path" && ! -L "$image_path" ]] || fail "$image_path must be a regular image file"
    image_extension="${image_path##*.}"
    validate_image_properties "$image_path" "$image_extension"
    images+=("$image_path")
  done
done

[[ ${#images[@]} -eq 6 ]] || fail "validated ${#images[@]} screenshot paths; expected exactly 6"

write_vision_scanner
if ! /usr/bin/xcrun swift -module-cache-path "$TEMP_ROOT/ModuleCache" "$VISION_SOURCE" "${images[@]}" >"$SCAN_OUTPUT" 2>"$SCAN_ERRORS"; then
  /bin/cat "$SCAN_ERRORS" >&2
  fail "native Vision OCR could not scan all six screenshots"
fi

ocr_completion_grep_status=0
ocr_completion_count="$(LC_ALL=C /usr/bin/grep -c $'\tOCR_COMPLETE\t' "$SCAN_OUTPUT")" || ocr_completion_grep_status=$?
case "$ocr_completion_grep_status" in
  0)
    ;;
  1)
    ocr_completion_count=0
    ;;
  *)
    fail "OCR completion scan failed with grep status $ocr_completion_grep_status"
    ;;
esac
[[ "$ocr_completion_count" == "6" ]] || fail "native Vision OCR completed for $ocr_completion_count screenshots; expected 6"

validate_sensitive_content

echo "Validated 6/6 Store screenshots: 1440x900, 16:10, opaque, embedded sRGB, approved names, and native Vision OCR/privacy scan complete."
