#!/bin/bash

# Maybe Finance MCP Server Setup Script
# This script helps you set up the MCP server for use with Claude Desktop

set -e

echo "========================================="
echo "Maybe Finance MCP Server Setup"
echo "========================================="
echo ""

# Check Python version
echo "Checking Python version..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed"
    echo "   Please install Python 3.10 or higher"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✓ Python version: $PYTHON_VERSION"

# Check if Python version is 3.10+
MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$MAJOR" -lt 3 ] || { [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 10 ]; }; then
    echo "❌ Python 3.10 or higher is required"
    exit 1
fi

# Install dependencies
echo ""
echo "Installing Python dependencies..."
pip install -q -r mcp_requirements.txt
echo "✓ Dependencies installed"

# Check for API key
echo ""
echo "Checking API key configuration..."
if [ -z "$MAYBE_API_KEY" ]; then
    echo "⚠ MAYBE_API_KEY is not set"
    echo ""
    echo "To get your API key:"
    echo "1. Open your Maybe Finance instance"
    echo "2. Go to Settings → API Key"
    echo "3. Create a new API key with 'read_write' scope"
    echo "4. Set the environment variable:"
    echo ""
    echo "   export MAYBE_API_KEY='your_api_key_here'"
    echo ""
    echo "For production instances, also set:"
    echo "   export MAYBE_API_BASE_URL='https://your-instance.com/api/v1'"
    echo ""
    read -p "Enter your API key (or press Enter to skip): " api_key
    if [ -n "$api_key" ]; then
        export MAYBE_API_KEY="$api_key"
        echo "✓ API key set for this session"
    else
        echo "⚠ No API key provided. Some features will not work."
    fi
else
    echo "✓ MAYBE_API_KEY is set"
fi

# Check for API URL
if [ -z "$MAYBE_API_BASE_URL" ]; then
    echo "⚠ MAYBE_API_BASE_URL is not set (using default: http://localhost:3000/api/v1)"
    echo "  For production instances, set MAYBE_API_BASE_URL"
else
    echo "✓ MAYBE_API_BASE_URL is set: $MAYBE_API_BASE_URL"
fi

# Run validation
echo ""
echo "Running validation..."
python3 test_mcp_setup.py

# Generate Claude Desktop configuration
echo ""
echo "Generating Claude Desktop configuration..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MCP_SERVER_PATH="$SCRIPT_DIR/mcp_server.py"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    OS_NAME="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CONFIG_FILE="$HOME/.config/claude/claude_desktop_config.json"
    OS_NAME="Linux"
else
    CONFIG_FILE="%APPDATA%\\Claude\\claude_desktop_config.json"
    OS_NAME="Windows"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Add this to your Claude Desktop config file:"
echo "   Location ($OS_NAME): $CONFIG_FILE"
echo ""
echo "   {"
echo "     \"mcpServers\": {"
echo "       \"maybe-finance\": {"
echo "         \"command\": \"python3\","
echo "         \"args\": [\"$MCP_SERVER_PATH\"],"
echo "         \"env\": {"
echo "           \"MAYBE_API_KEY\": \"${MAYBE_API_KEY:-YOUR_API_KEY}\","
echo "           \"MAYBE_API_BASE_URL\": \"${MAYBE_API_BASE_URL:-http://localhost:3000/api/v1}\""
echo "         }"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "2. Restart Claude Desktop"
echo ""
echo "3. Start using commands like:"
echo "   • \"Show me my accounts\""
echo "   • \"List my recent transactions\""
echo "   • \"Create a transaction for $50 in my checking account\""
echo ""
echo "For more examples, see:"
echo "   • MCP_QUICKSTART.md - Quick reference guide"
echo "   • MCP_README.md - Full documentation"
echo ""
echo "========================================="