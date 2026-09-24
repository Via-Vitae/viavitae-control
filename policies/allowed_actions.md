# GitHub Actions allowed-actions policy

## Control

`org_actions_policy.tf` declares `github_actions_organization_permissions`, restricting
which third-party actions may run in any repository across the org.

- **SOC 2 CC6.6 / CC7.1** — boundary protection & vulnerability management
- **ISO 27001 A.15.1.2 / A.14.2** — supplier & secure development
- **GDPR Art. 32** — prevents unvetted workflow code from processing/exfiltrating data

## Why an allow-list

GitHub Actions can run arbitrary third-party code with access to repository secrets.
An unpinned or malicious action is a direct supply-chain and secret-exfiltration risk.
Restricting to a curated allow-list is the primary mitigation.

## Modes (`var.actions_allowed_mode`)

| Mode | Behavior | Use |
|---|---|---|
| `all` | No restriction (current unsafe default) | Never in production |
| `selected` | Only actions matching `actions_allowed_patterns` | **Recommended** |
| `disabled` | Actions disabled org-wide | Locked-down/audit state |

## Default allow-list

```
actions/checkout@*          actions/setup-node@*        actions/setup-python@*
actions/upload-artifact@*   actions/download-artifact@* actions/cache@*
github/codeql-action@*      dependabot/*
```

## Hardening notes

- **Pin to full commit SHAs** rather than tags (`@*`) for production. Tag pins can be
  force-updated upstream; SHA pins cannot. Tighten `actions_allowed_patterns` to SHAs as
  workflows stabilize.
- Any new action a team needs must be added here via PR — this is the review gate.
- Combine with `permissions:` least-privilege in each workflow (default `contents: read`).
