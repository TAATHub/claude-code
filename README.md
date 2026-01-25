# Claude Code Extensions

A collection of plugins, skills, and subagents for Claude Code.

## Overview

This repository provides reusable components to enhance your Claude Code workflow:

- **Plugins** - Packaged extensions with skills and configurations
- **Skills** - Custom slash commands and workflows
- **Subagents** - Specialized agents for specific tasks

## Prerequisites

### Required Tools

- `curl` - for API requests
- `bash` - for running scripts

## Installation

### Add Marketplace
```bash
/plugin marketplace add TAATHub/claude-code
```

### Install Plugin
```bash
/plugin install discord-messaging@taat-marketplace
```

## Available Plugins

### [discord-messaging](plugins/discord-messaging/)
Discord REST API operations for messages, threads, and reactions. See [documentation](plugins/discord-messaging/README.md) for setup and usage.

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
