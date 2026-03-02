#!/usr/bin/env python3
"""
MCP Server for Maybe Finance Application
Enables LLM-based agents to interact with the Maybe API for transaction management.
"""

import json
import os
from typing import Any, Optional

import httpx
from mcp.server import Server
from mcp.types import (
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
    ResourceLink,
)
import mcp.server.stdio

# Initialize the MCP server
app = Server("maybe-finance-server")

# Configuration
MAYBE_API_BASE_URL = os.environ.get("MAYBE_API_BASE_URL", "http://localhost:3000/api/v1")
MAYBE_API_KEY = os.environ.get("MAYBE_API_KEY", "")

# HTTP client for API requests
client = httpx.AsyncClient(timeout=30.0)


def get_headers() -> dict[str, str]:
    """Get API headers with authentication."""
    if not MAYBE_API_KEY:
        raise ValueError("MAYBE_API_KEY environment variable is required")
    return {
        "X-Api-Key": MAYBE_API_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }


@app.list_tools()
async def list_tools() -> list[Tool]:
    """List all available MCP tools."""
    return [
        # Transaction Tools
        Tool(
            name="create_transaction",
            description="Create a new transaction in Maybe. Requires account_id, amount, date, and name. Optionally specify category, merchant, tags, and transaction nature (income/expense).",
            inputSchema={
                "type": "object",
                "properties": {
                    "account_id": {
                        "type": "string",
                        "description": "UUID of the account to create the transaction in"
                    },
                    "amount": {
                        "type": "number",
                        "description": "Transaction amount (positive number)"
                    },
                    "date": {
                        "type": "string",
                        "description": "Transaction date in YYYY-MM-DD format"
                    },
                    "name": {
                        "type": "string",
                        "description": "Transaction name/description"
                    },
                    "description": {
                        "type": "string",
                        "description": "Optional longer description"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Optional notes for the transaction"
                    },
                    "currency": {
                        "type": "string",
                        "description": "Currency code (e.g., USD, EUR). Defaults to user's primary currency"
                    },
                    "category_id": {
                        "type": "string",
                        "description": "Optional UUID of category to assign"
                    },
                    "merchant_id": {
                        "type": "string",
                        "description": "Optional UUID of merchant"
                    },
                    "tag_ids": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional array of tag UUIDs to assign"
                    },
                    "nature": {
                        "type": "string",
                        "enum": ["income", "expense"],
                        "description": "Transaction nature. If not specified, amount sign determines nature"
                    }
                },
                "required": ["account_id", "amount", "date", "name"]
            }
        ),
        Tool(
            name="list_transactions",
            description="List transactions with optional filtering by account, category, date range, amount range, and more. Supports pagination.",
            inputSchema={
                "type": "object",
                "properties": {
                    "account_id": {
                        "type": "string",
                        "description": "Filter by account UUID"
                    },
                    "category_id": {
                        "type": "string",
                        "description": "Filter by category UUID"
                    },
                    "merchant_id": {
                        "type": "string",
                        "description": "Filter by merchant UUID"
                    },
                    "start_date": {
                        "type": "string",
                        "description": "Start date filter (YYYY-MM-DD)"
                    },
                    "end_date": {
                        "type": "string",
                        "description": "End date filter (YYYY-MM-DD)"
                    },
                    "min_amount": {
                        "type": "number",
                        "description": "Minimum amount filter"
                    },
                    "max_amount": {
                        "type": "number",
                        "description": "Maximum amount filter"
                    },
                    "tag_ids": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Filter by tag UUIDs"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["income", "expense"],
                        "description": "Filter by transaction type"
                    },
                    "search": {
                        "type": "string",
                        "description": "Search term for transaction name, notes, or merchant"
                    },
                    "page": {
                        "type": "integer",
                        "description": "Page number (default: 1)"
                    },
                    "per_page": {
                        "type": "integer",
                        "description": "Results per page (default: 25, max: 100)"
                    }
                }
            }
        ),
        Tool(
            name="get_transaction",
            description="Get details of a specific transaction by ID.",
            inputSchema={
                "type": "object",
                "properties": {
                    "transaction_id": {
                        "type": "string",
                        "description": "UUID of the transaction to retrieve"
                    }
                },
                "required": ["transaction_id"]
            }
        ),
        Tool(
            name="update_transaction",
            description="Update an existing transaction. Can update amount, date, name, category, tags, and other fields.",
            inputSchema={
                "type": "object",
                "properties": {
                    "transaction_id": {
                        "type": "string",
                        "description": "UUID of the transaction to update"
                    },
                    "amount": {
                        "type": "number",
                        "description": "New transaction amount"
                    },
                    "date": {
                        "type": "string",
                        "description": "New transaction date (YYYY-MM-DD)"
                    },
                    "name": {
                        "type": "string",
                        "description": "New transaction name/description"
                    },
                    "notes": {
                        "type": "string",
                        "description": "New notes"
                    },
                    "category_id": {
                        "type": "string",
                        "description": "New category UUID"
                    },
                    "merchant_id": {
                        "type": "string",
                        "description": "New merchant UUID"
                    },
                    "tag_ids": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "New tag UUIDs"
                    }
                },
                "required": ["transaction_id"]
            }
        ),
        Tool(
            name="delete_transaction",
            description="Delete a transaction by ID.",
            inputSchema={
                "type": "object",
                "properties": {
                    "transaction_id": {
                        "type": "string",
                        "description": "UUID of the transaction to delete"
                    }
                },
                "required": ["transaction_id"]
            }
        ),
        # Account Tools
        Tool(
            name="list_accounts",
            description="List all accounts for the authenticated user's family. Shows account balances and basic info.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        # Category Tools
        Tool(
            name="list_categories",
            description="List all categories for the authenticated user's family. Use this to find category IDs for transactions.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        # Tag Tools
        Tool(
            name="list_tags",
            description="List all tags for the authenticated user's family. Use this to find tag IDs for transactions.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        # Merchant Tools
        Tool(
            name="list_merchants",
            description="List all merchants for the authenticated user's family. Use this to find merchant IDs for transactions.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> list[TextContent | ImageContent | EmbeddedResource]:
    """Execute a tool by name with the given arguments."""

    try:
        if name == "create_transaction":
            return await create_transaction(arguments)
        elif name == "list_transactions":
            return await list_transactions(arguments)
        elif name == "get_transaction":
            return await get_transaction(arguments)
        elif name == "update_transaction":
            return await update_transaction(arguments)
        elif name == "delete_transaction":
            return await delete_transaction(arguments)
        elif name == "list_accounts":
            return await list_accounts()
        elif name == "list_categories":
            return await list_categories()
        elif name == "list_tags":
            return await list_tags()
        elif name == "list_merchants":
            return await list_merchants()
        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]

    except httpx.HTTPStatusError as e:
        error_detail = e.response.text if e.response else "No error details available"
        return [TextContent(
            type="text",
            text=f"API Error {e.response.status_code if e.response else 'unknown'}: {error_detail}"
        )]
    except Exception as e:
        return [TextContent(type="text", text=f"Error executing {name}: {str(e)}")]


async def create_transaction(args: dict) -> list[TextContent]:
    """Create a new transaction."""
    url = f"{MAYBE_API_BASE_URL}/transactions"

    # Build transaction payload
    transaction_data = {
        "account_id": args["account_id"],
        "amount": args["amount"],
        "date": args["date"],
        "name": args["name"],
    }

    # Add optional fields
    if args.get("description"):
        transaction_data["description"] = args["description"]
    if args.get("notes"):
        transaction_data["notes"] = args["notes"]
    if args.get("currency"):
        transaction_data["currency"] = args["currency"]
    if args.get("category_id"):
        transaction_data["category_id"] = args["category_id"]
    if args.get("merchant_id"):
        transaction_data["merchant_id"] = args["merchant_id"]
    if args.get("tag_ids"):
        transaction_data["tag_ids"] = args["tag_ids"]
    if args.get("nature"):
        transaction_data["nature"] = args["nature"]

    payload = {"transaction": transaction_data}

    response = await client.post(url, json=payload, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Transaction created successfully:\n{json.dumps(data, indent=2)}"
    )]


async def list_transactions(args: dict) -> list[TextContent]:
    """List transactions with optional filters."""
    url = f"{MAYBE_API_BASE_URL}/transactions"

    # Build query parameters
    params = {}
    if args.get("account_id"):
        params["account_id"] = args["account_id"]
    if args.get("category_id"):
        params["category_id"] = args["category_id"]
    if args.get("merchant_id"):
        params["merchant_id"] = args["merchant_id"]
    if args.get("start_date"):
        params["start_date"] = args["start_date"]
    if args.get("end_date"):
        params["end_date"] = args["end_date"]
    if args.get("min_amount"):
        params["min_amount"] = args["min_amount"]
    if args.get("max_amount"):
        params["max_amount"] = args["max_amount"]
    if args.get("tag_ids"):
        params["tag_ids"] = ",".join(args["tag_ids"])
    if args.get("type"):
        params["type"] = args["type"]
    if args.get("search"):
        params["search"] = args["search"]
    if args.get("page"):
        params["page"] = args["page"]
    if args.get("per_page"):
        params["per_page"] = args["per_page"]

    response = await client.get(url, params=params, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Transactions:\n{json.dumps(data, indent=2)}"
    )]


async def get_transaction(args: dict) -> list[TextContent]:
    """Get a specific transaction by ID."""
    transaction_id = args["transaction_id"]
    url = f"{MAYBE_API_BASE_URL}/transactions/{transaction_id}"

    response = await client.get(url, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Transaction details:\n{json.dumps(data, indent=2)}"
    )]


