# Reaction Operations - Detailed Reference

## Add Unicode Emoji

```bash
# Add ✅ (white_check_mark)
curl -s -X PUT "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/%E2%9C%85/@me" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Length: 0"

# Add 👍 (thumbsup)
curl -s -X PUT "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/%F0%9F%91%8D/@me" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Length: 0"
```

**Note**: Unicode emojis require URL encoding
- ✅ → `%E2%9C%85`
- 👍 → `%F0%9F%91%8D`

## Add Custom Emoji

```bash
curl -s -X PUT "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/{emoji_name}:{emoji_id}/@me" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "User-Agent: DiscordBot (https://discord.com, 1.0)" \
  -H "Content-Length: 0"
```

## Response

Returns 204 No Content on success (no response body)

## Remove Reaction

### Remove Own Reaction

```bash
curl -X DELETE "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/{emoji}/@me" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN"
```

### Remove User's Reaction

```bash
curl -X DELETE "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/{emoji}/{user_id}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN"
```

**Note:** Requires `MANAGE_MESSAGES` permission to remove other users' reactions.

### Remove All Reactions

```bash
curl -X DELETE "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN"
```

### Remove All Reactions for Emoji

```bash
curl -X DELETE "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/{emoji}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN"
```

## Get Reactions

Get list of users who reacted with a specific emoji.

```bash
curl -s "https://discord.com/api/v10/channels/{channel_id}/messages/{message_id}/reactions/{emoji}" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN"
```

### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `after` | snowflake | Get users after this user ID |
| `limit` | integer | Max users to return (1-100, default 25) |
