# state/

Terraform state management for `viavitae-control`.

## Current mode: local state — NOT encrypted at rest (verified 2026-10-13)

The root module uses the default **local** backend. The state file
(`terraform.tfstate`) lives in the repo root and is **git-ignored** (see `/.gitignore`)
because it can contain sensitive resource metadata.

> **Correction.** This section previously read "encrypted local state". That was untrue.
> `findmnt /opt/viavitae` returns `vgopt-lv_viavitae` (plain LVM, ext4) and
> `dmsetup ls --target crypt` returns **0** devices, so no LUKS/dm-crypt layer exists on
> this host. At-rest protection today is **filesystem permissions only**, and `.gitignore`
> protects the repository, not the disk.

Measured 2026-10-13: `terraform.tfstate` serial **13**, lineage **eff08856**, 9 managed
instances, 27,538 bytes, mode `0600`.

Protect local state:

- Never commit `terraform.tfstate`, `*.tfstate.*`, or `*.tfplan`. A **saved plan file is
  state-equivalent** — it embeds prior state plus proposed attribute values — so it needs
  the same handling as the state itself.
- Restrict permissions on all of them: `chmod 600 terraform.tfstate terraform.tfvars *.tfplan`.
- Treat the state file as a secret. It discloses the full repository inventory, which repos
  are private, per-repo security settings, the Actions allow-list, and the repos still
  unprotected (`branch_protection_deferred`). It need not contain a token to be sensitive.
- Disk/working-directory encryption (LUKS) is still **not** in place — tracked as C13a in
  `docs/COMPLIANCE.md`.

## Target mode: S3 backend (Via-Vitae bootstrap bucket) — BLOCKED

> **Blocked, verified 2026-10-13.** Account `775093708742` is a member of AWS Organization
> `o-omcubugbug`. SCP `arn:aws:organizations::376896792604:policy/o-omcubugbug/service_control_policy/p-r9i2lq77`
> returns **explicit deny** for `s3:ListAllMyBuckets` and `s3:CreateBucket` as
> `arn:aws:iam::775093708742:user/viavitae-terraform`. An SCP explicit deny cannot be
> overridden by any IAM policy inside a member account — only the management account can
> grant it, so do not spend time on IAM workarounds. The steps below are therefore **not
> executable today**, and the open decision for this plane is HCP Terraform (the choice
> `jolarca-control` recorded in its ADR-0006, which evaluated and rejected S3+DynamoDB)
> versus continued local state plus the encrypted archive below. That decision needs a
> written ADR before any backend change. If the access request is re-raised, ask for an
> **allow scoped to one bucket ARN**, never for removal of the deny.

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

Steps 1-6 cannot start until the SCP blocker above is resolved. Until then the control in
the next section is what stands between this project and permanent loss of its inventory.

## Interim durability control (in place since 2026-10-13)

Because remote state is blocked, durability is provided by an **age-encrypted off-device
archive** of every control-plane state, verified by decrypt-and-compare rather than assumed.

- Archives and manifest: `/opt/jol/backup/tfstate/` (device `nvme1n1p6`).
- Recipient (public) key: `/opt/jolarca/repos/jolarca-control/.state-backup-pubkey.txt` —
  committed by design. Identity (private) key: `~/.config/age/state-backup-key.txt`, mode `0600`.
  Custody verified 2026-10-13: `age-keygen -y` on the identity reproduces the committed pubkey.
- Manifest columns are `archive / sha256 / content`, where content records `serial`, `lineage`
  and the managed-instance count read out of the decrypted state.

**Limits of this control — do not read it as 3-2-1 complete:**

1. `nvme1n1p6` is **off-device for this plane** (its state is on `nvme2n1` via `vgopt`) but
   **on the same physical disk as `jol-control`'s state** (`nvme1n1p8`). A failure of
   `nvme1n1` would take the charity's state and its only archive together.
2. Nothing here is **off-host**. An independent second copy is still required.
3. The identity key sits on the same host as the archives. Lose `~/.config/age/` and every
   archive becomes unrecoverable — move the identity off-host (the reference procedure is
   `docs/security/key-custody.md` in `jolarca-control`).

