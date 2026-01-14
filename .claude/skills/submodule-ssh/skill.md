# Submodule SSH Operations

Work with git submodules via SSH tunnel to desktop.

## Setup SSH Tunnel

The sandbox proxy only authorizes the main repo. Use the desktop SSH relay for submodule operations.

```bash
# Copy file to desktop
cat <file> | ssh desktop "cat > /tmp/<file>"

# Run commands on desktop
ssh desktop "<commands>"
```

## Clone/Checkout Submodule

```bash
# Add submodule (HTTPS works for read-only)
git submodule add https://github.com/<owner>/<repo>.git submodules/<name>

# Initialize and update
git submodule update --init --recursive
```

## Push Submodule Changes

The sandbox cannot push to repos other than the main one. Use desktop:

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

# 4. Update parent repo
cd ../..
git add submodules/<name>
git commit -m "Update <name> submodule"
git push
```

## Quick Reference

| Operation | Method |
|-----------|--------|
| Add submodule | `git submodule add <url>` (direct) |
| Read submodule | Direct file access works |
| Push submodule | SSH to desktop, clone, push there |
| Update parent ref | `git add submodules/<name>` after submodule changes |
