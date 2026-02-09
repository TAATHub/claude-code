# discord-messaging

Discord REST API operations for messages, threads, and reactions.

## Features

- **Messages**: Retrieve messages (with limit, date filtering, attachment extraction), send text/images, delete messages
- **Threads**: List active/archived threads, get thread messages
- **Reactions**: Add/remove emoji reactions (Unicode and custom)

## Prerequisites

### Discord Bot Token

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application or select existing one
3. Navigate to "Bot" section and copy the token
4. Set the token as environment variable:

- **Local**: Set `DISCORD_BOT_TOKEN` in `.claude/settings.local.json` `env`
- **Claude Code Action**: Add `DISCORD_BOT_TOKEN` to repository secrets (Settings > Secrets and variables > Actions > New repository secret), then set in `settings` `env`

### Required Bot Permissions

- `VIEW_CHANNEL` - View channels
- `READ_MESSAGE_HISTORY` - Read message history
- `SEND_MESSAGES` - Send messages (if sending)
- `ADD_REACTIONS` - Add reactions (if using reactions)
- `MANAGE_MESSAGES` - Remove others' reactions, delete others' messages (optional)

## Quick Start

### Prompt Examples

```
# Get messages
Get the latest 50 messages from Discord channel (ID: 123456789)

# Get messages with date filter
Get messages from Discord channel (ID: 123456789) on January 15, 2024

# Send message
Send "Hello, Discord!" to Discord channel (ID: 123456789)

# Delete message
Delete Discord message (Channel ID: 123456789, Message ID: 987654321)

# Add reaction
Add ✅ reaction to Discord message (Channel ID: 123456789, Message ID: 987654321)

# List threads
Get active threads from Discord server (ID: 111222333)

# Get thread messages
Get messages from Discord thread (ID: 444555666)
```

## How to Get IDs

### Channel ID

1. Discord Settings > Advanced > Enable Developer Mode
2. Right-click on a channel > "Copy ID"

### Guild (Server) ID

1. Discord Settings > Advanced > Enable Developer Mode
2. Right-click on the server name > "Copy ID"

### Thread ID

1. Discord Settings > Advanced > Enable Developer Mode
2. Right-click on a thread > "Copy ID"

## Detailed Documentation

- [Message Operations](skills/discord-messaging/references/messages.md) - Date filtering, sending images, error handling
- [Reaction Operations](skills/discord-messaging/references/reactions.md) - Custom emojis, removing reactions
- [Thread Operations](skills/discord-messaging/references/threads.md) - Active/archived threads, thread info
