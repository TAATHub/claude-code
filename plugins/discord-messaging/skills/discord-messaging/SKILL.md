---
name: discord-messaging
description: Message and thread operations using Discord REST API. Supports message retrieval (with limit, date, date range, attachment URL extraction), message sending (text, image files), and thread operations (list threads, get thread messages). Use for requests like "get Discord messages", "send a message to Discord", "list threads", "get messages in a thread".
allowed-tools:
  - Bash(curl*discord.com/api*)
  - Bash(*date-to-snowflake.sh*)
---

# Discord API

Retrieve and send messages using the Discord REST API.

## Get Messages

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=50" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

For details (date filtering, response examples, etc.), see [references/messages.md](references/messages.md).

## Send Messages

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{channel_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"Message content\"}"
```

For details (sending images, etc.), see [references/messages.md](references/messages.md).

## Add Reactions

```bash
# Add ✅
curl -s -X PUT "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/%E2%9C%85/@me" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Length: 0"
```

For details (custom emojis, etc.), see [references/reactions.md](references/reactions.md).

## Thread Operations

Threads are treated as channels, so use the thread ID instead of the channel ID.

```bash
# Get messages in a thread
curl -s "https://discord.com/api/v10/channels/{thread_id}/messages?limit=50" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

For details (listing threads, archived threads, etc.), see [references/threads.md](references/threads.md).

## How to Get Channel ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on a channel → "Copy ID"

## How to Get Guild ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on the server name → "Copy ID"
