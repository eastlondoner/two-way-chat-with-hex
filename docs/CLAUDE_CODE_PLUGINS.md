---
sources:
  - https://code.claude.com/docs/en/plugins.md
  - https://code.claude.com/docs/en/plugins-reference.md
  - https://code.claude.com/docs/en/hooks.md
  - https://code.claude.com/docs/en/hooks-guide.md
  - https://code.claude.com/docs/en/skills.md
  - https://code.claude.com/docs/en/sub-agents.md
  - https://code.claude.com/docs/en/slash-commands.md
  - https://code.claude.com/docs/en/mcp.md
  - https://code.claude.com/docs/en/discover-plugins.md
  - https://code.claude.com/docs/en/plugin-marketplaces.md
  - https://code.claude.com/docs/en/output-styles.md
  - https://code.claude.com/docs/en/settings.md
  - https://code.claude.com/docs/en/memory.md
  - https://code.claude.com/docs/en/headless.md
  - https://code.claude.com/docs/llms.txt
  - https://github.com/anthropics/claude-code/tree/main/plugins
---

# Claude Code Plugins Guide

Claude Code plugins are modular extensions that enhance Claude Code with custom commands, specialized agents, skills, hooks, and MCP server integrations. They enable you to tailor Claude Code to specific development workflows and share these customizations across projects and teams.

## Table of Contents

