# Reaction Operations - Reference

## Script Usage

```bash
# Add reaction
scripts/reactions.sh add <channel_id> <message_id> <emoji>

# Remove own reaction
scripts/reactions.sh remove <channel_id> <message_id> <emoji>

# Remove another user's reaction (requires MANAGE_MESSAGES)
scripts/reactions.sh remove-user <channel_id> <message_id> <emoji> <user_id>

# Remove all reactions (requires MANAGE_MESSAGES)
scripts/reactions.sh remove-all <channel_id> <message_id>

# Remove all reactions of specific emoji (requires MANAGE_MESSAGES)
scripts/reactions.sh remove-emoji <channel_id> <message_id> <emoji>

# List users who reacted
scripts/reactions.sh list <channel_id> <message_id> <emoji> [--limit <n>] [--after <id>]
```

## Emoji Format

### Unicode Emoji (URL Encoded)

Unicode emojis must be URL-encoded:

| Emoji | Name | URL Encoded |
|-------|------|-------------|
| ✅ | white_check_mark | `%E2%9C%85` |
| 👍 | thumbsup | `%F0%9F%91%8D` |
| 👎 | thumbsdown | `%F0%9F%91%8E` |
| ❤️ | heart | `%E2%9D%A4%EF%B8%8F` |
| 🎉 | tada | `%F0%9F%8E%89` |
| 👀 | eyes | `%F0%9F%91%80` |
| 🔥 | fire | `%F0%9F%94%A5` |
| ⭐ | star | `%E2%AD%90` |

### Custom Emoji

Custom emojis use `name:id` format:

```bash
scripts/reactions.sh add <channel_id> <message_id> "custom_emoji:123456789"
```

To find custom emoji ID:
1. Type `\:emoji_name:` in Discord chat
2. The ID will be shown in the format `<:name:id>`

## Query Parameters (list)

| Parameter | Type | Description |
|-----------|------|-------------|
| `--limit` | integer | Max users to return (1-100, default 25) |
| `--after` | snowflake | Get users after this user ID |

## Response

### Add/Remove Reactions

Returns 204 No Content on success (no response body).

### List Reactions

Returns array of user objects:

```json
[
  {
    "id": "123456789",
    "username": "user1",
    "discriminator": "0",
    "avatar": "abc123..."
  },
  {
    "id": "987654321",
    "username": "user2",
    "discriminator": "0",
    "avatar": "def456..."
  }
]
```

## Permissions

| Operation | Required Permission |
|-----------|---------------------|
| Add own reaction | None (bot must have access) |
| Remove own reaction | None |
| Remove others' reactions | `MANAGE_MESSAGES` |
| Remove all reactions | `MANAGE_MESSAGES` |
