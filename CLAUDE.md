# Claude Code Sandbox Network Configuration

<!-- Test change to verify PR comment wake-up workflow -->

## HTTP Proxy Authentication

The Claude Code sandbox routes all external HTTP/HTTPS traffic through an authenticated proxy.

### Proxy Environment Variables

The following environment variables contain the authenticated proxy URL:

- `HTTP_PROXY` / `http_proxy`
- `HTTPS_PROXY` / `https_proxy`
- `GLOBAL_AGENT_HTTP_PROXY` / `GLOBAL_AGENT_HTTPS_PROXY`
- `YARN_HTTP_PROXY` / `YARN_HTTPS_PROXY`

### Proxy URL Format

```
http://CONTAINER_ID:jwt_JWT_TOKEN@21.0.0.97:15004
```

Where:
- `CONTAINER_ID`: Container identifier (e.g., `container_container_01Y1iokMppErMQp1AbDUghXj--claude_code_remote--wee-lined-brief-wages`)
- `JWT_TOKEN`: JWT for authentication, containing:
  - `iss`: `anthropic-egress-control`
  - `organization_uuid`: Organization ID
  - `session_id`: Session identifier
  - `container_id`: Container identifier
  - `allowed_hosts`: Allowed destination hosts (typically `*`)
  - `exp`: Expiration timestamp

### Authentication Method

The proxy uses HTTP Basic authentication with:
- **Username**: Container ID
- **Password**: `jwt_` prefix + JWT token

Example header sent during HTTP CONNECT:
```
Proxy-Authorization: Basic base64(CONTAINER_ID:jwt_TOKEN)
```

### TLS Inspection

The proxy performs TLS MITM inspection on all HTTPS traffic:
- Issuer: `O=Anthropic; CN=sandbox-egress-production TLS Inspection CA`
- Certificates are dynamically generated for each connection
- Applications must trust the Anthropic CA or disable certificate verification

### No-Proxy Hosts

The following hosts bypass the proxy (from `NO_PROXY`/`no_proxy`):
- `localhost`
- `127.0.0.1`
- `169.254.169.254` (metadata service)
- `metadata.google.internal`
- `*.svc.cluster.local`
- `*.local`
- `*.googleapis.com`
- `*.google.com`

### DNS Resolution

- `CLAUDE_CODE_PROXY_RESOLVES_HOSTS=true` indicates the proxy handles DNS resolution
- Local DNS resolution (`[::1]:53`) is typically disabled/blocked
- Applications should let the proxy resolve hostnames via HTTP CONNECT

### Behavior Without Authentication

Unauthenticated requests to the proxy (without the JWT) receive:
```
HTTP/1.1 401 Unauthorized
www-authenticate: Bearer realm=""
server: envoy
```

### Supported Protocols

- HTTP/1.1: Supported through CONNECT tunnel
- HTTP/2: Supported through CONNECT tunnel (proxy negotiates ALPN)
- WebSockets: **BLOCKED** - proxy strips `Connection: Upgrade` and `Upgrade: websocket` headers
- Raw TCP: Only through HTTP CONNECT tunnel to port 443

## Protocol Feasibility Testing Results

Comprehensive testing of communication protocols through the sandbox proxy:

| Protocol | Status | Notes |
|----------|--------|-------|
| **Raw TCP (direct)** | ❌ BLOCKED | No direct outbound TCP connections allowed |
| **HTTP CONNECT to port 22** | ⚠️ PARTIAL | Returns 200 OK but **no data flows** - connection hangs |
| **HTTP CONNECT to port 443** | ✅ WORKS | Full bidirectional data flow after TLS handshake |
| **WebSocket** | ❌ BLOCKED | `Connection: Upgrade` header stripped by proxy |
| **HTTP/2 streams** | ✅ WORKS | ALPN negotiates h2 successfully |
| **Chunked Transfer** | ✅ WORKS | Streaming responses received correctly |
| **Server-Sent Events** | ✅ WORKS | Similar to chunked transfer |
| **HTTP Long-Polling** | ⚠️ ISSUES | Connections establish but timeout after ~15s with 0 bytes transferred |

### Key Findings

1. **Port 443 is special**: HTTP CONNECT to port 443 allows full data flow; port 22 connects but blocks data
2. **WebSocket blocked at header level**: The WebSocket-specific headers (`Sec-WebSocket-*`) pass through, but `Connection: Upgrade` is stripped
3. **Long-polling problematic**: The proxy may buffer responses or timeout idle connections, breaking long-polling tunnels like gost PHT
4. **HTTP/2 works**: Full HTTP/2 support including multiplexed streams

### Viable Tunneling Options

Based on testing, these approaches should work:

1. **HTTP/2 bidirectional streaming** - Use gRPC or custom HTTP/2 streams
2. **Short-polling HTTP** - Frequent small requests instead of long-polling
3. **Chunked transfer encoding** - For server-to-client streaming
4. **Simple HTTPS proxy** - Expose SSH as HTTPS endpoint with HTTP CONNECT

