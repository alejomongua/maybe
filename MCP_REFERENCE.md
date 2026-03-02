# MCP Server Quick Reference Card

## Setup Checklist

- [ ] Install Python 3.10+
- [ ] Install dependencies: `pip install -r mcp_requirements.txt`
- [ ] Start Maybe Finance (Docker: `docker-compose up -d` or local: `bin/dev`)
- [ ] Generate API key: Settings → API Key → Create with `read_write` scope
- [ ] Set environment: `export MAYBE_API_KEY="your_key"`
- [ ] Set URL: `export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"`
- [ ] Validate: `python test_mcp_setup.py`
- [ ] Configure Claude Desktop (see config below)
- [ ] Restart Claude Desktop

## Claude Desktop Configuration

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "maybe-finance": {
      "command": "python3",
      "args": ["/ABSOLUTE/PATH/TO/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "your_api_key_here",
        "MAYBE_API_BASE_URL": "http://localhost:3000/api/v1"
      }
    }
  }
}
```

**Replace** `/ABSOLUTE/PATH/TO/maybe/` with your actual path!

## Common Commands

| Task | Example Command |
|------|----------------|
| View accounts | "Show me my accounts" |
| Recent transactions | "Show my last 10 transactions" |
| Create transaction | "I spent $50 on groceries from checking yesterday" |
| Filter by category | "Show all grocery transactions this month" |
| Filter by amount | "Show transactions over $100" |
| Update transaction | "Change the coffee transaction to $5.50" |
| Delete transaction | "Delete the duplicate transaction from yesterday" |
| Monthly spending | "How much did I spend this month?" |
| Category breakdown | "Show spending by category for January" |

## Transaction Parameters

| Parameter | Required | Example |
|-----------|----------|---------|
| account_id | ✅ | Use account name, Claude finds ID |
| amount | ✅ | Positive number: 50.00 |
| date | ✅ | YYYY-MM-DD or "yesterday", "last week" |
| name | ✅ | "Grocery shopping" |
| category | Optional | Category name or ID |
| merchant | Optional | Merchant name or ID |
| tags | Optional | Tag names or IDs |
| nature | Optional | "income" or "expense" |

## Docker Deployment

**MCP runs OUTSIDE container** on your local machine.

Container requirements:
```yaml
# docker-compose.yml
services:
  web:
    ports:
      - "3000:3000"  # MUST be exposed
```

MCP connects to: `http://localhost:3000/api/v1`

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Cannot connect to localhost:3000" | Start Maybe: `docker-compose up -d` |
| "API Error 401" | Invalid API key - regenerate from Settings |
| "API Error 403" | Wrong scope - use `read_write` scope |
| "API Error 422" | Invalid parameters - check account exists, date format |
| "MCP server not loading" | Check Python version (3.10+), absolute path in config |
| "Rate limit exceeded" | Wait and retry, or upgrade API tier |

## API Scopes

| Scope | Permissions |
|-------|-------------|
| `read` | View accounts, transactions, categories |
| `read_write` | Full access: create, update, delete |

## Testing Commands

```bash
# Validate setup
python test_mcp_setup.py

# Test API connection manually
curl http://localhost:3000/api/v1/accounts \
  -H "X-Api-Key: your_key"

# Run automated setup
./setup_mcp.sh
```

## Security Best Practices

- ✅ Never commit API keys to git
- ✅ Use environment variables
- ✅ Rotate keys periodically
- ✅ Use minimal required scope
- ✅ Revoke unused keys
- ❌ Don't share keys publicly
- ❌ Don't hardcode in scripts

## File Locations

| File | Purpose |
|------|---------|
| `mcp_server.py` | MCP server implementation |
| `mcp_requirements.txt` | Python dependencies |
| `test_mcp_setup.py` | Validation script |
| `setup_mcp.sh` | Automated setup |
| `MCP_README.md` | Full documentation |
| `MCP_QUICKSTART.md` | Usage examples |
| `MCP_ARCHITECTURE.md` | Architecture details |

## Quick Workflow

1. **Start Maybe**: `docker-compose up -d` or `bin/dev`
2. **Set environment**: Export API key and URL
3. **Validate**: `python test_mcp_setup.py`
4. **Use Claude**: "Show my accounts"
5. **Create transaction**: "I spent $X on Y from Z account"

## Advanced Filters

```bash
# Date range
"Show transactions from January 1st to January 31st"

# Multiple filters
"Show grocery transactions over $50 from checking account this month"

# Search
"Find transactions with 'coffee' in the name"

# Type filter
"Show all income transactions"

# Combined
"Show dining out expenses over $20 from credit card last month"
```

## Getting Help

1. Run validation: `python test_mcp_setup.py`
2. Check logs: Maybe logs in Docker or Rails logs
3. Review docs: `MCP_README.md`, `MCP_QUICKSTART.md`
4. Architecture: `MCP_ARCHITECTURE.md`
5. GitHub Issues: Report bugs or feature requests

## Version Compatibility

- Python: 3.10 or higher
- MCP SDK: >= 1.0.0
- httpx: >= 0.25.0
- Maybe API: v1

---

**Pro tip**: Claude can figure out most details from context. Just describe what you want naturally: "I bought coffee for $4.50 this morning" and it will find the right account, date, and create the transaction!