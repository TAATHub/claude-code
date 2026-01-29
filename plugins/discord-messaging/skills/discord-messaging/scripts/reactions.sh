#!/bin/bash
set -euo pipefail

# Discord API - Reaction Operations
# Usage:
#   ./reactions.sh add <channel_id> <message_id> <emoji>
#   ./reactions.sh remove <channel_id> <message_id> <emoji>
#   ./reactions.sh remove-user <channel_id> <message_id> <emoji> <user_id>
#   ./reactions.sh remove-all <channel_id> <message_id>
#   ./reactions.sh remove-emoji <channel_id> <message_id> <emoji>
#   ./reactions.sh list <channel_id> <message_id> <emoji> [--limit <n>] [--after <id>]

show_usage() {
    cat << 'EOF'
Usage: reactions.sh <subcommand> [options]

Subcommands:
  add          Add a reaction to a message
  remove       Remove own reaction from a message
  remove-user  Remove another user's reaction
  remove-all   Remove all reactions from a message
  remove-emoji Remove all reactions of a specific emoji
  list         Get users who reacted with a specific emoji

add <channel_id> <message_id> <emoji>
  Add a reaction. Emoji must be URL-encoded for Unicode (e.g., %E2%9C%85 for checkmark)
  or name:id format for custom emoji.

remove <channel_id> <message_id> <emoji>
  Remove your own reaction.

remove-user <channel_id> <message_id> <emoji> <user_id>
  Remove another user's reaction. Requires MANAGE_MESSAGES permission.

remove-all <channel_id> <message_id>
  Remove all reactions from a message. Requires MANAGE_MESSAGES permission.

remove-emoji <channel_id> <message_id> <emoji>
  Remove all reactions of a specific emoji. Requires MANAGE_MESSAGES permission.

list <channel_id> <message_id> <emoji> [options]
  --limit <n>    Number of users (1-100, default: 25)
  --after <id>   Get users after this user ID

Common Emoji Encodings:
  checkmark  %E2%9C%85
  thumbsup   %F0%9F%91%8D
  heart      %E2%9D%A4%EF%B8%8F

Examples:
  reactions.sh add 123456789 987654321 "%E2%9C%85"
  reactions.sh add 123456789 987654321 "custom_emoji:111222333"
  reactions.sh remove 123456789 987654321 "%E2%9C%85"
  reactions.sh list 123456789 987654321 "%E2%9C%85" --limit 50
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

validate_emoji() {
    local emoji="$1"
    # URL-encoded emoji (e.g., %E2%9C%85) or custom emoji (e.g., name:id)
    if ! [[ "$emoji" =~ ^(%[0-9A-Fa-f]{2})+$ ]] && ! [[ "$emoji" =~ ^[a-zA-Z0-9_]+:[0-9]+$ ]]; then
        echo "ERROR: emoji must be URL-encoded (e.g., %E2%9C%85) or in name:id format." >&2
        exit 1
    fi
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

# --- add command ---
add_command() {
    if [ $# -lt 3 ]; then
        echo "ERROR: channel_id, message_id, and emoji are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"
    local emoji="$3"

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"
    validate_emoji "$emoji"

    curl -s -X PUT "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions/${emoji}/@me" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
        -H "Content-Length: 0"
}

# --- remove command ---
remove_command() {
    if [ $# -lt 3 ]; then
        echo "ERROR: channel_id, message_id, and emoji are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"
    local emoji="$3"

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"
    validate_emoji "$emoji"

    curl -s -X DELETE "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions/${emoji}/@me" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- remove-user command ---
remove_user_command() {
    if [ $# -lt 4 ]; then
        echo "ERROR: channel_id, message_id, emoji, and user_id are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"
    local emoji="$3"
    local user_id="$4"

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"
    validate_emoji "$emoji"
    validate_snowflake_id "$user_id" "user_id"

    curl -s -X DELETE "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions/${emoji}/${user_id}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- remove-all command ---
remove_all_command() {
    if [ $# -lt 2 ]; then
        echo "ERROR: channel_id and message_id are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"

    curl -s -X DELETE "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- remove-emoji command ---
remove_emoji_command() {
    if [ $# -lt 3 ]; then
        echo "ERROR: channel_id, message_id, and emoji are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"
    local emoji="$3"

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"
    validate_emoji "$emoji"

    curl -s -X DELETE "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions/${emoji}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# --- list command ---
list_command() {
    if [ $# -lt 3 ]; then
        echo "ERROR: channel_id, message_id, and emoji are required." >&2
        exit 1
    fi
    local channel_id="$1"
    local message_id="$2"
    local emoji="$3"
    shift 3

    validate_snowflake_id "$channel_id" "channel_id"
    validate_snowflake_id "$message_id" "message_id"
    validate_emoji "$emoji"

    local limit=25
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
    [ -n "$after" ] && query="${query}&after=${after}"

    curl -s "https://discord.com/api/v10/channels/${channel_id}/messages/${message_id}/reactions/${emoji}?${query}" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
}

# Execute subcommand
case "$SUBCOMMAND" in
    add)
        add_command "$@"
        ;;
    remove)
        remove_command "$@"
        ;;
    remove-user)
        remove_user_command "$@"
        ;;
    remove-all)
        remove_all_command "$@"
        ;;
    remove-emoji)
        remove_emoji_command "$@"
        ;;
    list)
        list_command "$@"
        ;;
    *)
        echo "ERROR: Unknown subcommand: $SUBCOMMAND" >&2
        show_usage
        exit 1
        ;;
esac
