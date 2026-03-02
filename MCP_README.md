# Maybe Finance MCP Server

This MCP (Model Context Protocol) server enables LLM-based agents like Claude to interact with the Maybe Finance application through the API. Agents can create, read, update, and delete transactions programmatically.

## Features

- **Transaction Management**: Create, read, update, and delete transactions
- **Account Listing**: View all accounts with balances
- **Category Management**: List available categories for transaction categorization
- **Tag Management**: List available tags for transaction tagging
- **Merchant Management**: List merchants for transaction association
- **Advanced Filtering**: Filter transactions by account, category, date range, amount, and more

## Architecture Overview

**Important:** The MCP server runs **outside the container** on your local machine and communicates with the Maybe API over HTTP.

```
┌─────────────────────────────────┐
│  Your Local Machine              │
│                                  │
│  ┌──────────────────────────┐  │
│  │  Claude Desktop           │  │
│  │  (spawns MCP server)      │  │
│  └──────────┬───────────────┘  │
│             │ stdin/stdout      │
│             ↓                   │
│  ┌──────────────────────────┐  │
│  │  MCP Server (Python)     │  │
│  │  mcp_server.py           │  │
│  └──────────┬───────────────┘  │
│             │ HTTP              │
└─────────────┼───────────────────┘
              │
              │ http://localhost:3000/api/v1
              │ (or https://your-instance.com/api/v1)
              ↓
┌──────────────────────────────────┐
│  Maybe Container/Server          │
│  ┌──────────────────────────┐   │
│  │  Rails API (port 3000)   │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
```

**Why outside the container?**
- Claude Desktop needs to spawn the MCP server as a local subprocess
- MCP uses stdio (stdin/stdout) for communication, requiring local access
- API key stays secure on your local machine
- Simpler setup and better compatibility

For detailed architecture information, see [MCP_ARCHITECTURE.md](MCP_ARCHITECTURE.md).

## Prerequisites

1. **Python 3.10+** installed on your system
2. **Maybe Finance API Key** - Generate this from your Maybe instance at `/settings/api_key`
3. **Access to a running Maybe Finance instance** (either local or remote)

## Architecture

**Important:** The MCP server runs **outside the container** on your local machine, while the Maybe Finance app runs inside Docker (or on a remote server).

### Why MCP Runs Outside Container

1. **Claude Desktop Integration**: Claude Desktop needs to spawn the MCP server as a local subprocess
2. **Stdio Communication**: MCP uses stdin/stdout which requires local process access
3. **User Experience**: Simpler setup, independent management
4. **Security**: API key stays on user's machine

### Container Requirements

If running Maybe in Docker, ensure the API port is exposed:

```yaml
# docker-compose.yml
services:
  web:
    ports:
      - "3000:3000"  # Required for MCP server access
```

**The MCP server connects to the API via HTTP** using the exposed port.

For detailed architecture information, see [MCP_ARCHITECTURE.md](MCP_ARCHITECTURE.md).

## Installation

### 1. Install Python Dependencies

```bash
pip install -r mcp_requirements.txt
```

Or manually:

```bash
pip install mcp httpx
```

### 2. Set Environment Variables

The MCP server needs to connect to your Maybe Finance API. Configure based on your deployment:

#### Option A: Docker (Self-Hosted)

If Maybe is running in Docker on your machine:

```bash
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"
```

**Important:** Ensure your `docker-compose.yml` exposes port 3000:
```yaml
ports:
  - "3000:3000"
```

#### Option B: Remote/Managed Instance

If using a hosted Maybe instance:

```bash
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="https://your-instance.com/api/v1"
```

#### Option C: Local Development

If running Maybe locally without Docker:

```bash
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"
```

For production instances:

```bash
export MAYBE_API_KEY="your_api_key_here"
export MAYBE_API_BASE_URL="https://your-maybe-instance.com/api/v1"
```

### 3. Test the Server

Run the server directly to test:

```bash
python mcp_server.py
```

## Configuration for Claude Desktop

To use this MCP server with Claude Desktop, add the following to your Claude Desktop configuration file:

### macOS
Edit `~/Library/Application Support/Claude/claude_desktop_config.json`

### Linux
Edit `~/.config/claude/claude_desktop_config.json`

### Windows
Edit `%APPDATA%\Claude\claude_desktop_config.json`

### Configuration Content

```json
{
  "mcpServers": {
    "maybe-finance": {
      "command": "python",
      "args": ["/path/to/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "your_api_key_here",
        "MAYBE_API_BASE_URL": "http://localhost:3000/api/v1"
      }
    }
  }
}
```

**Important**: Replace `/path/to/maybe/` with the actual path to your Maybe installation directory, and replace `your_api_key_here` with your actual API key.

## Generating an API Key

