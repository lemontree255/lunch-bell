#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
checks_dir=$(mktemp -d)
trap 'rm -rf "$checks_dir"' EXIT
swiftc Sources/LunchBell/Schedule.swift Tests/ScheduleChecks.swift -o "$checks_dir/schedule-checks"
"$checks_dir/schedule-checks"
