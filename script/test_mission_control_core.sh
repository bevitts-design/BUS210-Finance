#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bus210-mission-control-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT

swiftc \
  -swift-version 5 \
  -o "$CHECK_DIR/bus210-mission-control-core-checks" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Models/CourseMapModels.swift" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Models/PublishingModels.swift" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Services/RepositoryLocator.swift" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Services/JSONSourceEditor.swift" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Services/CourseMapService.swift" \
  "$ROOT_DIR/MissionControl/Sources/BUS210MissionControl/Services/GitPublishService.swift" \
  "$ROOT_DIR/MissionControl/Tests/CoreChecks/main.swift"

BUS210_REPO_ROOT="$ROOT_DIR" "$CHECK_DIR/bus210-mission-control-core-checks"
