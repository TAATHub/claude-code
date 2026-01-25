# Thread Operations - Detailed Reference

Discord threads are treated as a type of channel. Thread IDs can be used the same way as channel IDs.

## How to Get Thread ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on a thread → "Copy ID"
3. Or retrieve from the Active Threads API

## Get Messages in Thread

Since threads are treated as channels, use the same message retrieval API.

```bash
# Get latest 50 messages in a thread
curl -s "https://discord.com/api/v10/channels/{thread_id}/messages?limit=50" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

## Get Thread Info

```bash
curl -s "https://discord.com/api/v10/channels/{thread_id}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

### Response Example

```json
{
  "id": "1234567890123456789",
  "type": 11,
  "name": "Thread name",
  "parent_id": "9876543210987654321",
  "owner_id": "1111111111111111111",
  "message_count": 42,
  "member_count": 5,
  "thread_metadata": {
    "archived": false,
    "auto_archive_duration": 1440,
    "archive_timestamp": "2024-01-15T10:30:00.000000+00:00",
    "locked": false
  }
}
```

**Field Descriptions:**
- `type`: 11=public thread, 12=private thread
- `parent_id`: Parent channel ID
- `message_count`: Number of messages in thread (approximate)
- `thread_metadata.archived`: Archive status
- `thread_metadata.locked`: Lock status

## Get Active Threads List

Retrieve active (non-archived) threads in a server.

**Note**: Channel-level API is deprecated; use the guild (server) level API instead.

```bash
curl -s "https://discord.com/api/v10/guilds/{guild_id}/threads/active" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

### Response Example

```json
{
  "threads": [
    {
      "id": "1234567890123456789",
      "type": 11,
      "name": "Active thread",
      "parent_id": "9876543210987654321",
      "message_count": 10,
      "thread_metadata": {
        "archived": false,
        "auto_archive_duration": 1440,
        "archive_timestamp": "2024-01-15T10:30:00.000000+00:00",
        "locked": false
      }
    }
  ],
  "members": [
    {
      "id": "1234567890123456789",
      "user_id": "1111111111111111111",
      "join_timestamp": "2024-01-15T10:30:00.000000+00:00"
    }
  ]
}
```

## Get Archived Threads List

Retrieve archived threads in a specific channel.

### Public Archived Threads

```bash
# Basic
curl -s "https://discord.com/api/v10/channels/{channel_id}/threads/archived/public" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"

# With parameters
curl -s "https://discord.com/api/v10/channels/{channel_id}/threads/archived/public?limit=10&before=2024-01-15T00:00:00.000000Z" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

### Private Archived Threads

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/threads/archived/private" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

**Parameters:**
- `limit`: Number of threads to retrieve (1-100, default: 50)
- `before`: ISO8601 timestamp. Retrieve threads archived before this time.

### Response Example

```json
{
  "threads": [
    {
      "id": "1234567890123456789",
      "type": 11,
      "name": "Archived thread",
      "parent_id": "9876543210987654321",
      "thread_metadata": {
        "archived": true,
        "auto_archive_duration": 1440,
        "archive_timestamp": "2024-01-15T10:30:00.000000+00:00",
        "locked": false
      }
    }
  ],
  "members": [],
  "has_more": false
}
```

**Field Descriptions:**
- `has_more`: `true` if more threads exist (for pagination)

## Send Message to Thread

Use the same API as sending regular messages.

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{thread_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Type: application/json" \
  -d '{"content": "Message to thread"}'
```