### Non-Viable Options

- WebSocket-based tunnels (chisel, cloudflared default mode)
- gost PHT long-polling (timeouts)
- Direct TCP/SSH connections
- Raw TCP relay through HTTP CONNECT to non-443 ports

## SSH-over-HTTP Relay Solution

A working solution for SSH access from the sandbox uses HTTP/2 with Server-Sent Events (SSE):

### Architecture

```
[Sandbox Client] -- HTTPS/HTTP2 --> [Cloudflare Tunnel] --> [HTTP Relay Server] --> [SSH Server]
                                                                   ↓
                                                             POST /ssh/send (client→server data)
                                                             GET  /ssh/stream (SSE for server→client)
                                                             GET  /ssh/recv (polling fallback)
```

### Client Options

Two relay clients are available:

1. **HTTP/2 + SSE** (recommended): `ssh_http2_relay.py`
   - Uses HTTP/2 for better performance
   - Server-Sent Events for receiving data (lower latency)
   - Requires `httpx` Python package

2. **HTTP/1.1 Polling** (fallback): `ssh_http_relay.py`
   - Compatible with any Python installation
   - Uses short-polling for receiving data

### Client Configuration

```bash
# HTTP/2 + SSE (preferred)
ssh -o ProxyCommand="python3 ssh_http2_relay.py https://relay-server.example.com [api_key]" user@localhost

# HTTP/1.1 Polling (fallback)
ssh -o ProxyCommand="python3 ssh_http_relay.py https://relay-server.example.com [api_key]" user@localhost
```

### API Protocol

- **POST /ssh/send**: Send base64-encoded data to SSH, with `X-Session-ID` and `X-API-Key` headers
- **GET /ssh/stream**: SSE stream for receiving SSH data (format: `data: <base64>\n\n`)
- **GET /ssh/recv**: Polling fallback - receive base64-encoded SSH response
- **GET /health**: Health check endpoint (no auth required)
- **GET /stats**: Server statistics (requires auth)

### GitHub Variables for Setup

Configure these variables in the repository to enable SSH relay:

- `CLAUDE_SSH_KEY`: Base64-encoded private SSH key
- `CLAUDE_SSH_RELAY_URL`: URL of the HTTP relay server (e.g., `https://m1.gptkids.app`)
- `CLAUDE_DESKTOP_USER`: SSH username
- `CLAUDE_DESKTOP_HOST`: Desktop hostname (used for non-relay connections)

### Post-Checkout Hook Integration

The `.githooks/post-checkout` script automatically:
1. Fetches SSH key and relay URL from GitHub variables
2. Copies `ssh_http_relay.py` to `~/.ssh/`
3. Configures SSH config with ProxyCommand when in remote environment

### Usage

Once configured, connect to the desktop with:

```bash
ssh desktop
# or with command
ssh desktop "hostname; uname -a"
```

## Session Identification

Environment variables available within a Claude Code web session to identify the current session:

### Key Environment Variables

| Variable | Example | Purpose |
|----------|---------|---------|
| `CLAUDE_CODE_REMOTE_SESSION_ID` | `session_012e8Mfz8nX8o77VpBsT56Ro` | **Primary API/MCP session identifier** - use this to match with claude-town API |
| `CLAUDE_CODE_SESSION_ID` | `c4cc99d2-a561-477a-9fa3-866f96bd4149` | Internal UUID for the session |
| `CLAUDE_CODE_CONTAINER_ID` | `container_01DvmJFqh8BwAusQSFYyYFFp--claude_code_remote--...` | Container identifier |

### Usage

To get the current session's API identifier from within a session:

```bash
echo $CLAUDE_CODE_REMOTE_SESSION_ID
# Output: session_012e8Mfz8nX8o77VpBsT56Ro
```

This identifier matches the `id` field returned by the claude-town MCP server's `list_sessions` tool.

### Cross-Reference with Git Branch

The git branch name (e.g., `claude/check-web-sessions-QlHnX`) contains a shortened session suffix that can be used to identify sessions in claude-town output.

## PR Comment Session Wake-up

A GitHub Action automatically wakes Claude Code sessions when comments are posted on PRs.

### How It Works

1. When a comment is posted on a PR, the action triggers
2. It extracts the PR branch name from GitHub
3. Queries the Claude Code web API to find sessions matching that branch
4. Sends a wake-up message to the most recently updated session with the comment context

### Required GitHub Variables

The workflow automatically uses the `CLAUDE_CREDENTIALS` GitHub variable that is already synced by the post-commit hook. No additional configuration needed!

The credentials are automatically kept in sync by the post-commit hook whenever a Claude Code session makes a commit.

### Workflow File

The workflow is defined in `.github/workflows/pr-comment-wake-session.yml` and uses `.github/scripts/wake-session.js`.

### What Gets Sent to the Session

The wake-up message includes:
- PR number and title
- Comment author
- Full comment body
- Links to PR and comment

The session will then process the comment and respond appropriately.
