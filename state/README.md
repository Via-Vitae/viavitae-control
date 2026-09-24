# state/

Terraform state management for `viavitae-control`.

## Current mode: encrypted local state

Right now the root module uses the default **local** backend. The state file
(`terraform.tfstate`) lives in the repo root and is **git-ignored** (see `/.gitignore`)
because it can contain sensitive resource metadata.

Protect local state:

- Encrypt the disk / working directory (LUKS, FileVault, BitLocker).
- Never commit `terraform.tfstate`, `*.tfstate.*`, or `*.tfplan`.
- Treat the state file as a secret: it may embed repository metadata and tokens'
  side-effects. Restrict filesystem permissions (`chmod 600 terraform.tfstate`).

## Target mode: S3 backend (Via-Vitae bootstrap bucket)

Copy `backend_s3.tf.example` to `backend_s3.tf` in the repo root, fill in the
bucket/key/region, then re-run `terraform init` and migrate:

```bash
cp state/backend_s3.tf.example ./backend.tf   # adjust values first
terraform init -migrate-state
```

Backend requirements (see the example for the full checklist):

- **Versioning enabled** on the bucket (state history / rollback).
- **Server-side encryption** (SSE-S3 minimum; SSE-KMS preferred — ISO 27001 A.10).
- **State locking** — DynamoDB lock table, or S3 native locking (`use_lockfile = true`,
  Terraform ≥ 1.10).
- **Block public access** on the bucket (GDPR / SOC 2 CC6.1).
- **Cross-region replication** optional for DR (see `viavitae-runbooks` / `viavitae-infra`).

## Migration checklist

1. Provision/confirm the Via-Vitae bootstrap bucket meets the requirements above.
2. `cp state/backend_s3.tf.example ./backend.tf`; set real bucket/key/region.
3. `terraform init -migrate-state` and answer `yes` to copy existing state.
4. `terraform plan` — must show **no changes** (proves clean migration).
5. Delete the local `terraform.tfstate` only after the remote plan is clean.
6. Store `backend.tf` values in the repo (they are not secrets); keep AWS creds in
   env/SSO, never in code.
