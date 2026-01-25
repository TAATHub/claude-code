# Claude Code Extensions

A collection of plugins, skills, and subagents for Claude Code.

## Overview

This repository provides reusable components to enhance your Claude Code workflow:

- **Plugins** - Packaged extensions with skills and configurations
- **Skills** - Custom slash commands and workflows
- **Subagents** - Specialized agents for specific tasks

## Prerequisites

### Discord Bot Token

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application or select existing one
3. Navigate to "Bot" section and copy the token
4. Set the token as environment variable:

```bash
# Local execution
export DISCORD_BOT_TOKEN="your-bot-token-here"

# GitHub Actions (add to repository secrets)
# Settings > Secrets and variables > Actions > New repository secret
# Name: DISCORD_BOT_TOKEN
```

### Required Tools

- `curl` - for API requests
- `bash` - for running scripts

## Installation

### Add Marketplace
```bash
/plugin marketplace add taat/claude-code
```

### Install Plugin
```bash
/plugin install discord-messaging@taat-claude-plugins
```

## Available Plugins

### discord-messaging
Discord REST API operations for messages, threads, and reactions.

## Directory Structure

```
claude-code/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
├── plugins/
│   └── discord-messaging/  # Discord messaging plugin
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
└── LICENSE
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
