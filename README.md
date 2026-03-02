
<img width="1190" alt="sure_hero" src="https://github.com/user-attachments/assets/959f6e9f-2d8a-4f8c-893e-cd3e6eeb4ff2" />

<p align="center">
  <!-- Keep these links. Translations will automatically update with the README. -->
  <a href="https://readme-i18n.com/de/we-promise/sure">Deutsch</a> | 
  <a href="https://readme-i18n.com/es/we-promise/sure">Español</a> | 
  <a href="https://readme-i18n.com/fr/we-promise/sure">Français</a> | 
  <a href="https://readme-i18n.com/ja/we-promise/sure">日本語</a> | 
  <a href="https://readme-i18n.com/ko/we-promise/sure">한국어</a> | 
  <a href="https://readme-i18n.com/pt/we-promise/sure">Português</a> | 
  <a href="https://readme-i18n.com/ru/we-promise/sure">Русский</a> | 
  <a href="https://readme-i18n.com/zh/we-promise/sure">中文</a>
</p>

# ~Maybe~Sure: The personal finance app for everyone

<b>Get
involved: [Discord](https://discord.gg/36ZGBsxYEK) • [(archived) Website](https://web.archive.org/web/20250715182050/https://maybefinance.com/) • [Issues](https://github.com/we-promise/sure/issues)</b>

> [!IMPORTANT]
> This repository is a community fork of the now-abandoned Maybe Finance project. 
> Learn more in their [final release](https://github.com/maybe-finance/maybe/releases/tag/v0.6.0) doc.

## Backstory

The Maybe Finance team spent most of 2021–2022 building a full-featured personal finance and wealth management app. It even included an “Ask an Advisor” feature that connected users with a real CFP/CFA — all included with your subscription.

The business end of things didn't work out, and so they stopped developing the app in mid-2023.

After spending nearly $1 million on development (employees, contractors, data providers, infra, etc.), the team open-sourced the app. Their goal was to let users self-host it for free — and eventually launch a hosted version for a small fee.

They actually did launch that hosted version … briefly.

That also didn’t work out — at least not as a sustainable B2C business — so now here we are: hosting a community-maintained fork to keep the codebase alive and see where this can go next.

Join us!

## Hosting ~Maybe~Sure

Sure is a fully working personal finance app that can be [self hosted with Docker](docs/hosting/docker.md).

## MCP Integration (AI Assistants)

Sure includes support for **MCP (Model Context Protocol)**, enabling AI assistants like Claude Desktop to interact with your financial data programmatically.

### Quick Start

```bash
# Install dependencies
pip install -r mcp_requirements.txt

# Generate API key from Settings → API Key in the web UI
# Configure environment
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"  # or your instance URL

# Validate setup
python test_mcp_setup.py
```

### Usage with Claude Desktop

Once configured, you can use natural language commands like:
- "Show me my accounts and balances"
- "Create a transaction for $50 groceries from my checking account"
- "How much did I spend on dining out this month?"
- "List all transactions over $100 from last week"

### Documentation

- **[MCP_README.md](MCP_README.md)** - Installation and configuration guide
- **[MCP_QUICKSTART.md](MCP_QUICKSTART.md)** - Quick reference with examples
- **[MCP_ARCHITECTURE.md](MCP_ARCHITECTURE.md)** - Architecture and deployment guide

**Note:** The MCP server runs **outside the container** on your local machine and communicates with the Sure API via HTTP. See the architecture documentation for details.

## Forking and Attribution

This repo is a community fork of the archived Maybe Finance repo.
You’re free to fork it under the AGPLv3 license — but we’d love it if you stuck around and contributed here instead.

To stay compliant and avoid trademark issues:

- Be sure to include the original [AGPLv3 license](https://github.com/maybe-finance/maybe/blob/main/LICENSE) and clearly state in your README that your fork is based on Maybe Finance but is **not affiliated with or endorsed by** Maybe Finance Inc.
- "Maybe" is a trademark of Maybe Finance Inc. and therefore, use of it is NOT allowed in forked repositories (or the logo)

## Local Development Setup

**If you are trying to _self-host_ the app, [read this guide to get started](docs/hosting/docker.md).**

The instructions below are for developers to get started with contributing to the app.

### Requirements

- See `.ruby-version` file for required Ruby version
- PostgreSQL >9.3 (latest stable version recommended)

### Getting Started
```sh
cd sure
cp .env.local.example .env.local
bin/setup
bin/dev

# Optionally, load demo data
rake demo_data:default
```

Visit http://localhost:3000 to view the app. You can log in with these demo credentials (from the DB seed):

- Email: `user@sure.local`
- Password: `password`

For further instructions, see guides below.

### Setup Guides

- [Mac dev setup](https://github.com/we-promise/sure/wiki/Mac-Dev-Setup-Guide)
- [Linux dev setup](https://github.com/we-promise/sure/wiki/Linux-Dev-Setup-Guide)
- [Windows dev setup](https://github.com/we-promise/sure/wiki/Windows-Dev-Setup-Guide)
- Dev containers - visit [this guide](https://code.visualstudio.com/docs/devcontainers/containers)

## MCP Integration for AI Assistants

Sure includes an MCP (Model Context Protocol) server that enables AI assistants like Claude Desktop to interact with your financial data programmatically.

### Quick Setup

```bash
# Install dependencies
pip install -r mcp_requirements.txt

# Set environment variables
export MAYBE_API_KEY="your_api_key_here"  # Get from Settings → API Key
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"  # Adjust for your instance

# Validate setup
python test_mcp_setup.py

# Run automated setup
./setup_mcp.sh
```

### Usage with Claude Desktop

Once configured, you can use natural language commands:

- "Show me my accounts and balances"
- "I spent $50 on groceries from my checking account yesterday"
- "How much did I spend on dining out this month?"
- "Show transactions over $100 from my credit card"

### Documentation

- **[MCP_README.md](MCP_README.md)** - Full installation and configuration guide
- **[MCP_QUICKSTART.md](MCP_QUICKSTART.md)** - Quick reference for common commands
- **[MCP_ARCHITECTURE.md](MCP_ARCHITECTURE.md)** - Deployment architecture and container setup
- **[docs/mcp_integration.md](docs/mcp_integration.md)** - Integration documentation

**Note:** The MCP server runs outside the container on your local machine and communicates with the Sure API via HTTP. See [MCP_ARCHITECTURE.md](MCP_ARCHITECTURE.md) for details.

## License and Trademarks

Maybe and Sure are both distributed under
an [AGPLv3 license](https://github.com/we-promise/sure/blob/main/LICENSE).
- "Maybe" is a trademark of Maybe Finance, Inc.
- "Sure" is not, and refers to this community fork.
