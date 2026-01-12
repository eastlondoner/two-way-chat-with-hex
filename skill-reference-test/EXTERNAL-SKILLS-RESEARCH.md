# External Skills Reference Research

## Summary

Claude Code **does not natively support remote/HTTP skill references**, but there are two main approaches:

1. **Symlinks** - Link to external directories on the filesystem
2. **Plugins** - Package skills in plugins for distribution via GitHub/marketplaces

## Tested Approach: Symlinks

### Setup

1. Create an external skills repository/directory:
   ```bash
   mkdir -p /path/to/external-skills-repo/skills/my-skill
   ```

2. Create the skill in the external location:
   ```bash
   cat > /path/to/external-skills-repo/skills/my-skill/SKILL.md << 'EOF'
   ---
   name: my-skill
   description: Description of what this skill does
   ---
   # Skill Content
   EOF
   ```

3. Symlink into your project:
   ```bash
   mkdir -p .claude/skills
   ln -s /path/to/external-skills-repo/skills/my-skill .claude/skills/my-skill
   ```

### Verification

Run `/skills` in Claude Code to see the symlinked skill listed alongside local skills.

## Plugin-Based Distribution (Recommended for Teams)

### Plugin Structure with Skills

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Required manifest
├── skills/                   # Skills directory
│   ├── my-skill/
│   │   └── SKILL.md
│   └── another-skill/
│       └── SKILL.md
├── commands/                 # Optional: slash commands
└── hooks/                    # Optional: hooks
```

### Plugin Manifest (`plugin.json`)

```json
{
  "name": "my-skills-plugin",
  "version": "1.0.0",
  "description": "Skills for my team",
  "author": { "name": "Your Name" },
  "repository": "https://github.com/org/skills-plugin"
}
```

### Distribution Methods

| Method | Command | Use Case |
|--------|---------|----------|
| **GitHub repo** | `/plugin marketplace add org/repo` | Public/private sharing |
| **Local path** | `claude --plugin-dir ./my-plugin` | Development/testing |
| **Git URL** | Any git host | GitLab, self-hosted |

### Installation Flow

```bash
# 1. Add marketplace (one-time)
/plugin marketplace add your-org/plugins-repo

# 2. Install plugin (includes all skills)
/plugin install my-plugin@your-org

# Skills become automatically available
```

### Publishing a Plugin Marketplace

Create `.claude-plugin/marketplace.json` in your repo:

```json
{
  "name": "my-marketplace",
  "plugins": [
    {
      "name": "code-skills",
      "source": "./plugins/code-skills",
      "description": "Code review and quality skills"
    }
  ]
}
```

### Benefits of Plugin Distribution

- **Version Control** - Semantic versioning for skills
- **Single Install** - One command installs all skills
- **Namespace Isolation** - Plugin commands prefixed to avoid conflicts
- **Bundled Components** - Skills + commands + hooks together
- **Marketplace Discovery** - Users browse available plugins

## How Skills Are Discovered

Claude Code searches these locations (in order):

| Location | Scope | Example Path |
|----------|-------|--------------|
| Project skills | Current project | `.claude/skills/` |
| User skills | Global/personal | `~/.claude/skills/` |
| Plugin skills | From plugins | Auto-discovered |

Skills are auto-loaded based on their `description` field matching the current task context.

## Alternative Approaches

### 1. Symlinks (Tested - Works)
- **Pros**: Simple, transparent, version-controllable
- **Cons**: Requires external path to exist on filesystem

### 2. Git Submodules
```bash
git submodule add https://github.com/org/skills-repo .claude/external-skills
ln -s .claude/external-skills/skills/my-skill .claude/skills/my-skill
```

### 3. Clone and Copy (Manual Sync)
```bash
git clone https://github.com/org/skills-repo /tmp/skills
cp -r /tmp/skills/my-skill .claude/skills/
```

### 4. Plugin Marketplaces (Documented but Limited)
```bash
/plugin install org/skills-repo
```
Note: Marketplace support may be limited to official sources.

## Skill Structure

Each skill is a directory containing at minimum a `SKILL.md` file:

```
my-skill/
├── SKILL.md          # Required: YAML frontmatter + markdown content
├── scripts/          # Optional: Helper scripts
└── references/       # Optional: Additional documentation
```

### SKILL.md Format

```yaml
---
name: skill-name
description: Brief description (max 200 chars) - used for auto-triggering
version: 1.0.0           # Optional
allowed-tools:           # Optional: Restrict tools
  - bash
  - read
model: claude-opus-4-5-20251101  # Optional: Override model
context: fork            # Optional: Run in isolated context
---

# Skill Title

Instructions for Claude when this skill is active.
```

## Test Results

- **External skill path**: `/home/user/claude/external-skills-repo/skills/test-external-skill/`
- **Symlink location**: `/home/user/claude/skill-reference-test/.claude/skills/test-external-skill`
- **Result**: Skill loaded successfully, instructions followed correctly

## Recommendations

1. **For shared skills across projects**: Use symlinks pointing to a central skills repository
2. **For team skills**: Use git submodules to version-control external skill references
3. **For personal skills**: Place in `~/.claude/skills/` for global availability
