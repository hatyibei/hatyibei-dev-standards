---
name: ci-status
description: Check GitHub Actions run status and analyze root cause on failure
origin: self
allowed-tools: Bash(gh:*), Bash(curl:*), Read, WebFetch
argument-hint: workflow URL or run ID (defaults to the latest run)
---

Check GitHub Actions status and, if a run failed, analyze the cause.

## Input

- No args -> `gh run list --limit=3` to show the last 3 runs
- GitHub Actions URL -> extract the run ID from the URL for details
- run ID -> used directly

## Procedure

1. **Fetch status**
   ```bash
   gh run view [RUN_ID] --json status,conclusion,jobs,name,createdAt,updatedAt
   ```

2. **If in progress**
   - Show the current step
   - Estimated time remaining (based on past runs)

3. **On failure**
   ```bash
   gh run view [RUN_ID] --log-failed
   ```
   - Identify the failing job/step
   - Parse the error log
   - Classify the cause:
     - Test failure (unit / e2e)
     - Build error (TypeScript / lint)
     - Auth error (GCP / Firebase)
     - Deploy error (Cloud Build / Cloud Run)
     - Dependency error (npm install)

4. **On success**
   - Confirm whether deploy was included
   - `curl` the production URL to check reachability

## Output

```
## CI status

**Repository**: [owner/repo]
**Workflow**: [name]
**Status**: success / failed / running
**Duration**: [Xm Ys]
**Trigger**: push / PR #XX

### Failure details (if any)
| Job | Step | Error |
|--------|---------|--------|
| ...    | ...     | ...    |

**Cause**: ...
**Fix**: ...
```
