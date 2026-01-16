# Claude Code Documentation Site Map

This site map documents the structure of the Claude Code documentation at https://code.claude.com/docs/

## Directory Structure

```
docs/
└── en/                          # English documentation (primary)
    ├── Core Documentation
    ├── IDE & Editor Integration
    ├── Deployment Options
    ├── Advanced Features
    ├── Configuration & Administration
    ├── Enterprise Features
    ├── Reference & Support
    └── Additional Topics
```

---

## `/docs/en/` - English Documentation

### Core Documentation

| File | Description |
|------|-------------|
| `quickstart.md` | Getting started guide for new users |
| `overview.md` | Introduction to Claude Code as an agentic coding tool |
| `setup.md` | Installation, authentication, and initial configuration |

### IDE & Editor Integration

| File | Description |
|------|-------------|
| `vs-code.md` | VS Code extension with inline diffs and @-mentions |
| `jetbrains.md` | Support for IntelliJ, PyCharm, WebStorm, and other JetBrains IDEs |
| `chrome.md` | Browser testing and automation (beta) |
| `slack.md` | Delegate tasks from Slack workspace |

### Deployment Options

| File | Description |
|------|-------------|
| `desktop.md` | Local or cloud execution options |
| `claude-code-on-the-web.md` | Asynchronous cloud infrastructure for web-based usage |
| `amazon-bedrock.md` | Integration with Amazon Bedrock |
| `google-vertex-ai.md` | Integration with Google Vertex AI |
| `microsoft-foundry.md` | Integration with Microsoft Foundry |

### Advanced Features

| File | Description |
|------|-------------|
| `plugins.md` | Create custom extensions to extend functionality |
| `skills.md` | Extend Claude's capabilities with custom skills |
| `hooks.md` | Customize behavior with shell commands triggered by events |
| `slash-commands.md` | Control Claude during sessions with `/` commands |
| `mcp.md` | Connect via Model Context Protocol (MCP) |
| `sub-agents.md` | Specialized AI agents for specific tasks |
| `memory.md` | Cross-session memory management |

### Configuration & Administration

| File | Description |
|------|-------------|
| `settings.md` | Global and project-level configuration options |
| `model-config.md` | Model aliases and selection settings |
| `terminal-config.md` | Optimize terminal setup for Claude Code |
| `network-config.md` | Proxy and mTLS configuration |
| `llm-gateway.md` | Gateway configuration for LLM requests |

### Enterprise Features

| File | Description |
|------|-------------|
| `iam.md` | Authentication and authorization (Identity & Access Management) |
| `analytics.md` | Usage insights and metrics tracking |
| `monitoring-usage.md` | OpenTelemetry integration for monitoring |
| `devcontainer.md` | Development containers for consistent team environments |
| `github-actions.md` | CI/CD integration with GitHub Actions |
| `gitlab-ci-cd.md` | CI/CD integration with GitLab |
| `third-party-integrations.md` | Enterprise deployment with third-party tools |

### Reference & Support

| File | Description |
|------|-------------|
| `cli-reference.md` | Complete command-line reference |
| `interactive-mode.md` | Keyboard shortcuts and interactive features |
| `troubleshooting.md` | Common issues and solutions |
| `changelog.md` | Version history and release notes |

### Additional Topics

| File | Description |
|------|-------------|
| `checkpointing.md` | Track and rewind edits with checkpoints |
| `sandboxing.md` | Filesystem and network isolation features |
| `security.md` | Security safeguards and best practices |
| `legal-and-compliance.md` | Legal and compliance information |
| `data-usage.md` | Anthropic's data handling policies |
| `costs.md` | Token usage optimization and cost management |
| `output-styles.md` | Output formatting beyond software engineering |
| `common-workflows.md` | Common usage patterns and workflows |

---

## Quick Reference by Use Case

### Getting Started
- `quickstart.md` → `setup.md` → `overview.md`

### IDE Users
- VS Code: `vs-code.md`
- JetBrains: `jetbrains.md`

### Cloud/Platform Deployment
- Web: `claude-code-on-the-web.md`
- AWS: `amazon-bedrock.md`
- GCP: `google-vertex-ai.md`
- Azure: `microsoft-foundry.md`

### Extending Claude Code
- Plugins: `plugins.md`
- Skills: `skills.md`
- Hooks: `hooks.md`
- MCP: `mcp.md`

### Enterprise Deployment
- `iam.md` → `analytics.md` → `monitoring-usage.md`
- CI/CD: `github-actions.md`, `gitlab-ci-cd.md`
- Containers: `devcontainer.md`

---

## URL Pattern

All documentation pages follow this URL pattern:
```
https://code.claude.com/docs/en/{filename}.md
```

Example: `https://code.claude.com/docs/en/quickstart.md`
