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
