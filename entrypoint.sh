#!/usr/bin/env bash
set -euo pipefail

scanner_url="${INPUT_SCANNER_URL%/}"
repository="${INPUT_REPOSITORY:-https://github.com/${GITHUB_REPOSITORY}}"
fail_on="${INPUT_FAIL_ON:-high}"

case "$fail_on" in
  critical|high|medium|low) ;;
  *) echo "::error::Invalid fail-on value: $fail_on"; exit 2 ;;
esac

case "$repository" in
  https://github.com/*/*|https://www.github.com/*/*) ;;
  *) echo "::error::repository must be a GitHub HTTPS repository URL"; exit 2 ;;
esac

repo_full_name=$(printf '%s' "$repository" | python3 -c 'import sys,urllib.parse; u=urllib.parse.urlparse(sys.stdin.read().strip()); p=u.path.strip("/").removesuffix(".git"); parts=p.split("/"); print("/".join(parts[:2]) if len(parts)==2 else "")')
if [[ -z "$repo_full_name" ]]; then
  echo "::error::Invalid GitHub repository URL"
  exit 2
fi

repo_info=$(curl --fail-with-body --silent --show-error --location \
  --connect-timeout 10 --max-time 30 \
  "${scanner_url}/api/github/repo-info?repo=${repo_full_name}") || {
    echo "::error::Could not retrieve repository metadata from GitHub Security Scanner"
    exit 1
  }

branch=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("defaultBranch") or "main")' "$repo_info")

fetch_payload=$(python3 - "$repo_full_name" "$branch" <<'PY'
import json, sys
print(json.dumps({"repoFullName": sys.argv[1], "branch": sys.argv[2], "maxFiles": 40}))
PY
)

files_response=$(curl --fail-with-body --silent --show-error --location \
  --connect-timeout 10 --max-time 120 \
  -H 'Content-Type: application/json' \
  -X POST "${scanner_url}/api/github/fetch-files" \
  --data "$fetch_payload") || {
    echo "::error::Could not fetch repository files from GitHub Security Scanner"
    exit 1
  }

scan_payload=$(python3 - "$files_response" "$repository" <<'PY'
import json, sys

data = json.loads(sys.argv[1])
files = data.get("files")
if not isinstance(files, list) or not files:
    raise SystemExit("No scan-compatible files were returned")

payload = {
    "files": files,
    "targetName": data.get("repo") or sys.argv[2],
    "targetType": "GITHUB_REPO",
    "targetUrl": sys.argv[2],
    "coverage": data.get("coverage"),
}
print(json.dumps(payload, separators=(",", ":")))
PY
)

response=$(curl --fail-with-body --silent --show-error --location \
  --connect-timeout 10 --max-time 120 \
  -H 'Content-Type: application/json' \
  -X POST "${scanner_url}/api/scan" \
  --data "$scan_payload") || {
    echo "::error::Security scan request failed"
    exit 1
  }

python3 - "$response" "$fail_on" <<'PY'
import json, sys, os

raw, fail_on = sys.argv[1:]
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print('::error::Scanner returned invalid JSON')
    sys.exit(1)

metrics = data.get('metrics')
score = metrics.get('score') if isinstance(metrics, dict) else data.get('score')
findings = data.get('findings') or []

if not isinstance(score, (int, float)) or isinstance(score, bool):
    print('::error::Scanner response did not contain a valid score')
    sys.exit(1)
if not isinstance(findings, list):
    print('::error::Scanner response did not contain a valid findings list')
    sys.exit(1)

severity_rank = {'low': 1, 'medium': 2, 'high': 3, 'critical': 4}
threshold = severity_rank[fail_on]
counts = {key: 0 for key in severity_rank}

for finding in findings:
    if isinstance(finding, dict):
        severity = str(finding.get('severity', '')).lower()
        if severity in counts:
            counts[severity] += 1

with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as out:
    out.write(f"score={score}\n")
    out.write(f"findings={len(findings)}\n")

print(f'GitHub Security Scanner score: {score}/100')
print('Findings: ' + ', '.join(f'{k}={counts[k]}' for k in ('critical','high','medium','low')))

should_fail = any(counts[level] > 0 for level, rank in severity_rank.items() if rank >= threshold)
if should_fail:
    print(f'::error::Security findings meet or exceed fail-on={fail_on}')
    sys.exit(1)
PY
