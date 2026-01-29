---
name: discord-messaging
description: Message and thread operations using Discord REST API. Supports message retrieval (with limit, date, date range, attachment URL extraction), message sending (text, image files), and thread operations (list threads, get thread messages). Use for requests like "get Discord messages", "send a message to Discord", "list threads", "get messages in a thread".
argument-hint: [channel_id]
allowed-tools:
  - Bash(*messages.sh*)
  - Bash(*reactions.sh*)
  - Bash(*threads.sh*)
  - Bash(*date-to-snowflake.sh*)
  - Bash(curl*discord.com/api*)
---

# Discord API

Retrieve and send messages using the Discord REST API.

## Get Messages

```bash
# Get latest 50 messages
scripts/messages.sh get <channel_id>

# With options
scripts/messages.sh get <channel_id> --limit 20
scripts/messages.sh get <channel_id> --after <snowflake_id> --limit 100
```

For response format and error handling, see [references/messages.md](references/messages.md).

## Send Messages

```bash
# Text message
scripts/messages.sh send <channel_id> "Message content"

# With file attachment
scripts/messages.sh upload <channel_id> --file /path/to/image.png

# Text and file
scripts/messages.sh upload <channel_id> --content "Check this!" --file /path/to/image.png

# Multiple files
scripts/messages.sh upload <channel_id> --content "Multiple files" --file /path/to/a.png --file /path/to/b.jpg
```

## Add Reactions

```bash
# Add checkmark reaction
scripts/reactions.sh add <channel_id> <message_id> "%E2%9C%85"

# Add custom emoji
scripts/reactions.sh add <channel_id> <message_id> "custom_emoji:111222333"

# Remove own reaction
scripts/reactions.sh remove <channel_id> <message_id> "%E2%9C%85"

# List users who reacted
scripts/reactions.sh list <channel_id> <message_id> "%E2%9C%85" --limit 50
```

For emoji encoding reference, see [references/reactions.md](references/reactions.md).

## Thread Operations

```bash
# Get thread info
scripts/threads.sh info <thread_id>

# Get messages in thread
scripts/threads.sh messages <thread_id> --limit 50

# List active threads in guild
scripts/threads.sh active <guild_id>

# List archived threads in channel
scripts/threads.sh archived <channel_id> --type public --limit 20

# Send message to thread
scripts/threads.sh send <thread_id> "Hello thread!"
```

For details, see [references/threads.md](references/threads.md).

## Snowflake ID Conversion

For date-based filtering, convert dates to Snowflake IDs:

```bash
# Today at 00:00:00 UTC
scripts/date-to-snowflake.sh

# Specific date at 00:00:00 UTC
scripts/date-to-snowflake.sh 2024-01-15

# Specific date at 00:00:00 JST
scripts/date-to-snowflake.sh 2024-01-15 JST
```

### Example: Get messages for a specific date (JST)

```bash
# Get messages from 2024-01-15 JST
AFTER_ID=$(scripts/date-to-snowflake.sh 2024-01-15 JST)
BEFORE_ID=$(scripts/date-to-snowflake.sh 2024-01-16 JST)
scripts/messages.sh get <channel_id> --after $AFTER_ID --before $BEFORE_ID --limit 100
```

## How to Get Channel ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on a channel → "Copy ID"

## How to Get Guild ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on the server name → "Copy ID"
