# PR Merge Workflow

## Overview

This skill describes the required process for merging pull requests. PRs must have both passing CI and passing bugbot review on the **latest commit** before merging.

## Prerequisites

- GitHub CLI (`gh`) available at `/tmp/gh_2.83.2_linux_amd64/bin/gh` or in PATH
- Repository configured with CI workflow
- Bugbot (cursor[bot]) enabled on the repository

## Critical Requirements

**NEVER merge a PR without:**
1. CI passing on the latest commit
2. Bugbot review passing on the latest commit

## Checking CI Status

```bash
# Get recent workflow runs - check the commit SHA matches your latest
gh api repos/OWNER/REPO/actions/runs \
  --jq '.workflow_runs[:5] | .[] | "\(.id) \(.status) \(.conclusion // "running") \(.name) \(.head_sha[:7])"'
```

**Verify the commit SHA** - The `head_sha` in the output must match your latest pushed commit. If CI ran on an older commit, push again or wait for the new run.

## Checking Bugbot Review

```bash
# Get PR reviews - look for cursor[bot] review
gh pr view PR_NUMBER --repo OWNER/REPO --json reviews,comments

# Get detailed review comments
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments
```

**Verify the review commit** - Check the `commit` field in reviews matches your latest commit SHA:
```json
"commit": {"oid": "YOUR_LATEST_COMMIT_SHA"}
```

### Passing Review
A passing bugbot review shows:
```
"body": "✅ Bugbot reviewed your changes and found no bugs!"
```

### Triggering a Review
If no bugbot review appears within 5 minutes, add a comment to trigger one:
```bash
gh pr comment PR_NUMBER --repo OWNER/REPO --body "@cursor please review"
```

## Handling Bugbot Issues

When bugbot finds issues, **fix them autonomously** without asking the user unless you are genuinely unsure whether bugbot is correct.

### Fix Process

1. **Understand the issue** - Read bugbot's feedback carefully

2. **Write a regression test first** - Create a test that confirms the bug exists:
   ```bash
   # Add test to appropriate test file
   # Test should FAIL before fix, PASS after
   ```

3. **Fix the bug** - Make the minimal change to fix the issue

4. **Commit and push both**:
   ```bash
   git add -A && git commit -m "Fix: [description of bugbot issue]

   - Add regression test for [issue]
   - Fix [root cause]"
   git push
   ```

5. **Wait for new bugbot review** - Bugbot will automatically review the new commit. Wait up to 5 minutes.

6. **Verify the new review** - Ensure the review is on your NEW commit SHA, not the old one

### When to Ask the User

Only check with the user if:
- Bugbot's feedback seems incorrect or doesn't apply
- The fix would require significant architectural changes
- You're unsure whether the flagged code is intentional

## Merge Process

Once CI and bugbot both pass on the latest commit:

```bash
# Final verification
gh pr view PR_NUMBER --repo OWNER/REPO --json reviews,state

# Check latest commit SHA
git rev-parse HEAD

# Verify review is on latest commit (compare SHAs)

# Merge
gh pr merge PR_NUMBER --repo OWNER/REPO --merge --delete-branch
```

## Verification Checklist

Before merging, confirm ALL of the following:

- [ ] `gh api repos/OWNER/REPO/actions/runs` shows `success` for latest commit
- [ ] `gh pr view` shows bugbot review with "found no bugs"
- [ ] Review's `commit.oid` matches `git rev-parse HEAD`
- [ ] CI's `head_sha` matches `git rev-parse HEAD`

## Common Issues

### CI passed but on wrong commit
Push again or wait - CI will re-run on new commits automatically.

### Bugbot reviewed old commit
Add `@cursor please review` comment to trigger new review on latest commit.

### Bugbot flags intentional behavior
Reply to the review explaining why the code is intentional, then proceed if you're confident. Document the decision.

## Example Session

```bash
# 1. Check current commit
git rev-parse HEAD  # abc1234

# 2. Check CI status
gh api repos/owner/repo/actions/runs --jq '.workflow_runs[0] | "\(.conclusion) \(.head_sha[:7])"'
# success abc1234  ✓ matches

# 3. Check bugbot review
gh pr view 24 --repo owner/repo --json reviews
# Look for: "commit":{"oid":"abc1234..."} and "found no bugs"

# 4. Merge if both pass
gh pr merge 24 --repo owner/repo --merge --delete-branch
```
