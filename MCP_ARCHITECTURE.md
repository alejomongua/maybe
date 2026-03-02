# MCP Server Deployment Architecture

## Overview

The MCP server for Maybe Finance runs **outside the container** on the user's local machine and communicates with the Maybe API (running inside or outside a container) over HTTP.

## Architecture Decision

### Why MCP Runs Outside Container

1. **Claude Desktop Integration**
   - Claude Desktop runs on the user's local machine
   - It spawns MCP servers as subprocesses using stdio communication
   - The MCP server process must be accessible locally

2. **Stdio Communication**
   - MCP protocol uses stdin/stdout for communication
   - This requires the process to be local, not remote
   - Containerized MCP would require complex port forwarding

3. **User Experience**
   - Simpler setup for users
   - No need to expose additional ports
   - No need to manage container networking for stdio

4. **Security**
   - API key stays on user's machine
   - Communication with Maybe API uses standard HTTP(S)
   - Container isolation is maintained

## Deployment Scenarios

### Scenario 1: Docker Compose (Self-Hosted)

**Maybe runs in Docker, MCP runs locally**

```yaml
# docker-compose.yml
services:
  web:
    image: maybefinance/maybe:latest
    ports:
      - "3000:3000"  # API must be exposed
    environment:
      RAILS_ENV: production
      # ... other config
```

**User's local machine:**
```bash
# Install MCP dependencies
pip install -r mcp_requirements.txt

# Configure to connect to containerized Maybe
export MAYBE_API_KEY="your_key"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"

# Test connection
python test_mcp_setup.py
```

### Scenario 2: Managed/Cloud Instance

**Maybe runs on remote server, MCP runs locally**

**User's local machine:**
```bash
# Configure to connect to remote Maybe
export MAYBE_API_KEY="your_key"
export MAYBE_API_BASE_URL="https://your-instance.maybefinance.com/api/v1"

# Claude Desktop config
{
  "mcpServers": {
    "maybe-finance": {
      "command": "python3",
      "args": ["/path/to/maybe/mcp_server.py"],
      "env": {
        "MAYBE_API_KEY": "your_key",
        "MAYBE_API_BASE_URL": "https://your-instance.maybefinance.com/api/v1"
      }
    }
  }
}
```

### Scenario 3: Local Development

**Maybe runs locally (not containerized), MCP runs locally**

```bash
# Start Rails server
bin/dev  # Runs on localhost:3000

# In another terminal, configure MCP
export MAYBE_API_KEY="your_key"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"
```

## Container Configuration

### Docker Compose Requirements

The Maybe container **must expose the API port** for MCP to work:

```yaml
# docker-compose.yml
services:
  maybe:
    image: maybefinance/maybe:latest
    ports:
      - "3000:3000"  # Required for MCP server access
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - DATABASE_URL=${DATABASE_URL}
      # ... other environment variables
```

**Important**: If you don't expose port 3000, the MCP server cannot communicate with the API.

### Dockerfile Considerations

The Dockerfile does **not** need to include:
- Python runtime
- MCP dependencies
- mcp_server.py

These run outside the container on the user's machine.

## Alternative: MCP in Container (Advanced)

If you really want MCP inside the container, you would need:

### Approach 1: Expose via Volume Mount

```yaml
# docker-compose.yml
services:
  maybe:
    image: maybefinance/maybe:latest
    volumes:
      - ./mcp_server.py:/app/mcp_server.py:ro
      - ./mcp_requirements.txt:/app/mcp_requirements.txt:ro
    ports:
      - "3000:3000"
```

**Claude Desktop config:**
```json
{
  "mcpServers": {
    "maybe-finance": {
      "command": "docker",
      "args": [
        "exec", "-i", "maybe_container_name",
        "python3", "/app/mcp_server.py"
      ],
      "env": {
        "MAYBE_API_KEY": "your_key",
        "MAYBE_API_BASE_URL": "http://localhost:3000/api/v1"
      }
    }
  }
}
```

**Problems:**
- Requires Docker to be installed and running
- Complex setup for users
- Container must have Python installed
- Must manage dependencies inside container

### Approach 2: Sidecar Container

