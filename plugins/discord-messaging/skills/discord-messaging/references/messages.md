# Message Operations - Reference

## Script Usage

```bash
# Get messages
scripts/messages.sh get <channel_id> [--limit <n>] [--before <id>] [--after <id>] [--around <id>]

# Send text message
scripts/messages.sh send <channel_id> <content>
scripts/messages.sh send <channel_id> --json '{"content": "text"}' # (recommended for automation)

# Send with file attachments
scripts/messages.sh upload <channel_id> [--content <text>] --file <path> [--file <path>...]
```

## Query Parameters (get)

| Parameter | Type | Description |
|-----------|------|-------------|
| `--limit` | integer | Max messages to return (1-100, default 50) |
| `--before` | snowflake | Get messages before this message ID |
| `--after` | snowflake | Get messages after this message ID |
| `--around` | snowflake | Get messages around this message ID |

## Date Filtering

Discord API requires dates to be converted to Snowflake IDs. Use `scripts/date-to-snowflake.sh`:

```bash
# Get Snowflake ID for today at 00:00:00 UTC
scripts/date-to-snowflake.sh

# Get Snowflake ID for a specific date at 00:00:00 JST
scripts/date-to-snowflake.sh 2024-01-15 JST
```

### Example: Get messages for a specific date (JST)

```bash
# Get messages from 2024-01-15 JST 0:00 - 23:59
AFTER_ID=$(scripts/date-to-snowflake.sh 2024-01-15 JST)
BEFORE_ID=$(scripts/date-to-snowflake.sh 2024-01-16 JST)
scripts/messages.sh get <channel_id> --after $AFTER_ID --before $BEFORE_ID --limit 100
```

## Response Example

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
- `thread`: Only present if a thread was created from this message

## Error Responses

### 401 Unauthorized

Missing or invalid authentication token.

```json
{
  "message": "401: Unauthorized",
  "code": 0
}
```

**Solution:** Verify that `$DISCORD_BOT_TOKEN` is set correctly.

### 403 Forbidden

Bot lacks required permissions for the channel.

```json
{
  "message": "Missing Access",
  "code": 50001
}
```

**Solution:** Ensure the bot has `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY` permissions.

### 404 Not Found

Channel or message does not exist.

```json
{
  "message": "Unknown Channel",
  "code": 10003
}
```

**Solution:** Verify the channel ID is correct and the bot has access.

### 429 Too Many Requests

Rate limit exceeded.

```json
{
  "message": "You are being rate limited.",
  "retry_after": 1.5,
  "global": false
}
```

**Solution:** Wait for `retry_after` seconds before retrying.
