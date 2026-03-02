#!/usr/bin/env python3
"""
Test script to validate MCP server setup for Maybe Finance
Run this script to verify your configuration before using with Claude Desktop.
"""

import os
import sys
import asyncio
import httpx


def check_environment():
    """Check that required environment variables are set."""
    print("Checking environment variables...")

    api_key = os.environ.get("MAYBE_API_KEY")
    api_url = os.environ.get("MAYBE_API_BASE_URL", "http://localhost:3000/api/v1")

    if not api_key:
        print("❌ MAYBE_API_KEY is not set")
        print("   Set it with: export MAYBE_API_KEY='your_key_here'")
        return False

    print(f"✓ MAYBE_API_KEY is set (length: {len(api_key)})")
    print(f"✓ MAYBE_API_BASE_URL: {api_url}")

    return True


async def test_api_connection():
    """Test connection to the Maybe API."""
    api_key = os.environ.get("MAYBE_API_KEY")
    api_url = os.environ.get("MAYBE_API_BASE_URL", "http://localhost:3000/api/v1")

    if not api_key:
        print("\n❌ Cannot test API connection: MAYBE_API_KEY not set")
        return False

    print("\nTesting API connection...")

    headers = {
        "X-Api-Key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            # Test accounts endpoint
            response = await client.get(f"{api_url}/accounts", headers=headers)

            if response.status_code == 200:
                data = response.json()
                print(f"✓ Successfully connected to Maybe API")
                print(f"✓ Found {len(data.get('accounts', []))} accounts")

                # Show account details
                accounts = data.get('accounts', [])
                if accounts:
                    print("\n  Available accounts:")
                    for account in accounts[:5]:  # Show first 5 accounts
                        balance = account.get('balance', 'N/A')
                        currency = account.get('currency', 'USD')
                        print(f"    - {account.get('name', 'Unknown')}: {balance} {currency} (ID: {account.get('id', 'N/A')[:8]}...)")

                return True

            elif response.status_code == 401:
                print("❌ API Error: Unauthorized - Invalid API key")
                return False

            elif response.status_code == 403:
                print("❌ API Error: Forbidden - API key lacks required scope")
                print("   Make sure your API key has 'read' or 'read_write' scope")
                return False

            else:
                print(f"❌ API Error: {response.status_code} - {response.text}")
                return False

        except httpx.ConnectError:
            print(f"❌ Cannot connect to {api_url}")
            print("   Make sure your Maybe instance is running")
            return False

        except Exception as e:
            print(f"❌ Error: {str(e)}")
            return False


async def test_categories():
    """Test categories endpoint."""
    api_key = os.environ.get("MAYBE_API_KEY")
    api_url = os.environ.get("MAYBE_API_BASE_URL", "http://localhost:3000/api/v1")

    if not api_key:
        return False

    print("\nTesting categories endpoint...")

    headers = {
        "X-Api-Key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(f"{api_url}/categories", headers=headers)

            if response.status_code == 200:
                data = response.json()
                categories = data.get('categories', [])
                print(f"✓ Found {len(categories)} categories")

                if categories:
                    print("  Sample categories:")
                    for cat in categories[:5]:
                        print(f"    - {cat.get('name')} ({cat.get('classification')})")

                return True

            else:
                print(f"❌ Categories endpoint error: {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ Error testing categories: {str(e)}")
            return False


def test_mcp_dependencies():
    """Check that required Python packages are installed."""
    print("\nChecking Python dependencies...")

    try:
        import mcp
        print("✓ mcp package installed")
    except ImportError:
        print("❌ mcp package not installed")
        print("   Install with: pip install mcp")
        return False

    try:
        import httpx
        print("✓ httpx package installed")
    except ImportError:
        print("❌ httpx package not installed")
        print("   Install with: pip install httpx")
        return False

    return True


def main():
    """Run all tests."""
    print("=" * 60)
    print("Maybe Finance MCP Server - Setup Validation")
    print("=" * 60)

    # Check Python version
    if sys.version_info < (3, 10):
        print("❌ Python 3.10 or higher is required")
        sys.exit(1)

    print(f"✓ Python version: {sys.version}")

    # Run tests
    all_passed = True

    # Test dependencies
    if not test_mcp_dependencies():
        all_passed = False

    # Test environment
    if not check_environment():
        all_passed = False

    # Test API connection (async)
    if all_passed:
        loop = asyncio.get_event_loop()
        if not loop.run_until_complete(test_api_connection()):
            all_passed = False

        # Test categories endpoint
        loop.run_until_complete(test_categories())

    # Print summary
    print("\n" + "=" * 60)
    if all_passed:
        print("✓ All checks passed!")
        print("\nNext steps:")
        print("1. Add this configuration to Claude Desktop:")
        print("   ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)")
        print("   ~/.config/claude/claude_desktop_config.json (Linux)")
        print("   %APPDATA%\\Claude\\claude_desktop_config.json (Windows)")
        print("\n2. Add the server configuration:")
        print(f'   {{')
        print(f'     "mcpServers": {{')
        print(f'       "maybe-finance": {{')
        print(f'         "command": "python",')
        print(f'         "args": ["{os.path.abspath("mcp_server.py")}"],')
        print(f'         "env": {{')
        print(f'           "MAYBE_API_KEY": "{os.environ.get("MAYBE_API_KEY", "YOUR_API_KEY")}",')
        print(f'           "MAYBE_API_BASE_URL": "{os.environ.get("MAYBE_API_BASE_URL", "http://localhost:3000/api/v1")}"')
        print(f'         }}')
        print(f'       }}')
        print(f'     }}')
        print(f'   }}')
        print("\n3. Restart Claude Desktop")
        print("\n4. Start using commands like:")
        print("   'Show me my recent transactions'")
        print("   'Create a transaction for $50 in my checking account'")
    else:
        print("❌ Some checks failed. Please fix the issues above and try again.")
        sys.exit(1)

    print("=" * 60)


if __name__ == "__main__":
    main()