async def update_transaction(args: dict) -> list[TextContent]:
    """Update an existing transaction."""
    transaction_id = args["transaction_id"]
    url = f"{MAYBE_API_BASE_URL}/transactions/{transaction_id}"

    # Build update payload
    transaction_data = {}

    if args.get("amount") is not None:
        transaction_data["amount"] = args["amount"]
    if args.get("date"):
        transaction_data["date"] = args["date"]
    if args.get("name"):
        transaction_data["name"] = args["name"]
    if args.get("notes"):
        transaction_data["notes"] = args["notes"]
    if args.get("category_id"):
        transaction_data["category_id"] = args["category_id"]
    if args.get("merchant_id"):
        transaction_data["merchant_id"] = args["merchant_id"]
    if args.get("tag_ids"):
        transaction_data["tag_ids"] = args["tag_ids"]

    payload = {"transaction": transaction_data}

    response = await client.patch(url, json=payload, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Transaction updated successfully:\n{json.dumps(data, indent=2)}"
    )]


async def delete_transaction(args: dict) -> list[TextContent]:
    """Delete a transaction."""
    transaction_id = args["transaction_id"]
    url = f"{MAYBE_API_BASE_URL}/transactions/{transaction_id}"

    response = await client.delete(url, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Transaction deleted: {data.get('message', 'Success')}"
    )]


