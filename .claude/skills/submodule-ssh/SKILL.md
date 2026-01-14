---
name: submodule-ssh
description: Push git submodule changes via SSH tunnel to desktop. Use when you need to push commits to a submodule repository that the sandbox proxy doesn't authorize.
allowed-tools: Bash, Read, Write
---

# Submodule SSH Operations

Push submodule changes through the desktop SSH relay when the sandbox proxy only authorizes the main repository.

## Push Submodule Changes

```bash
# 1. Copy changed files to desktop
cat submodules/<name>/<file> | ssh desktop "cat > /tmp/<file>"

# 2. Clone, apply changes, and push from desktop
ssh desktop "cd /tmp && rm -rf <name>-push 2>/dev/null; \
  git clone https://github.com/<owner>/<repo>.git <name>-push && \
  cd <name>-push && \
  git checkout -b <branch> && \
  cp /tmp/<file> . && \
  git add <file> && \
  git commit -m '<message>' && \
  git push -u origin <branch>"

# 3. Update local submodule to track remote
cd submodules/<name>
git fetch origin <branch>
git checkout <branch>
git reset --hard origin/<branch>

# 4. Update parent repo reference
cd ../..
git add submodules/<name>
git commit -m "Update <name> submodule"
git push
```

## Add Submodule (Read-Only)

Adding submodules works directly since HTTPS clone is allowed:

```bash
git submodule add https://github.com/<owner>/<repo>.git submodules/<name>
git submodule update --init --recursive
```

## Quick Reference

| Operation | Method |
|-----------|--------|
| Add submodule | `git submodule add <url>` (direct HTTPS) |
| Read submodule | Direct file access works |
| Push submodule | SSH to desktop → clone → push |
| Update parent | `git add submodules/<name>` after changes |
