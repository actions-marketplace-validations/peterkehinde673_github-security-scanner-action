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

payload=$(printf '%s' "$repository" | python3 -c 'import json,sys; print(json.dumps({"targetUrl":sys.stdin.read()}))')

response=$(curl --fail-with-body --silent --show-error --location \
  --connect-timeout 10 --max-time 90 \
  -H 'Content-Type: application/json' \
  -X POST "${scanner_url}/api/scan" \
  --data "$payload") || {
    echo "::error::GitHub Security Scanner request failed"
    exit 1
  }

python3 - "$response" "$fail_on" <<'PY'
import json, sys

raw, fail_on = sys.argv[1:]
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print('::error::Scanner returned invalid JSON')
    sys.exit(1)

report = data.get('report', data)
score = report.get('score')
findings = report.get('findings') or []

if not isinstance(score, (int, float)):
    print('::error::Scanner response did not contain a valid score')
    sys.exit(1)

severity_rank = {'low': 1, 'medium': 2, 'high': 3, 'critical': 4}
threshold = severity_rank[fail_on]
counts = {key: 0 for key in severity_rank}

for finding in findings:
    severity = str(finding.get('severity', '')).lower()
    if severity in counts:
        counts[severity] += 1

print(f'GitHub Security Scanner score: {score}/100')
print('Findings: ' + ', '.join(f'{k}={counts[k]}' for k in ('critical','high','medium','low')))

if counts['critical'] or (threshold <= 3 and counts['high']) or (threshold <= 2 and counts['medium']) or (threshold <= 1 and counts['low']):
    print(f'::error::Security findings meet or exceed fail-on={fail_on}')
    sys.exit(1)
PY
