#!/bin/bash
set -euo pipefail
# Script to calculate Discord Snowflake ID from a date
# Usage:
#   ./date-to-snowflake.sh                # Snowflake ID for today at 00:00:00 UTC
#   ./date-to-snowflake.sh 2024-01-15     # Snowflake ID for specified date at 00:00:00 UTC
#   ./date-to-snowflake.sh 2024-01-15 JST # Snowflake ID for specified date at 00:00:00 JST (= previous day 15:00:00 UTC)

# Help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [YYYY-MM-DD] [TIMEZONE]"
    echo "  YYYY-MM-DD  Target date (default: today)"
    echo "  TIMEZONE    UTC or JST (default: UTC)"
    exit 0
fi

if [ -n "${1:-}" ]; then
    TARGET_DATE="$1"
else
    TARGET_DATE=$(date -u "+%Y-%m-%d")
fi

# Second argument specifies timezone (special handling for JST)
TIMEZONE="${2:-UTC}"

# Validate date format
if [[ -n "$TARGET_DATE" && ! "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: Invalid date format. Please use YYYY-MM-DD format." >&2
    exit 1
fi

# Validate timezone
if [[ "$TIMEZONE" != "UTC" && "$TIMEZONE" != "JST" ]]; then
    echo "ERROR: Invalid timezone. Supported values: UTC, JST" >&2
    exit 1
fi

# Detect OS and switch date command accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if [[ "$TIMEZONE" == "JST" ]]; then
        # JST 00:00:00 = UTC previous day 15:00:00
        # First get timestamp for specified date at UTC 00:00:00, then subtract 9 hours (32400 seconds)
        timestamp_s=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$TARGET_DATE 00:00:00" "+%s" 2>/dev/null)
        if [ -n "$timestamp_s" ]; then
            timestamp_s=$((timestamp_s - 32400))
        fi
    else
        # UTC 00:00:00 (default behavior)
        timestamp_s=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$TARGET_DATE 00:00:00" "+%s" 2>/dev/null)
    fi
else
    # Linux (GNU date)
    if [[ "$TIMEZONE" == "JST" ]]; then
        # JST 00:00:00 = UTC previous day 15:00:00
        timestamp_s=$(date -u -d "$TARGET_DATE 00:00:00" "+%s" 2>/dev/null)
        if [ -n "$timestamp_s" ]; then
            timestamp_s=$((timestamp_s - 32400))
        fi
    else
        # UTC 00:00:00 (default behavior)
        timestamp_s=$(date -u -d "$TARGET_DATE 00:00:00" "+%s" 2>/dev/null)
    fi
fi

if [ -z "$timestamp_s" ]; then
    echo "ERROR: Invalid date format. Please use YYYY-MM-DD format." >&2
    exit 1
fi

# Discord Snowflake ID calculation: (timestamp_ms - 1420070400000) << 22
snowflake=$(( ($timestamp_s * 1000 - 1420070400000) << 22 ))
echo "$snowflake"