- [Overview](#overview)
- [When to Use Plugins vs Standalone Configuration](#when-to-use-plugins-vs-standalone-configuration)
- [Plugin Structure](#plugin-structure)
- [Plugin Components](#plugin-components)
  - [Slash Commands](#1-slash-commands)
  - [Subagents](#2-subagents)
  - [Skills](#3-skills)
  - [Hooks](#4-hooks)
  - [MCP Servers](#5-mcp-servers)
  - [Output Styles](#6-output-styles)
- [Creating Your First Plugin](#creating-your-first-plugin)
- [Installing and Managing Plugins](#installing-and-managing-plugins)
- [Plugin Marketplaces](#plugin-marketplaces)
- [Testing and Debugging](#testing-and-debugging)
- [Best Practices](#best-practices)
- [Official Example Plugins](#official-example-plugins)

---

## Overview

Claude Code plugins bundle together related functionality into distributable packages. A plugin can contain any combination of:

| Component | Purpose | User Invocation |
|-----------|---------|-----------------|
| **Slash Commands** | Custom shortcuts for operations | User types `/command` |
| **Subagents** | Specialized AI agents for specific tasks | User delegates via `/agent:name` or Claude spawns |
| **Skills** | Model-invoked knowledge/capabilities | Claude autonomously uses when relevant |
| **Hooks** | Event handlers for automation | Triggered by system events |
| **MCP Servers** | External tool/service integrations | Claude uses as tools |
| **Output Styles** | Customize Claude's response behavior | User sets via settings |

---

## When to Use Plugins vs Standalone Configuration

### Use Standalone Configuration When:
- Customizing Claude Code for a single project
- Configuration is personal and doesn't need sharing
- Experimenting with slash commands or hooks before packaging
- You want short command names like `/hello` or `/review`

### Use Plugins When:
- Sharing functionality with your team or community
- Need the same slash commands/agents across multiple projects
- Want version control and easy updates
- Distributing through a marketplace
- Okay with namespaced commands like `/my-plugin:hello`

---

## Plugin Structure

Every plugin follows this directory structure:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata (required)
├── commands/                # Slash commands (optional)
│   ├── my-command.md
│   └── another-command.md
├── agents/                  # Specialized agents (optional)
│   ├── analyzer.md
│   └── reviewer.md
├── skills/                  # Agent Skills (optional)
│   └── my-skill/
│       └── SKILL.md
├── hooks/                   # Event handlers (optional)
│   ├── hooks.json
│   └── my-hook-handler.py
├── mcp-servers.json         # MCP server config (optional)
├── output-style.md          # Output style (optional)
└── README.md                # Plugin documentation
```

### Plugin Manifest (`plugin.json`)

The manifest file at `.claude-plugin/plugin.json` is **required** and defines plugin metadata:

```json
{
  "name": "my-plugin",
  "description": "Description shown in plugin manager",
  "version": "1.0.0",
  "author": {
    "name": "Your Name",
    "email": "you@example.com"
  }
}
```

| Field | Description |
|-------|-------------|
| `name` | Unique identifier and slash command namespace. Commands are prefixed with this (e.g., `/my-plugin:hello`) |
| `description` | Shown when browsing or installing plugins |
| `version` | Track releases using [semantic versioning](https://semver.org/) |
| `author` | Optional. Helpful for attribution |

---

## Plugin Components

### 1. Slash Commands

Slash commands are user-initiated actions defined as Markdown files in the `commands/` directory.

#### Command File Format

```markdown
---
description: Brief description shown in /help
argument-hint: Optional hint for arguments
allowed-tools: ["Read", "Write", "Bash", "Grep"]
---

# Command Title

Instructions for Claude when this command is invoked.

## Context

You can include dynamic context using backtick-bang syntax:
- Current git status: !`git status`
- File contents: !`cat package.json`

## Your task

$ARGUMENTS

Based on the above context, perform the requested action.
```

#### Frontmatter Options

| Field | Description |
|-------|-------------|
| `description` | Shown in `/help` and autocomplete |
| `argument-hint` | Placeholder text for arguments |
| `allowed-tools` | Restrict which tools Claude can use |

#### Dynamic Content Syntax

| Syntax | Description |
|--------|-------------|
| `$ARGUMENTS` | User-provided arguments |
| `!`\`command\` | Execute command and include output |

#### Example: Git Commit Command

```markdown
---
description: Create a git commit
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
---

## Context

- Current git status: !`git status`
- Current git diff: !`git diff HEAD`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the above changes, create a single git commit. Stage and commit using a clear, conventional commit message.
```

When installed as `commit-commands` plugin, invoke with: `/commit-commands:commit`

---

### 2. Subagents

Subagents are specialized AI agents configured in the `agents/` directory. They have custom prompts, restricted tool access, and can use different models.

#### Agent File Format

```markdown
---
name: code-architect
description: Designs feature architectures
tools: Glob, Grep, LS, Read, WebFetch, TodoWrite
model: sonnet
color: green
---

You are a senior software architect who delivers comprehensive, actionable architecture blueprints.

## Core Process

1. **Codebase Pattern Analysis**: Extract existing patterns and conventions
2. **Architecture Design**: Design complete feature architecture
3. **Implementation Blueprint**: Specify files to create/modify

## Output Format

Deliver a decisive, complete architecture blueprint including:
- Patterns & conventions found
- Architecture decision with rationale
- Component design with file paths
- Implementation phases as checklist
```

#### Frontmatter Options

| Field | Description |
|-------|-------------|
| `name` | Agent identifier (used in `/agent:name`) |
| `description` | Shown when listing agents |
| `tools` | Comma-separated list of allowed tools |
| `model` | Model to use: `opus`, `sonnet`, `haiku` |
| `color` | Output color: `green`, `blue`, `yellow`, `red`, `cyan`, `magenta` |

#### Available Tools for Agents

Common tools include:
- `Read`, `Write`, `Edit`, `MultiEdit` - File operations
- `Bash`, `BashOutput` - Shell commands
- `Glob`, `Grep`, `LS` - File search
- `WebFetch`, `WebSearch` - Web access
- `TodoWrite` - Task tracking
- `Task` - Spawn sub-tasks
- `Skill` - Load skills
- `AskUserQuestion` - User interaction
- `NotebookRead`, `NotebookEdit` - Jupyter notebooks

#### Using Agents

```bash
# Delegate to an agent directly
/agent:code-architect "Design the authentication system"

# From a command, spawn agents as tasks
Use the Task tool to spawn code-architect for architecture analysis
```

---

### 3. Skills

Skills are model-invoked capabilities that Claude autonomously uses based on context. Unlike commands (user-initiated) or agents (delegated), skills are automatically triggered when relevant.

#### Skill Structure

```
skills/
└── frontend-design/
    └── SKILL.md
```

#### Skill File Format

```markdown
---
name: frontend-design
description: Create distinctive frontend interfaces. Use when building web components, pages, or applications.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces.

## Design Thinking

Before coding, understand context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve?
- **Tone**: Pick an extreme: brutally minimal, maximalist, retro-futuristic, etc.
- **Differentiation**: What makes this UNFORGETTABLE?

## Guidelines

- **Typography**: Choose distinctive fonts, avoid Arial and Inter
- **Color**: Dominant colors with sharp accents
- **Motion**: CSS animations for effects and micro-interactions
- **Backgrounds**: Create atmosphere with gradients, patterns, textures

NEVER use generic AI aesthetics like purple gradients on white backgrounds.
```

#### When Skills Activate

Claude automatically loads skills when:
- The task matches the skill's description
- The skill's domain is relevant to current work
- Claude determines the knowledge would be helpful

Skills are **not** invoked by users directly—they're context that Claude uses autonomously.

---

### 4. Hooks

Hooks are event handlers that execute at specific points in Claude Code's lifecycle. They enable automated actions like validation, notifications, and context injection.

#### Hook Types

| Hook | Trigger | Use Cases |
|------|---------|-----------|
| `PreToolUse` | Before a tool executes | Validate, transform, or block tool calls |
| `PostToolUse` | After a tool executes | Log, notify, or react to tool results |
| `Notification` | On notifications | Custom notification handling |
| `Stop` | When Claude tries to exit | Continue loops, cleanup, generate summaries |
| `SessionStart` | When session begins | Inject context, setup environment |
| `PreCompact` | Before context compaction | Preserve important information |

#### hooks.json Format

```json
{
  "description": "Security reminder hook",
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/security_check.py"
          }
        ],
        "matcher": "Edit|Write|MultiEdit"
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

#### Hook Configuration

| Field | Description |
|-------|-------------|
| `type` | Always `"command"` |
| `command` | Script to execute. Use `${CLAUDE_PLUGIN_ROOT}` for plugin directory |
| `matcher` | Regex pattern to filter which tools trigger the hook (PreToolUse/PostToolUse only) |

#### Hook Input (stdin)

Hooks receive JSON input via stdin:

```json
{
  "session_id": "abc123",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.py",
    "content": "..."
  }
}
```

#### Hook Exit Codes

| Exit Code | Behavior |
|-----------|----------|
| `0` | Allow operation to proceed |
| `2` | Block operation (PreToolUse) or re-inject prompt (Stop) |
| Other | Allow operation, log error |

#### Example: Security Reminder Hook (Python)

```python
#!/usr/bin/env python3
import json
import sys

SECURITY_PATTERNS = [
    {"substrings": ["eval("], "reminder": "⚠️ eval() is a security risk"},
    {"substrings": ["os.system"], "reminder": "⚠️ os.system can lead to injection"},
]

def main():
    input_data = json.loads(sys.stdin.read())
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    
    if tool_name not in ["Edit", "Write", "MultiEdit"]:
        sys.exit(0)  # Allow non-file tools
    
    content = tool_input.get("content", "") or tool_input.get("new_string", "")
    
    for pattern in SECURITY_PATTERNS:
        for substring in pattern["substrings"]:
            if substring in content:
                print(pattern["reminder"], file=sys.stderr)
                sys.exit(2)  # Block operation
    
    sys.exit(0)  # Allow

if __name__ == "__main__":
    main()
```

#### Example: Stop Hook for Iteration Loops

```bash
#!/bin/bash
# stop-hook.sh - Continue ralph loops

STATE_FILE=".ralph/loop_state.json"

if [ -f "$STATE_FILE" ]; then
    CURRENT=$(jq -r '.current_iteration' "$STATE_FILE")
    MAX=$(jq -r '.max_iterations' "$STATE_FILE")
    
    if [ "$CURRENT" -lt "$MAX" ]; then
        # Increment and continue
        jq ".current_iteration = $((CURRENT + 1))" "$STATE_FILE" > tmp && mv tmp "$STATE_FILE"
        echo "Continue iteration $((CURRENT + 1)) of $MAX"
        exit 2  # Re-inject prompt
    fi
fi

exit 0  # Allow exit
```

---

### 5. MCP Servers

MCP (Model Context Protocol) servers integrate external tools and services into Claude Code.

#### mcp-servers.json Format

```json
{
  "mcpServers": {
    "database": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://..."
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/allowed/path"]
    },
    "custom-server": {
      "command": "python",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/my_server.py"]
    }
  }
}
```

#### Available MCP Servers

Popular community MCP servers:
- `@modelcontextprotocol/server-filesystem` - File system access
- `@modelcontextprotocol/server-postgres` - PostgreSQL queries
- `@modelcontextprotocol/server-sqlite` - SQLite database
- `@modelcontextprotocol/server-github` - GitHub API
- `@modelcontextprotocol/server-slack` - Slack integration

---

### 6. Output Styles

Output styles customize Claude's response behavior. Define in `output-style.md`:

```markdown
---
name: explanatory
description: Adds educational insights about implementation choices
---

When responding:
1. Explain WHY you're making each choice
2. Reference relevant codebase patterns
3. Suggest alternative approaches when appropriate
4. Include learning resources for complex topics
```

Output styles can also be injected via `SessionStart` hooks.

---

## Creating Your First Plugin

### Quick Start

1. **Create the plugin directory**:
```bash
mkdir -p my-first-plugin/.claude-plugin
mkdir -p my-first-plugin/commands
```

2. **Create the plugin manifest**:
```bash
cat > my-first-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "my-first-plugin",
  "description": "My first Claude Code plugin",
  "version": "1.0.0"
}
EOF
```

3. **Add a slash command**:
```bash
cat > my-first-plugin/commands/hello.md << 'EOF'
---
description: Say hello with context
---

Say hello to the user and briefly describe what you see in their project.

Project files: !`ls -la`
EOF
```

4. **Test your plugin**:
```bash
# Add local marketplace
/plugin marketplace add ./

# Install plugin
/plugin install my-first-plugin@local
```

5. **Use your command**:
```bash
/my-first-plugin:hello
```

---

## Installing and Managing Plugins

### Via Interactive Menu (Recommended)

```bash
/plugin                    # Open plugin management interface
```

### Via Direct Commands

```bash
# Add a marketplace
/plugin marketplace add your-org/claude-plugins

# Install a plugin
/plugin install formatter@your-org

# Enable/disable
/plugin enable plugin-name@marketplace
/plugin disable plugin-name@marketplace

# Uninstall
/plugin uninstall plugin-name@marketplace
```

### Local Development

```bash
# Add local directory as marketplace
/plugin marketplace add ./local-plugins

# Install local plugin
/plugin install my-plugin@local-plugins

# After changes, reinstall
/plugin uninstall my-plugin@local-plugins
/plugin install my-plugin@local-plugins
```

---

## Plugin Marketplaces

Marketplaces are catalogs of plugins. They can be:

1. **GitHub repositories**: `your-org/plugin-marketplace`
2. **Local directories**: `./my-marketplace`
3. **Remote URLs**: `https://example.com/marketplace`

### Marketplace Structure

```
my-marketplace/
├── plugin-a/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── commands/
├── plugin-b/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── agents/
└── README.md
```

### Creating a Marketplace

1. Create a directory with multiple plugins
2. Each plugin in its own subdirectory
3. Host on GitHub or serve locally

---

## Testing and Debugging

### Test Checklist

- [ ] Plugin manifest is valid JSON
- [ ] All command files have valid frontmatter
- [ ] Hooks have correct permissions (`chmod +x`)
- [ ] Hook scripts handle errors gracefully
- [ ] Commands work with various arguments

### Debug Techniques

1. **Check structure**: Ensure directories are at plugin root, not inside `.claude-plugin/`
2. **Test components individually**: Check each command, agent, hook separately
3. **Review hook logs**: Many hooks write to `/tmp/` for debugging
4. **Validate JSON**: Use `jq` to verify JSON files

### Common Issues

| Issue | Solution |
|-------|----------|
| Command not found | Check `plugin.json` name matches directory |
| Hook not triggering | Verify `hooks.json` matcher patterns |
| Agent errors | Check `tools` list includes required tools |
| MCP server fails | Verify command/args and environment variables |

---

## Best Practices

### Plugin Design

1. **Single responsibility**: Each plugin should do one thing well
2. **Progressive disclosure**: Skills should be lean with references to examples
3. **Defensive hooks**: Always handle errors, never crash
4. **Document everything**: Include README with installation and usage

### Command Design

1. **Clear descriptions**: Help users understand what commands do
2. **Restricted tools**: Only allow tools the command needs
3. **Dynamic context**: Use `!`\`command\` to include relevant info
4. **Helpful output**: Guide Claude to produce useful responses

### Hook Design

1. **Fast execution**: Hooks run synchronously, keep them quick
2. **Fail gracefully**: Exit 0 on errors to avoid blocking operations
3. **Session-scoped state**: Use session ID for per-session state files
4. **Cleanup old state**: Periodically remove old state files

### Skill Design

1. **Clear trigger descriptions**: Help Claude know when to use the skill
2. **Actionable guidance**: Provide specific instructions, not just theory
3. **Examples**: Include examples of good and bad approaches
4. **Stay focused**: Keep skills targeted to specific domains

---

## Official Example Plugins

The [claude-code/plugins](https://github.com/anthropics/claude-code/tree/main/plugins) repository contains official examples:

| Plugin | Components | Description |
|--------|------------|-------------|
| **agent-sdk-dev** | Command, 2 Agents | Development kit for Claude Agent SDK |
| **claude-opus-4-5-migration** | Skill | Migrate to Opus 4.5 model |
| **code-review** | Command, 5 Agents | PR review with confidence scoring |
| **commit-commands** | 3 Commands | Git workflow automation |
| **explanatory-output-style** | Hook | Educational output style |
| **feature-dev** | Command, 3 Agents | 7-phase feature development workflow |
| **frontend-design** | Skill | Distinctive UI design guidance |
| **hookify** | 4 Commands, Agent, Skill | Create custom behavior prevention hooks |
| **learning-output-style** | Hook | Interactive learning mode |
| **plugin-dev** | Command, 3 Agents, 7 Skills | Plugin development toolkit |
| **pr-review-toolkit** | Command, 6 Agents | Comprehensive PR review |
| **ralph-wiggum** | 2 Commands, Hook | Self-referential AI loops |
| **security-guidance** | Hook | Security pattern warnings |

### Study These Patterns

- **code-review**: Multiple parallel agents with confidence aggregation
- **feature-dev**: Multi-phase workflow with specialized agents
- **hookify**: Meta-plugin that creates hooks dynamically
- **security-guidance**: PreToolUse hook with pattern matching
- **ralph-wiggum**: Stop hook for iteration loops

---

## Quick Reference

### File Locations

| Component | Location | Format |
|-----------|----------|--------|
| Manifest | `.claude-plugin/plugin.json` | JSON |
| Commands | `commands/*.md` | Markdown |
| Agents | `agents/*.md` | Markdown |
| Skills | `skills/*/SKILL.md` | Markdown |
| Hooks | `hooks/hooks.json` | JSON |
| MCP Servers | `mcp-servers.json` | JSON |
| Output Style | `output-style.md` | Markdown |

### Environment Variables in Hooks

| Variable | Description |
|----------|-------------|
| `CLAUDE_PLUGIN_ROOT` | Absolute path to plugin directory |
| `ENABLE_SECURITY_REMINDER` | Custom env vars from settings |

### Hook Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Proceed normally |
| `2` | Block/re-inject |
| Other | Proceed, log error |

---

## Further Reading

- [Official Plugins Documentation](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills Documentation](https://code.claude.com/docs/en/skills)
- [Subagents Documentation](https://code.claude.com/docs/en/subagents)
- [MCP Documentation](https://code.claude.com/docs/en/mcp)
- [Example Plugins on GitHub](https://github.com/anthropics/claude-code/tree/main/plugins)