```yaml
# docker-compose.yml
services:
  maybe:
    image: maybefinance/maybe:latest
    ports:
      - "3000:3000"

  mcp-server:
    image: maybefinance/mcp:latest
    environment:
      - MAYBE_API_KEY=${MAYBE_API_KEY}
      - MAYBE_API_BASE_URL=http://maybe:3000/api/v1
    stdin_open: true
    tty: true
```

**Problems:**
- Claude Desktop still needs local access to MCP
- Would need to use `docker attach` or similar
- Complex networking
- Not recommended

## Recommendation

**Use the default architecture: MCP runs outside container**

### For Self-Hosted Users

```bash
# 1. Clone or download Maybe
git clone https://github.com/maybe-finance/maybe.git
cd maybe

# 2. Start Maybe in Docker
docker-compose up -d

# 3. Generate API key in web UI (Settings → API Key)

# 4. Configure MCP (runs locally)
export MAYBE_API_KEY="your_key_here"
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"

# 5. Test setup
pip install -r mcp_requirements.txt
python test_mcp_setup.py

# 6. Configure Claude Desktop
# Add to claude_desktop_config.json
```

### For Managed Instance Users

```bash
# 1. Download MCP files
# (or they're included in the release)

# 2. Configure for remote instance
export MAYBE_API_KEY="your_key_here"
export MAYBE_API_BASE_URL="https://your-instance.maybefinance.com/api/v1"

# 3. Install and test
pip install -r mcp_requirements.txt
python test_mcp_setup.py

# 4. Configure Claude Desktop
```

## Distribution

The MCP server files should be:

1. **Included in releases** - Users download the MCP files with Maybe
2. **Available separately** - Users can download just the MCP components
3. **Version matched** - MCP version should match API version

### Release Package Structure

```
maybe-mcp-v1.0.0.tar.gz
├── mcp_server.py
├── mcp_requirements.txt
├── test_mcp_setup.py
├── setup_mcp.sh
├── MCP_README.md
├── MCP_QUICKSTART.md
└── MCP_ARCHITECTURE.md
```

## Security Considerations

### API Key Storage

**Outside Container (Recommended):**
```bash
# User's local machine
export MAYBE_API_KEY="key"  # Environment variable
# OR
# In Claude Desktop config (only readable by user)
```

**Inside Container (Not Recommended):**
```yaml
# docker-compose.yml - exposes key in config
environment:
  - MAYBE_API_KEY=${MAYBE_API_KEY}  # Visible in docker inspect
```

### Network Security

**Local Development:**
- API on localhost:3000
- Only accessible from local machine
- MCP connects via localhost

**Production/Remote:**
- API on HTTPS endpoint
- API key required for authentication
- MCP connects via HTTPS with API key header

## Troubleshooting

### "Cannot connect to localhost:3000"

**Problem:** Maybe container not running or port not exposed

**Solution:**
```bash
# Check if container is running
docker ps

# Check if port is exposed
docker-compose ps

# Ensure ports are mapped in docker-compose.yml
ports:
  - "3000:3000"
```

### "API Error: Connection refused"

**Problem:** Wrong API URL or Maybe not started

**Solution:**
```bash
# For Docker deployment
export MAYBE_API_BASE_URL="http://localhost:3000/api/v1"

# For remote instance
export MAYBE_API_BASE_URL="https://your-instance.com/api/v1"

# Verify API is accessible
curl $MAYBE_API_BASE_URL/accounts -H "X-Api-Key: your_key"
```

### "Claude Desktop can't start MCP server"

**Problem:** Python not installed or wrong path

**Solution:**
1. Ensure Python 3.10+ is installed locally
2. Check path in claude_desktop_config.json is absolute
3. Run `python test_mcp_setup.py` to validate

## Summary

- ✅ **MCP runs outside container** on user's local machine
- ✅ **Maybe runs inside container** (or on remote server)
- ✅ **Communication via HTTP** to exposed API port
- ✅ **Claude Desktop spawns MCP** as local subprocess
- ✅ **API key stays local** on user's machine
- ✅ **Container must expose API port** (3000) for MCP access

This architecture provides the best balance of simplicity, security, and compatibility with Claude Desktop's stdio-based MCP integration.