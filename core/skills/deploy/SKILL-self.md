---
name: deploy
description: Automate deploy + verification for Cloud Run / Firebase targets
origin: self
allowed-tools: Bash(gcloud:*), Bash(gh:*), Bash(git:*), Bash(curl:*), Read, Glob, Grep
argument-hint: "target (e.g. cloud-run, firebase, auto) default: auto"
---

Deploy the project and verify the change is live in production.

## Target detection

Detect from the current directory:
- `cloudbuild.yaml` present → Cloud Run deploy
- `firebase.json` present → Firebase deploy
- Explicit arg `cloud-run` / `firebase` overrides detection

## Cloud Run flow

1. **Pre-checks**
   - `git status` to confirm nothing is uncommitted (warn if dirty)
   - `npm run typecheck && npm run lint` to catch build errors early

2. **Submit the build**
   ```bash
   gcloud builds submit --config=cloudbuild.yaml --project=scale-webcoding-service
   ```

3. **Watch the build**
   - Poll `gcloud builds list --limit=1 --project=scale-webcoding-service` at 30 s intervals
   - Stop when status is SUCCESS or FAILURE (max 10 minutes)

4. **Verify live**
   - `curl -s -o /dev/null -w "%{http_code}" https://gen-diag.com/` → expect 200

5. **If deploy is triggered via GitHub Actions instead**
   - `gh run list --limit=1` for the latest run
   - `gh run watch` until completion

## Firebase flow

1. `firebase deploy --only hosting`
2. `curl -s https://gen-diag.com/` to confirm

## Result report

```
## Deploy result

**Project**: [project name]
**Mode**: Cloud Run / Firebase
**Status**: success / failure
**Production URL**: https://gen-diag.com/
**Response**: HTTP [status code]
**Duration**: [Xm Ys]

### Failure detail (if applicable)
- Error log: ...
- Probable cause: ...
- Suggested fix: ...
```
