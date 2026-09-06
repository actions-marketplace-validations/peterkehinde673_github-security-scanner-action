# GitHub Security Scanner Action

Run [GitHub Security Scanner](https://github-security-scanner.onrender.com/) from GitHub Actions.

## Quick start

Create `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - name: Scan repository
        uses: peterkehinde673/github-security-scanner-action@v1
```

The action defaults to the repository that triggered the workflow and calls the public scanner service. No repository checkout is required.

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `repository` | current repository | HTTPS GitHub repository URL to scan |
| `scanner-url` | `https://github-security-scanner.onrender.com` | Scanner API base URL |
| `fail-on` | `high` | Severity threshold: `critical`, `high`, `medium`, or `low` |

## Security behavior

- Only HTTPS GitHub repository URLs are accepted.
- The action does not execute code from the scanned repository.
- The workflow requests only `contents: read` permission in the example.
- Scanner responses are validated before the workflow succeeds.
- Findings at or above the configured severity threshold fail the workflow.

## Important limitation

The current action sends a public repository URL to the scanner service. It is intended for public repositories and does not request or handle private-repository credentials. Do not use it for private repositories until private scanning support is explicitly added.

## Development

This repository contains the thin GitHub Actions integration. The scanning engine remains in the main [GitHub Security Scanner](https://github.com/peterkehinde673/GitHub-Security-Scanner) repository.
