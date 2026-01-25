# Message Operations - Detailed Reference

## Get Messages

### Basic Usage

```bash
# Get latest 50 messages
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=50" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"

# Specify count (1-100)
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=20" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

### Date Filtering (before/after)

Discord API requires dates to be converted to Snowflake IDs.

**Snowflake ID Conversion Script**: `scripts/date-to-snowflake.sh`

```bash
# Get Snowflake ID for today at 00:00:00 UTC
scripts/date-to-snowflake.sh

# Get Snowflake ID for a specific date at 00:00:00 UTC
scripts/date-to-snowflake.sh 2024-01-15

# Get Snowflake ID for a specific date at 00:00:00 JST (= previous day 15:00:00 UTC)
scripts/date-to-snowflake.sh 2024-01-15 JST
```

#### Get Messages for a Specific Date (JST) Using Date Range

Example: Get messages from 2024-01-15 JST 0:00 - 23:59

- AFTER_ID: scripts/date-to-snowflake.sh 2024-01-15 JST
- BEFORE_ID: scripts/date-to-snowflake.sh 2024-01-16 JST

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=100&after=$AFTER_ID&before=$BEFORE_ID" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

#### Get Messages Before a Specific Date

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=50&before={snowflake_id}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

#### Get Messages After a Specific Date

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages?limit=50&after={snowflake_id}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)"
```

### Response Example

```json
[
  {
    "id": "123456789",
    "timestamp": "2024-01-15T10:30:00.000000+00:00",
    "author": {"username": "username", "id": "..."},
    "content": "Check this image!",
    "attachments": [
      {
        "url": "https://cdn.discordapp.com/attachments/...",
        "filename": "image.png",
        "content_type": "image/png",
        "size": 12345
      }
    ],
    "thread": {
      "id": "1234567890123456789",
      "name": "Thread name",
      "type": 11,
      "message_count": 10,
      "member_count": 3
    }
  }
]
```

**Field Descriptions:**
- `attachments`: Attachment information (images, videos, etc.)
- `thread`: Only present if a thread was created from this message. Contains basic thread information.

## Send Messages

### Send Text Message

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{channel_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Type: application/json" \
  -d '{"content": "Message content"}'
```

### Send Image

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{channel_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -F 'payload_json={"content":""}' \
  -F "files[0]=@/path/to/image.png"
```

### Send Text and Image Together

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{channel_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -F 'payload_json={"content":"Message content"}' \
  -F "files[0]=@/path/to/image.png"
```

### Send Multiple Images

```bash
curl -s -X POST "https://discord.com/api/v10/channels/{channel_id}/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -F 'payload_json={"content":"Message content"}' \
  -F "files[0]=@/path/to/image1.png" \
  -F "files[1]=@/path/to/image2.jpg"
```
