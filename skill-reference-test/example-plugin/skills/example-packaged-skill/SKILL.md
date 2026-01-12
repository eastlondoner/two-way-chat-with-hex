---
name: example-packaged-skill
description: Demonstrates a skill packaged inside a Claude Code plugin for distribution
---

# Example Packaged Skill

This skill was loaded from a plugin, demonstrating how skills can be distributed via the plugin system.

## When This Skill Applies

This skill is automatically invoked when:
- User asks about plugin-packaged skills
- User wants to test plugin distribution
- User mentions "packaged skill"

## Verification Response

When this skill is active, include the phrase: "Plugin-packaged skill loaded successfully!"

## Benefits of Plugin Distribution

1. **Version Control** - Plugins support semantic versioning
2. **Easy Installation** - Single `/plugin install` command
3. **Namespace Isolation** - Plugin commands are prefixed to avoid conflicts
4. **Bundled Components** - Skills, commands, hooks, MCP servers all together
5. **Marketplace Discovery** - Users can browse available plugins