async def list_accounts() -> list[TextContent]:
    """List all accounts for the family."""
    url = f"{MAYBE_API_BASE_URL}/accounts"

    response = await client.get(url, headers=get_headers())
    response.raise_for_status()

    data = response.json()

    return [TextContent(
        type="text",
        text=f"Accounts:\n{json.dumps(data, indent=2)}"
    )]


async def list_categories() -> list[TextContent]:
    """List all categories for the family."""
    # Note: This endpoint might need to be created in the API
    # For now, we'll try the standard categories endpoint
    url = f"{MAYBE_API_BASE_URL.replace('/api/v1', '')}/api/v1/categories"

    try:
        response = await client.get(url, headers=get_headers())
        response.raise_for_status()
        data = response.json()
        return [TextContent(
            type="text",
            text=f"Categories:\n{json.dumps(data, indent=2)}"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"Error: Could not fetch categories. The categories endpoint may not be available in the API yet. Error: {str(e)}"
        )]


async def list_tags() -> list[TextContent]:
    """List all tags for the family."""
    # Note: This endpoint might need to be created in the API
    url = f"{MAYBE_API_BASE_URL.replace('/api/v1', '')}/api/v1/tags"

    try:
        response = await client.get(url, headers=get_headers())
        response.raise_for_status()
        data = response.json()
        return [TextContent(
            type="text",
            text=f"Tags:\n{json.dumps(data, indent=2)}"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"Error: Could not fetch tags. The tags endpoint may not be available in the API yet. Error: {str(e)}"
        )]


async def list_merchants() -> list[TextContent]:
    """List all merchants for the family."""
    # Note: This endpoint might need to be created in the API
    url = f"{MAYBE_API_BASE_URL.replace('/api/v1', '')}/api/v1/merchants"

    try:
        response = await client.get(url, headers=get_headers())
        response.raise_for_status()
        data = response.json()
        return [TextContent(
            type="text",
            text=f"Merchants:\n{json.dumps(data, indent=2)}"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"Error: Could not fetch merchants. The merchants endpoint may not be available in the API yet. Error: {str(e)}"
        )]


async def main():
    """Main entry point for the MCP server."""
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())