---
name: ssh-desktop
description: SSH to the desktop Mac machine via HTTP relay tunnel. Use when the user wants to run commands on the desktop, access desktop files, or interact with the Mac.
---

# SSH to Desktop

Connect to the desktop Mac via the HTTP relay tunnel configured in `~/.ssh/config`.

## Quick Reference

```bash
# Run a command on desktop
ssh desktop "command here"

# Interactive examples
ssh desktop "hostname; uname -a"
ssh desktop "ls -la ~/Desktop"
ssh desktop "brew list"
```

## How It Works

The connection uses an HTTP relay tunnel that works through the sandbox proxy:

```
[Sandbox] --HTTPS--> [Cloudflare Tunnel] --> [HTTP Relay Server] --> [SSH Server]
```

- **Relay URL**: Configured via `CLAUDE_SSH_RELAY_URL` GitHub variable
- **API Key**: Configured via `CLAUDE_SSH_RELAY_API_KEY` GitHub variable
- **SSH Key**: Stored in `~/.ssh/claude_desktop_key`
- **ProxyCommand**: Uses `ssh_http_relay.py` for HTTP tunneling

## SSH Config

The `~/.ssh/config` is automatically configured by the post-checkout hook:

```
Host desktop
    HostName localhost
    User m1
    IdentityFile ~/.ssh/claude_desktop_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand python3 ~/.ssh/ssh_http_relay.py <relay_url> <api_key>
```

## Common Tasks

| Task | Command |
|------|---------|
| Check connectivity | `ssh desktop "echo ok"` |
| System info | `ssh desktop "uname -a"` |
| List files | `ssh desktop "ls -la /path"` |
| Run script | `ssh desktop "bash -s" < local_script.sh` |
| Copy to desktop | `cat file \| ssh desktop "cat > /path/file"` |
| Copy from desktop | `ssh desktop "cat /path/file" > local_file` |

## Troubleshooting

If SSH fails:
1. Check relay is running: `curl -s https://m1.gptkids.app/health`
2. Verify SSH key exists: `ls -la ~/.ssh/claude_desktop_key`
3. Test with verbose: `ssh -v desktop "echo test"`
