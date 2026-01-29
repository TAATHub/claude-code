#!/bin/bash
set -euo pipefail

# Discord API - Message Operations
# Usage:
#   ./messages.sh get <channel_id> [--limit <n>] [--before <id>] [--after <id>] [--around <id>]
#   ./messages.sh send <channel_id> <content>
#   ./messages.sh upload <channel_id> [--content <text>] --file <path> [--file <path>...]

show_usage() {
    cat << 'EOF'
Usage: messages.sh <subcommand> [options]

Subcommands:
  get      Get messages from a channel
  send     Send a text message
  upload   Send a message with file attachments

get <channel_id> [options]
  --limit <n>     Number of messages (1-100, default: 50)
  --before <id>   Get messages before this Snowflake ID
  --after <id>    Get messages after this Snowflake ID
  --around <id>   Get messages around this Snowflake ID

send <channel_id> <content>
  Send a text message to the channel

upload <channel_id> [options]
  --content <text>   Optional message text
  --file <path>      File to upload (can be specified multiple times)

Examples:
  messages.sh get 123456789 --limit 20
  messages.sh get 123456789 --after 987654321
  messages.sh send 123456789 "Hello, World!"
  messages.sh upload 123456789 --content "Check this!" --file /path/to/image.png
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

validate_file_path() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file" >&2
        exit 1
    fi
    if [ ! -r "$file" ]; then
        echo "ERROR: File is not readable: $file" >&2
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

# --- get command ---
get_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: channel_id is required." >&2
        exit 1
    fi
    local channel_id="$1"
    validate_snowflake_id "$channel_id" "channel_id"
    shift

    local limit=50
    local before=""
    local after=""
    local around=""

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
            --around)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --around requires a value." >&2
                    exit 1
                fi
                around="$2"
                validate_snowflake_id "$around" "--around"
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
    [ -n "$around" ] && query="${query}&around=${around}"

    curl -s "https://discord.com/api/v10/channels/${channel_id}/messages?${query}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- send command ---
send_command() {
    if [ $# -lt 2 ]; then
        echo "ERROR: channel_id and content are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local content="$2"

    validate_snowflake_id "$channel_id" "channel_id"

    # Escape special characters for JSON
    content=$(escape_json_string "$content")

    curl -s -X POST "https://discord.com/api/v10/channels/${channel_id}/messages" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"${content}\"}"
}

# --- upload command ---
upload_command() {
    if [ $# -lt 1 ]; then
        echo "ERROR: channel_id is required." >&2
        exit 1
    fi
    local channel_id="$1"
    validate_snowflake_id "$channel_id" "channel_id"
    shift

    local content=""
    local files=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --content)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --content requires a value." >&2
                    exit 1
                fi
                content="$2"
                shift 2
                ;;
            --file)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --file requires a value." >&2
                    exit 1
                fi
                validate_file_path "$2"
                files+=("$2")
                shift 2
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    if [ ${#files[@]} -eq 0 ]; then
        echo "ERROR: At least one --file is required." >&2
        exit 1
    fi

    # Escape content for JSON
    content=$(escape_json_string "$content")

    # Build curl command with file arguments
    local curl_args=()
    curl_args+=(-s -X POST "https://discord.com/api/v10/channels/${channel_id}/messages")
    curl_args+=(-H "Authorization: Bot $DISCORD_BOT_TOKEN")
    curl_args+=(-H "User-Agent: DiscordBot (https://discord.com, 1.0)")
    curl_args+=(-F "payload_json={\"content\":\"${content}\"}")

    local i=0
    for file in "${files[@]}"; do
        curl_args+=(-F "files[${i}]=@${file}")
        ((i++))
    done

    curl "${curl_args[@]}"
}

# Execute subcommand
case "$SUBCOMMAND" in
    get)
        get_command "$@"
        ;;
    send)
        send_command "$@"
        ;;
    upload)
        upload_command "$@"
        ;;
    *)
        echo "ERROR: Unknown subcommand: $SUBCOMMAND" >&2
        show_usage
        exit 1
        ;;
esac