1. Log in to your Maybe Finance instance
2. Navigate to **Settings** → **API Key**
3. Click **Create New API Key**
4. Give it a name (e.g., "MCP Server")
5. Select the scopes:
   - **read**: Required for listing and viewing transactions, accounts, categories, etc.
   - **read_write**: Required for creating, updating, and deleting transactions
6. Copy the generated API key and save it securely

## Available Tools

The MCP server provides the following tools:

### Transaction Tools

#### `create_transaction`
Create a new transaction in Maybe.

**Required Parameters:**
- `account_id`: UUID of the account
- `amount`: Transaction amount (positive number)
- `date`: Transaction date (YYYY-MM-DD)
- `name`: Transaction name/description

**Optional Parameters:**
- `description`: Longer description
- `notes`: Transaction notes
- `currency`: Currency code (e.g., USD, EUR)
- `category_id`: Category UUID
- `merchant_id`: Merchant UUID
- `tag_ids`: Array of tag UUIDs
- `nature`: "income" or "expense"

**Example Usage (in Claude):**
```
Create a transaction for $50.50 in my checking account for groceries on 2026-03-02
```

Claude will automatically:
1. Call `list_accounts` to find your checking account ID
2. Call `list_categories` to find the groceries category
3. Call `create_transaction` with the appropriate parameters

#### `list_transactions`
List transactions with optional filtering.

**Optional Parameters:**
- `account_id`: Filter by account
- `category_id`: Filter by category
- `merchant_id`: Filter by merchant
- `start_date` / `end_date`: Date range filter
- `min_amount` / `max_amount`: Amount range filter
- `tag_ids`: Filter by tags
- `type`: "income" or "expense"
- `search`: Search term
- `page` / `per_page`: Pagination

#### `get_transaction`
Get details of a specific transaction by ID.

**Required Parameters:**
- `transaction_id`: UUID of the transaction

#### `update_transaction`
Update an existing transaction.

**Required Parameters:**
- `transaction_id`: UUID of the transaction

**Optional Parameters:**
- `amount`, `date`, `name`, `notes`, `category_id`, `merchant_id`, `tag_ids`

#### `delete_transaction`
Delete a transaction by ID.

**Required Parameters:**
- `transaction_id`: UUID of the transaction

### Account Tools

#### `list_accounts`
List all accounts for your family with balances and basic information.

### Category Tools

#### `list_categories`
List all available categories for transaction categorization.

### Tag Tools

#### `list_tags`
List all available tags for transaction tagging.

### Merchant Tools

#### `list_merchants`
List all merchants for transaction association.

## Example Workflows

### Creating a Transaction

**User**: "I bought coffee for $4.50 at Starbucks this morning from my checking account"

**Claude will**:
1. List accounts to find your checking account
2. List merchants to find Starbucks (or create if needed)
3. Create the transaction with appropriate categorization

### Viewing Recent Transactions

**User**: "Show me my last 10 transactions"

**Claude will**:
1. Call `list_transactions` with per_page=10
2. Format and display the results

### Filtering by Category

**User**: "How much did I spend on groceries this month?"

**Claude will**:
1. List categories to find groceries
2. List transactions filtered by category and date range
3. Calculate and display the total

## Security Considerations

1. **API Key Security**: Never commit your API key to version control. Use environment variables.
2. **Rate Limits**: The API has rate limits. The MCP server respects these limits and returns appropriate error messages.
3. **Scope Limitations**: API keys with `read` scope can only read data. Use `read_write` scope for creating transactions.
4. **Network Security**: If connecting to a remote Maybe instance, ensure it uses HTTPS.

## Troubleshooting

### "MAYBE_API_KEY environment variable is required"

Set the `MAYBE_API_KEY` environment variable or add it to your Claude Desktop configuration.

### "API Error 401: Unauthorized"

Your API key is invalid or expired. Generate a new key from Settings → API Key.

### "API Error 403: Forbidden"

Your API key lacks the necessary scope. For creating/updating transactions, you need the `read_write` scope.

### "API Error 422: Unprocessable Entity"

The request parameters are invalid. Check that:
- Account ID exists and belongs to your family
- Date is in YYYY-MM-DD format
- Amount is a valid number
- Category/Tag/Merchant IDs exist (if provided)

### Connection Refused

Ensure your Maybe instance is running and accessible at the configured `MAYBE_API_BASE_URL`.

## Development

### Running Tests

```bash
python -m pytest tests/
```

### Adding New Tools

1. Define the tool in `list_tools()`
2. Implement the handler function
3. Add it to the `call_tool()` router
4. Update this README

## License

This MCP server is part of the Maybe Finance project and follows the same license as the main application.

## Support

For issues and feature requests:
1. Check the [Maybe Finance documentation](https://github.com/maybe-finance/maybe)
2. Open an issue on GitHub
3. Refer to the API documentation at `/api/v1/docs` (if available) on your Maybe instance