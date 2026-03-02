# MCP (Model Context Protocol) Integration

Maybe Finance supports MCP (Model Context Protocol) for integrating with LLM-based agents like Claude Desktop. This enables AI assistants to interact with your financial data programmatically.

## What is MCP?

MCP is an open protocol that enables AI assistants to interact with external systems through a standardized interface. With the Maybe MCP server, you can:

- Create, read, update, and delete transactions
- View accounts and balances
- Browse categories, tags, and merchants
- Query transactions with advanced filters
- Integrate financial management into AI workflows

## Quick Start

### 1. Generate an API Key

1. Log in to your Maybe Finance instance
2. Navigate to **Settings** → **API Key**
3. Click **Create New API Key**
4. Give it a name (e.g., "MCP Server" or "Claude Desktop")
5. Select scopes:
   - **`read`**: For viewing data only
   - **`read_write`**: For creating, updating, and deleting data (recommended)
6. Copy the generated API key

### 2. Install Dependencies

```bash
cd /path/to/maybe
pip install -r mcp_requirements.txt
```

### 3. Set Environment Variables

```bash
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"  # Adjust for your instance
```

For production instances:

```bash
export MAYBE_API_BASE_URL="https://your-maybe-instance.com/api/v1"
```

### 4. Validate Setup

Run the validation script:

```bash
python test_mcp_setup.py
```

### 5. Configure Claude Desktop

Add the MCP server to your Claude Desktop configuration:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

**Linux**: `~/.config/claude/claude_desktop_config.json`

**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "maybe-finance": {
      "command": "python3",
      "args": ["/path/to/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "your_api_key_here",
        "MAYBE_API_BASE_URL": "http://localhost:3000/api/v1"
      }
    }
  }
}
```

**Important**: Replace `/path/to/maybe/` with the actual path to your Maybe installation.

### 6. Restart Claude Desktop

Close and reopen Claude Desktop to load the MCP server.

## Usage Examples

### View Your Accounts

```
You: "Show me my accounts"
```

Claude will list all your accounts with balances.

### Create a Transaction

```
You: "I spent $50 on groceries at Whole Foods from my checking account yesterday"
```

Claude will:
1. Find your checking account
2. Find or suggest the "Groceries" category
3. Create the transaction with all details

### List Transactions

```
You: "Show me my last 10 transactions"
You: "What did I spend on groceries this month?"
You: "Show all transactions over $100 from my credit card"
```

### Update a Transaction

```
You: "Change my coffee purchase from yesterday to $5.50 instead of $5.00"
```

### Filter by Date Range

```
You: "Show me transactions from January 1st to January 31st"
```

## Available Tools

The MCP server provides these tools:

### Transaction Tools
- `create_transaction` - Create a new transaction
- `list_transactions` - List transactions with filters
- `get_transaction` - Get details of a specific transaction
- `update_transaction` - Update an existing transaction
- `delete_transaction` - Delete a transaction

### Account Tools
- `list_accounts` - List all accounts with balances

### Category Tools
- `list_categories` - List all categories

### Tag Tools
- `list_tags` - List all tags

### Merchant Tools
- `list_merchants` - List all merchants

## Security Considerations

### API Key Security

- **Never commit API keys** to version control
- Use environment variables or secure configuration
- Rotate keys periodically
- Revoke keys when no longer needed

### Scope Management

- Use `read` scope for viewing-only access
- Use `read_write` scope only when creating/updating data
- Each API key should have minimal required permissions

### Rate Limits

- API keys have configurable rate limits
- The MCP server respects rate limits automatically
- Rate limit headers are returned in responses

### Data Privacy

- MCP server runs locally and communicates directly with your Maybe instance
- No data is sent to third parties
- All communication uses your API key authentication

## Troubleshooting

### "MAYBE_API_KEY environment variable is required"

Set the environment variable:
```bash
export MAYBE_API_KEY="your_api_key_here"
```

### "API Error 401: Unauthorized"

Your API key is invalid or expired. Generate a new key from Settings → API Key.

### "API Error 403: Forbidden"

Your API key lacks the required scope. Create a new key with `read_write` scope.

### "API Error 422: Unprocessable Entity"

The request parameters are invalid. Check that:
- Account ID exists and belongs to your family
- Date is in YYYY-MM-DD format
- Amount is a valid number
- Category/Tag/Merchant IDs exist (if provided)

### Connection Refused

Ensure your Maybe instance is running and accessible at `MAYBE_API_BASE_URL`.

### MCP Server Not Loading in Claude Desktop

1. Verify the path in `claude_desktop_config.json` is correct
2. Check that Python 3.10+ is installed
3. Ensure all dependencies are installed
4. Restart Claude Desktop after configuration changes

## Advanced Configuration

### Custom API URL

For production instances, set the base URL:

```bash
export MAYBE_API_BASE_URL="https://your-instance.com/api/v1"
```

### Multiple Environments

You can run multiple MCP servers for different environments:

```json
{
  "mcpServers": {
    "maybe-finance-dev": {
      "command": "python3",
      "args": ["/path/to/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "dev_key",
        "MAYBE_API_BASE_URL": "http://localhost:3000/api/v1"
      }
    },
    "maybe-finance-prod": {
      "command": "python3",
      "args": ["/path/to/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "prod_key",
        "MAYBE_API_BASE_URL": "https://production.example.com/api/v1"
      }
    }
  }
}
```

### Programmatic Usage

You can also use the MCP server programmatically without Claude Desktop:

```python
import asyncio
from mcp_server import create_transaction, list_transactions

async def main():
    # Create a transaction
    result = await create_transaction({
        "account_id": "abc123",
        "amount": 50.00,
        "date": "2026-03-02",
        "name": "Groceries",
        "category_id": "def456"
    })
    print(result)

asyncio.run(main())
```

## Files

- `mcp_server.py` - MCP server implementation
- `mcp_requirements.txt` - Python dependencies
- `test_mcp_setup.py` - Setup validation script
- `setup_mcp.sh` - Automated setup script
- `MCP_README.md` - Detailed documentation
- `MCP_QUICKSTART.md` - Quick reference guide

## Support

For issues and feature requests:

1. Check the [MCP_README.md](MCP_README.md) for detailed documentation
2. Review [MCP_QUICKSTART.md](MCP_QUICKSTART.md) for usage examples
3. Run `python test_mcp_setup.py` to validate your setup
4. Open an issue on GitHub

## License

The MCP server is part of the Maybe Finance project and follows the same license as the main application.