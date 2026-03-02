# MCP Server Quick Start Guide

This guide provides quick reference examples for using the Maybe Finance MCP server with Claude Desktop.

## Setup Checklist

1. ✅ Install Python dependencies: `pip install -r mcp_requirements.txt`
2. ✅ Generate API key from Settings → API Key in your Maybe instance
3. ✅ Set environment variables (MAYBE_API_KEY, MAYBE_API_BASE_URL)
4. ✅ Test setup: `python test_mcp_setup.py`
5. ✅ Configure Claude Desktop (see MCP_README.md)
6. ✅ Restart Claude Desktop

## Common Commands

### Viewing Accounts

**Command:** "Show me my accounts"

**What Claude does:**
1. Calls `list_accounts`
2. Displays account names, balances, and IDs

**Example response:**
```
You have 3 accounts:
1. Checking (USD): $5,234.56 (ID: abc123...)
2. Savings (USD): $12,500.00 (ID: def456...)
3. Credit Card (USD): -$890.23 (ID: ghi789...)
```

### Creating a Transaction

**Command:** "I spent $45.50 on groceries at Whole Foods from my checking account yesterday"

**What Claude does:**
1. Calls `list_accounts` to find your checking account
2. Calls `list_categories` to find "Groceries" category
3. Calls `list_merchants` to find Whole Foods
4. Calls `create_transaction` with all parameters

**Required info:**
- Amount (can be extracted from context)
- Account (must specify which account)
- Date (defaults to today if not specified)
- Description/name

### Listing Transactions

**Command:** "Show my last 10 transactions"

**What Claude does:**
1. Calls `list_transactions` with per_page=10
2. Formats and displays results

**Command:** "Show all grocery transactions this month"

**What Claude does:**
1. Calls `list_categories` to find "Groceries" ID
2. Calls `list_transactions` with category_id and start_date filters
3. Calculates total and displays transactions

### Updating a Transaction

**Command:** "Change my coffee transaction from yesterday to $5.00 instead of $4.50"

**What Claude does:**
1. Calls `list_transactions` with date filter to find the transaction
2. Calls `update_transaction` with new amount

### Filtering Transactions

**By Account:**
"Show transactions from my checking account"

**By Date Range:**
"Show transactions from January 1st to January 31st"

**By Amount Range:**
"Show transactions over $100"

**By Type:**
"Show all income transactions"

**Combined:**
"Show grocery transactions from my credit card over $50 this month"

## Workflow Examples

### Monthly Expense Review

**Command:** "How much did I spend on each category this month?"

**Claude's process:**
1. Get all categories
2. For each category, get transactions for current month
3. Calculate totals
4. Present summary

### Budget Tracking

**Command:** "I have a $500 grocery budget. How am I doing?"

**Claude's process:**
1. Find "Groceries" category
2. Get current month's grocery transactions
3. Calculate total spent
4. Calculate remaining budget and percentage

### Finding Specific Transactions

**Command:** "Find my transaction at Starbucks last week"

**Claude's process:**
1. Call `list_merchants` to find Starbucks ID
2. Call `list_transactions` with merchant_id and date range
3. Display matching transactions

## Tips

### Providing Context

The more context you provide, the better Claude can help:

✅ **Good:** "I spent $50 on gas at Shell from my checking account this morning"

❌ **Vague:** "Add a transaction for gas"

### Working with IDs

Sometimes you may need to reference items by ID:

- **Account IDs:** Use when you have multiple accounts with similar names
- **Category IDs:** Use for specific subcategories
- **Tag IDs:** Use to group related transactions

### Date Formats

Claude understands natural language dates:

- "yesterday"
- "last week"
- "this month"
- "January 15th"
- "2026-03-02"

### Handling Errors

If something goes wrong, Claude will:

1. Show the error message
2. Suggest what might be wrong
3. Ask for clarification if needed

Common errors:

- **"Account not found"**: You specified an account name that doesn't exist
- **"Category not found"**: The category name doesn't match any of your categories
- **"Invalid amount"**: Amount should be a positive number
- **"Unauthorized"**: API key is invalid or missing required scope

## Advanced Usage

### Batch Operations

While Claude processes commands one at a time, you can ask for summaries:

"Show me all transactions this month grouped by category"

"List all transactions over $100 from my credit card"

### Custom Categorization

"I want to create transactions with the 'Dining Out' category"

Claude will:
1. Find the category ID for "Dining Out"
2. Use it for transaction creation

### Tagging Strategy

"Tag all my coffee transactions as 'caffeine'"

Claude will:
1. Find transactions matching "coffee"
2. Apply the "caffeine" tag to each

## Limitations

### Current Limitations

1. **No create categories/tags/merchants via API** - These must be created in the web interface first
2. **No bulk operations** - Transactions are created one at a time
3. **No transfers between accounts** - Use the web interface for transfers

### Workarounds

- Create categories, tags, and merchants in the web interface before referencing them in commands
- For bulk imports, use the CSV import feature in the web interface

## Getting Help

If you're having trouble:

1. Run `python test_mcp_setup.py` to validate your setup
2. Check the MCP_README.md for detailed documentation
3. Verify your API key has the correct scopes (read or read_write)
4. Ensure your Maybe instance is accessible at MAYBE_API_BASE_URL

## Security Notes

- **Never share your API key** - It provides full access to your financial data
- **Use environment variables** - Don't hardcode API keys in scripts
- **Review permissions** - Only grant `read_write` scope when needed
- **Monitor usage** - Check Settings → API Key to see last usage time
- **Rotate keys** - Generate new keys periodically and revoke old ones