Re-run after every apply (appends a verified row to that run's manifest):

```bash
umask 077          # REQUIRED: without this the archives are created 0644/0664 and the
                   # backup set becomes the leak. Verified the hard way on 2026-10-13:
                   # an earlier run of this loop omitted it and produced group-readable
                   # archives of live state (P1-15).
P=$(tr -d ' \n' </opt/jolarca/repos/jolarca-control/.state-backup-pubkey.txt)
T=$(date -u +%Y%m%dT%H%M%SZ)
M=/opt/jol/backup/tfstate/manifest-$T.tsv
# Device guard (P1-17): an archive on the same PHYSICAL disk as its source is not a backup.
# Compare disks, not partition names: nvme1n1p6 and nvme1n1p8 are one drive.
# Verified 2026-10-13: viavitae-control src = /dev/mapper/vgopt-lv_viavitae (nvme2n1),
# destination /opt/jol/backup/tfstate = /dev/nvme1n1p6 -> genuinely a second disk here.
# For jol-control (src /dev/nvme1n1p8) the same destination is NOT a second disk.
sd=$(df --output=source /opt/viavitae/repos/viavitae-control | tail -1)
dd=$(df --output=source /opt/jol/backup/tfstate | tail -1)
echo "src=$sd dst=$dd"
case "$dd" in *nvme1n1*) echo "WARN: destination sits on OS disk nvme1n1 - unlock a LUKS volume instead (P1-17)";; esac
printf 'archive\tsha256\tcontent\n' > "$M"
for f in /opt/viavitae/repos/viavitae-control/terraform.tfstate \
         /opt/jol/repos/jol-control/terraform.tfstate; do
  o=/opt/jol/backup/tfstate/$(basename $(dirname $f))-$(basename $f).$T.age
  age -r "$P" -o "$o" "$f"
  h=$(sha256sum "$f" | cut -d' ' -f1)
  d=$(age -d -i ~/.config/age/state-backup-key.txt "$o" | sha256sum | cut -d' ' -f1)
  c=$(age -d -i ~/.config/age/state-backup-key.txt "$o" \
      | jq -r '"serial=\(.serial) lineage=\(.lineage[0:8]) inst=\([.resources[]|select(.mode=="managed")|.instances|length]|add)"')
  if [ "$h" = "$d" ]; then echo "VERIFIED $o"; else echo "FAILED $o"; fi
  printf '%s\t%s\t%s\n' "$(basename "$o")" "${h:0:16}" "$c" | tee -a "$M"
done
```

A `FAILED` line means the archive cannot be restored with the local identity — stop and fix
custody before relying on it.

## Restore drill: two tiers, and only tier 1 is done

GDPR Art. 32(1)(c) asks for *the ability to ensure ongoing availability of and access to*
data after an incident. A configured destination is not that ability; a rehearsed restore is.

**Tier 1 — archive integrity (rehearsed 2026-10-13, all four archives passed).**

```bash
A=$(ls -t /opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.*.age | head -1)
age -d -i ~/.config/age/state-backup-key.txt "$A" \
  | jq -r '"serial=\(.serial) lineage=\(.lineage[0:8]) inst=\([.resources[]|select(.mode=="managed")|.instances|length]|add)"'
```

Expected: `serial=13`, `lineage=eff08856`, `inst=9`.

**Tier 2 — plan from restored state in a scratch copy (NOT yet rehearsed; tracked as C13b).**

```bash
umask 077; D=/tmp/vv-drill-$$; mkdir -p "$D"
cd /opt/viavitae/repos/viavitae-control
git ls-files -z | xargs -0 -I{} install -Dm644 {} "$D/{}"
find . -maxdepth 1 -name '*.tf' -newer .git -exec install -Dm644 {} "$D/{}" \; 2>/dev/null
A=$(ls -t /opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.*.age | head -1)
age -d -i ~/.config/age/state-backup-key.txt -o "$D/terraform.tfstate" "$A"
cd "$D" && cp -a /opt/viavitae/repos/viavitae-control/.terraform . \
  && terraform init -backend=false -input=false >/dev/null \
  && terraform validate \
  && terraform plan -input=false -refresh=false -var 'billing_email=org-billing@example.invalid' | tail -5
rm -rf "$D"
```

Acceptance: `validate` succeeds and the plan shows **no adds of the 30 declared repos** —
if it proposes to create repositories that already exist, the restored state is not the one
this config expects. A plan against an empty or unreadable state proposes to CREATE
everything, and `prevent_destroy` cannot catch that because nothing is being destroyed.
