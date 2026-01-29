# Thread Operations - Reference

Discord threads are treated as a type of channel. Thread IDs can be used the same way as channel IDs.

## Script Usage

```bash
# Get thread information
scripts/threads.sh info <thread_id>

# Get messages in thread
scripts/threads.sh messages <thread_id> [--limit <n>] [--before <id>] [--after <id>]

# List active threads in guild
scripts/threads.sh active <guild_id>

# List archived threads in channel
scripts/threads.sh archived <channel_id> [--type <public|private>] [--limit <n>] [--before <timestamp>]

# Send message to thread
scripts/threads.sh send <thread_id> <content>
```

## How to Get Thread ID

1. Discord Settings → Advanced → Enable Developer Mode
2. Right-click on a thread → "Copy ID"
3. Or retrieve from the Active Threads API

## Query Parameters

### messages

| Parameter | Type | Description |
|-----------|------|-------------|
| `--limit` | integer | Max messages (1-100, default 50) |
| `--before` | snowflake | Get messages before this ID |
| `--after` | snowflake | Get messages after this ID |

### archived

| Parameter | Type | Description |
|-----------|------|-------------|
| `--type` | string | `public` or `private` (default: public) |
| `--limit` | integer | Max threads (1-100, default 50) |
| `--before` | timestamp | ISO8601 timestamp for pagination |

## Response Examples

### Thread Info

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

### Active Threads

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

### Archived Threads

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

## Notes

- **Active threads API**: Use guild ID, not channel ID
- **Archived threads API**: Use channel ID, supports both public and private types
- **Pagination**: Use `--before` with the `archive_timestamp` from the last thread
