#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MeasureAnything/MeasureAnything.xcodeproj"
SCHEME_NAME="${SCHEME_NAME:-MeasureAnything}"
TEST_TARGET="${TEST_TARGET:-MeasureAnythingTests}"
DEFAULT_SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DEFAULT_SIMULATOR_OS="${SIMULATOR_OS:-26.1}"

find_simulator_id() {
  local name="$1"
  local os="$2"
  local current_os=""
  local line trimmed

  while IFS= read -r line; do
    if [[ "$line" =~ ^--\ iOS\ ([0-9.]+)\ --$ ]]; then
      current_os="${BASH_REMATCH[1]}"
      continue
    fi

    [[ "$current_os" == "$os" ]] || continue
    trimmed="${line#"${line%%[![:space:]]*}"}"

    if [[ "$trimmed" =~ ^(.*)\ \(([0-9A-F-]{36})\)\ \((.*)\)[[:space:]]*$ ]]; then
      if [[ "${BASH_REMATCH[1]}" == "$name" ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
        return 0
      fi
    fi
  done < <(xcrun simctl list devices available)
}

find_simulator_name() {
  local id="$1"
  local line trimmed

  while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ "$trimmed" =~ ^(.*)\ \(([0-9A-F-]{36})\)\ \((.*)\)[[:space:]]*$ ]]; then
      if [[ "${BASH_REMATCH[2]}" == "$id" ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
      fi
    fi
  done < <(xcrun simctl list devices available)
}

SIMULATOR_ID="${SIMULATOR_ID:-}"
if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(find_simulator_id "$DEFAULT_SIMULATOR_NAME" "$DEFAULT_SIMULATOR_OS")"
fi

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "Could not find an available simulator for '$DEFAULT_SIMULATOR_NAME' on iOS $DEFAULT_SIMULATOR_OS." >&2
  echo "Set SIMULATOR_ID directly, or override SIMULATOR_NAME and SIMULATOR_OS." >&2
  exit 1
fi

RESOLVED_SIMULATOR_NAME="${SIMULATOR_NAME:-$(find_simulator_name "$SIMULATOR_ID")}"
echo "Using simulator: ${RESOLVED_SIMULATOR_NAME:-unknown} (${SIMULATOR_ID}) on iOS ${DEFAULT_SIMULATOR_OS}"

if ! xcrun simctl list devices | grep -Fq "$SIMULATOR_ID (Booted)"; then
  xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
fi

xcrun simctl bootstatus "$SIMULATOR_ID" -b

cd "$ROOT_DIR"

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -destination-timeout 120 \
  -skip-testing:MeasureAnythingUITests \
  -only-testing:"$TEST_TARGET"
