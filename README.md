# GitHub Security Scanner Action

[![Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-GitHub%20Security%20Scanner-blue?logo=github)](https://github.com/marketplace/actions/github-security-scanner)
[![Action self-test](https://github.com/peterkehinde673/github-security-scanner-action/actions/workflows/self-test.yml/badge.svg)](https://github.com/peterkehinde673/github-security-scanner-action/actions/workflows/self-test.yml)

**Scan a public GitHub repository for security risks directly from GitHub Actions.**

The action connects your workflow to [GitHub Security Scanner](https://github-security-scanner.onrender.com/) and reports a deterministic security score plus findings. It is designed for lightweight, repeatable security checks on pushes and pull requests.

## What it checks

The scanner can identify:

- 🔐 Potential exposed secrets and credentials
- ⚠️ Dangerous code patterns / SAST-style findings
- 📦 Dependency and known-advisory risks from supported manifests
- 🛡️ Security configuration issues
- 📊 A deterministic 0–100 security score and severity counts

> The scanner uses static analysis and repository metadata. It does **not** execute code from the repository or install dependencies from the repository being scanned.

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

**No checkout step is required.** The action uses the repository that triggered the workflow by default and retrieves the public repository data through the scanner service.

## Fail the workflow on serious findings

By default, the action fails when it finds a `high` or `critical` finding.

You can choose the threshold:

```yaml
- name: Scan repository
  uses: peterkehinde673/github-security-scanner-action@v1
  with:
    fail-on: critical
```

Supported values:

| `fail-on` | Workflow fails when findings include |
| --- | --- |
| `critical` | Critical |
| `high` | High or Critical |
| `medium` | Medium, High, or Critical |
| `low` | Low, Medium, High, or Critical |

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `repository` | Current repository | HTTPS GitHub repository URL to scan |
| `scanner-url` | `https://github-security-scanner.onrender.com` | Base URL of the scanner API |
| `fail-on` | `high` | Severity threshold: `critical`, `high`, `medium`, or `low` |

### Scan another public repository

You can explicitly provide a repository URL:

```yaml
- name: Scan public repository
  uses: peterkehinde673/github-security-scanner-action@v1
  with:
    repository: https://github.com/owner/repository
    fail-on: high
```

The target repository must be publicly accessible. Private repository credentials are not accepted or handled by this action.

## Outputs

The action exposes two outputs:

| Output | Description |
| --- | --- |
| `score` | Deterministic security score from 0 to 100 |
| `findings` | Total number of findings returned by the scanner |

Example:

```yaml
- name: Scan repository
  id: security
  uses: peterkehinde673/github-security-scanner-action@v1

- name: Print security score
  run: echo "Security score: ${{ steps.security.outputs.score }}/100"
```

## Example result

A clean scan reports a result similar to:

```text
GitHub Security Scanner score: 100/100
Findings: critical=0, high=0, medium=0, low=0
```

When findings meet or exceed the configured `fail-on` threshold, the action exits with a failure status so the GitHub workflow can block or flag the change.

## Security and privacy

This action is intentionally designed with a small permission footprint:

- The example workflow requests only `contents: read`.
- No GitHub personal access token is required by the action.
- No repository code is executed by the action.
- Dependencies from the target repository are not installed.
- Repository URLs must use HTTPS GitHub URLs.
- Scanner responses are validated before results are accepted.
- The action prints the score and severity counts rather than dumping finding evidence into the workflow log.

### What data leaves the workflow?

For the default hosted configuration, the public repository URL and the public repository files selected for scanning are sent to the GitHub Security Scanner service at `github-security-scanner.onrender.com`.

Do not use the hosted action for private or sensitive repositories until private scanning and the corresponding data-handling controls are explicitly supported.

If your organization needs a different deployment, the `scanner-url` input can point to a compatible scanner API that you control.

## Limitations

- **Public repositories only.** Private repository authentication is not currently supported.
- The scanner is static analysis; it does not execute application code.
- SAST detection is pattern-based rather than a full language-aware AST analysis.
- Dependency analysis depends on the package manifests and advisory data supported by the scanner.
- The action is not a replacement for comprehensive penetration testing, code review, or a dedicated enterprise security platform.

## Versioning

Use the major release tag for normal consumption:

```yaml
uses: peterkehinde673/github-security-scanner-action@v1
```

For high-assurance supply-chain environments, you can pin the action to a full commit SHA instead. GitHub recommends release/tag based versioning for Actions, while full SHAs provide an immutable reference. See the [GitHub documentation on managing custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions).

## Development

The action repository contains the GitHub Actions integration. The scanning engine remains in the main [GitHub Security Scanner](https://github.com/peterkehinde673/GitHub-Security-Scanner) repository.

The repository includes an automated self-test workflow that exercises the released `v1` action against the scanner service.

## Links

- **Web scanner:** https://github-security-scanner.onrender.com/
- **Scanner engine:** https://github.com/peterkehinde673/GitHub-Security-Scanner
- **Marketplace:** https://github.com/marketplace/actions/github-security-scanner
- **Issues:** https://github.com/peterkehinde673/github-security-scanner-action/issues

## Support and responsible disclosure

For bugs or feature requests, open an issue in this repository.

If you discover a security vulnerability, please avoid posting sensitive details publicly. Use GitHub's private vulnerability reporting features when available for this repository.
