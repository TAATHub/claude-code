#!/bin/bash
set -euo pipefail

# Discord API - Thread Operations
# Usage:
#   ./threads.sh info <thread_id>
#   ./threads.sh messages <thread_id> [--limit <n>] [--before <id>] [--after <id>]
#   ./threads.sh active <guild_id>
#   ./threads.sh archived <channel_id> [--type <public|private>] [--limit <n>] [--before <timestamp>]
#   ./threads.sh send <thread_id> <content>

show_usage() {
    cat << 'EOF'
Usage: threads.sh <subcommand> [options]

Subcommands:
  info      Get thread information
  messages  Get messages in a thread
  active    List active threads in a guild
  archived  List archived threads in a channel
  send      Send a message to a thread

info <thread_id>
  Get information about a thread.

messages <thread_id> [options]
  --limit <n>     Number of messages (1-100, default: 50)
  --before <id>   Get messages before this Snowflake ID
  --after <id>    Get messages after this Snowflake ID

active <guild_id>
  List all active (non-archived) threads in the guild.

archived <channel_id> [options]
  --type <public|private>  Thread type (default: public)
  --limit <n>              Number of threads (1-100, default: 50)
  --before <timestamp>     ISO8601 timestamp to filter by archive time

send <thread_id> <content>
  Send a text message to the thread.

Examples:
  threads.sh info 123456789
  threads.sh messages 123456789 --limit 20
  threads.sh active 987654321
  threads.sh archived 123456789 --type private --limit 10
  threads.sh archived 123456789 --before "2024-01-15T00:00:00.000000Z"
  threads.sh send 123456789 "Hello thread!"
EOF
}

# --- Validation functions ---
validate_snowflake_id() {
    local id="$1"
    local name="$2"
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "ERROR: ${name} must be a valid Snowflake ID (numeric only)." >&2
        exit 1
    fi
}

validate_limit() {
    local limit="$1"
    if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -lt 1 ] || [ "$limit" -gt 100 ]; then
        echo "ERROR: --limit must be a number between 1 and 100." >&2
        exit 1
    fi
}

# Escape string for JSON (using Bash built-in parameter expansion)
escape_json_string() {
    local str="$1"
    str="${str//\\/\\\\}"      # Backslash
    str="${str//\"/\\\"}"      # Double quote
    str="${str//$'\t'/\\t}"    # Tab
    str="${str//$'\n'/\\n}"    # Newline
    str="${str//$'\r'/\\r}"    # Carriage return
    printf '%s' "$str"
}

# Help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check DISCORD_BOT_TOKEN
if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
    echo "ERROR: DISCORD_BOT_TOKEN environment variable is not set." >&2
    exit 1
fi

# Validate subcommand
SUBCOMMAND="${1:-}"
if [ -z "$SUBCOMMAND" ]; then
    echo "ERROR: subcommand is required." >&2
    show_usage
    exit 1
fi
shift

# --- info command ---
info_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: thread_id is required." >&2
        exit 1
    fi
    local thread_id="$1"

    validate_snowflake_id "$thread_id" "thread_id"

    curl -s "https://discord.com/api/v10/channels/${thread_id}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- messages command ---
messages_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: thread_id is required." >&2
        exit 1
    fi
    local thread_id="$1"
    validate_snowflake_id "$thread_id" "thread_id"
    shift

    local limit=50
    local before=""
    local after=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --limit)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --limit requires a value." >&2
                    exit 1
                fi
                limit="$2"
                validate_limit "$limit"
                shift 2
                ;;
            --before)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --before requires a value." >&2
                    exit 1
                fi
                before="$2"
                validate_snowflake_id "$before" "--before"
                shift 2
                ;;
            --after)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --after requires a value." >&2
                    exit 1
                fi
                after="$2"
                validate_snowflake_id "$after" "--after"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    # Build query string
    local query="limit=${limit}"
    [ -n "$before" ] && query="${query}&before=${before}"
    [ -n "$after" ] && query="${query}&after=${after}"

    curl -s "https://discord.com/api/v10/channels/${thread_id}/messages?${query}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- active command ---
active_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: guild_id is required." >&2
        exit 1
    fi
    local guild_id="$1"

    validate_snowflake_id "$guild_id" "guild_id"

    curl -s "https://discord.com/api/v10/guilds/${guild_id}/threads/active" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- archived command ---
archived_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: channel_id is required." >&2
        exit 1
    fi
    local channel_id="$1"
    validate_snowflake_id "$channel_id" "channel_id"
    shift

    local thread_type="public"
    local limit=50
    local before=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --type)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --type requires a value." >&2
                    exit 1
                fi
                thread_type="$2"
                if [[ "$thread_type" != "public" && "$thread_type" != "private" ]]; then
                    echo "ERROR: --type must be 'public' or 'private'." >&2
                    exit 1
                fi
                shift 2
                ;;
            --limit)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --limit requires a value." >&2
                    exit 1
                fi
                limit="$2"
                validate_limit "$limit"
                shift 2
                ;;
            --before)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --before requires a value." >&2
                    exit 1
                fi
                before="$2"
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    # Build query string
    local query="limit=${limit}"
    [ -n "$before" ] && query="${query}&before=${before}"

    curl -s "https://discord.com/api/v10/channels/${channel_id}/threads/archived/${thread_type}?${query}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- send command ---
send_command() {
    if [ $# -lt 2 ]; then
        echo "ERROR: thread_id and content are required." >&2
        exit 1
    fi
    local thread_id="$1"
    local content="$2"

    validate_snowflake_id "$thread_id" "thread_id"

    # Escape special characters for JSON
    content=$(escape_json_string "$content")

    curl -s -X POST "https://discord.com/api/v10/channels/${thread_id}/messages" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"${content}\"}"
}

# Execute subcommand
case "$SUBCOMMAND" in
    info)
        info_command "$@"
        ;;
    messages)
        messages_command "$@"
        ;;
    active)
        active_command "$@"
        ;;
    archived)
        archived_command "$@"
        ;;
    send)
        send_command "$@"
        ;;
    *)
        echo "ERROR: Unknown subcommand: $SUBCOMMAND" >&2
        show_usage
        exit 1
        ;;
esac
