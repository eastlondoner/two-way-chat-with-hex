# Claude Code Sandbox Network Configuration

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
