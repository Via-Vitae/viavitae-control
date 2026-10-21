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

## Creating backups (run after every apply and every vault change)

This host's interactive **umask is `0002`** — files created without a guard land group-readable
(0664). An earlier revision of this loop omitted `umask 077` and produced a 0664 encrypted
copy of live state while fixing that very defect (recorded pitfall). The guard is therefore
part of the procedure, not an optimization, and the mode check at the end is the proof.

```bash
umask 077
RECIPIENT=$(age-keygen -y ~/.config/age/state-backup-key.txt)
TS=$(date -u +%Y%m%dT%H%M%SZ)
for f in /opt/viavitae/repos/viavitae-control/terraform.tfstate \
         /opt/jol/repos/jol-control/terraform.tfstate; do
  age -r "$RECIPIENT" -o "/opt/jol/backup/tfstate/$(basename "$(dirname "$f")")-terraform.tfstate.$TS.age" "$f"
done
# jolarca authoritative state lives in HCP (ADR-0006); export it explicitly.
# Never pipe the pull straight into age — a failed auth yields EMPTY stdin and age
# will cheerfully encrypt zero bytes, producing a "good" archive of nothing.
cd /opt/jolarca/repos/jolarca-control
umask 077; TMP=$(mktemp); terraform state pull > "$TMP"; rc=$?
if [ "$rc" -eq 0 ] && [ -s "$TMP" ] && grep -q '"lineage"' "$TMP"; then
  age -r "$RECIPIENT" -o "/opt/jol/backup/tfstate/jolarca-control-hcp-state.$TS.age" "$TMP"
else
  echo "HCP state pull failed (rc=$rc) — no archive written" >&2
fi
shred -u "$TMP"
# age vault (~/.vault) — git bundle, self-contained (--all). This is the store that holds
# real secrets (scripts/vault.sh). ~/.password-store is the deprecated, never-initialized
# `pass` skeleton — bundling it would back up nothing while looking like a vault copy.
git -C ~/.vault bundle create "/opt/jol/backup/tfstate/vault-$TS.bundle" --all
# PROVE the guard worked — must print nothing (no file group/other-readable):
find /opt/jol/backup/tfstate -newermt "-10 minutes" -perm /g+r,o+r -print
# PROVE restorability of one archive per run (sha256 round-trip):
age -d -i ~/.config/age/state-backup-key.txt \
    "/opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.$TS.age" | sha256sum
sha256sum /opt/viavitae/repos/viavitae-control/terraform.tfstate
```

Cadence: after every apply, and at least every 30 days — a backup older than the last change
is how F-02-class findings are born. When the second physical medium arrives (roadmap step 5),
the whole `/opt/jol/backup/tfstate/` directory syncs to it; until then these archives share
`nvme1n1` with the data they protect and guard only against deletion/corruption, not disk loss.

## Restoring an encrypted backup (do this before any plan/apply)

`age --decrypt` creates the output file with the **process umask**, which on this host is
`0002` — so a naive restore writes live state **group-readable (0664)** and defeats the very
control this file documents. Set the mask first, then verify the mode; do not trust the
command to have finished because a pipeline hid its exit status (`echo ${PIPESTATUS[0]}`).

```bash
umask 077
ls /opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.*.age   # newest = authoritative
age -d -i ~/.config/age/state-backup-key.txt \
    /opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.<newest>.age \
    > terraform.tfstate
stat -c '%a %n' terraform.tfstate          # must print 600
terraform init && terraform plan           # GITHUB_TOKEN + TF_VAR_billing_email exported
```

Confirm the restored identity before trusting it: `terraform.tfstate` carries a `lineage`
and `serial`; this plane's invariant is lineage `eff08856` — a different lineage means you
restored another plane's state, stop. The `serial` only ever increases with each apply, so
never hard-check a serial value here; compare against the serial recorded in the newest
backup manifest instead.

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
