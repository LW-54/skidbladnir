# Runbook 02 — `verft-pull` Rollback, Epoch Quarantine & Emergency Human Override

## 1. Trigger
- `ntfy` alert or `verft_pull_rollback_alert == 1` / `verft_pull_freeze_alert == 1` on any fleet host.

## 2. Blast Radius & Invariants
- Host automatically rolled back to `last_healthy_epoch` and recorded the bad epoch in `/var/lib/verft-pull/pull-state.json` (`failed_epochs`).
- Reboots will **never** re-enter a quarantined epoch (`EXP-0016` KVM `vm-pull-rollback`), and `systemd-boot.bootCounting` (`tries = 3`) protects against kernel/initrd boot failures.

## 3. Immediate Diagnosis
```bash
verft pull --json status --state-file /var/lib/verft-pull/pull-state.json | jq .
cat /etc/verft/pull-rollback-probes.json
journalctl -u verft-pull -n 100 --no-pager
```

## 4. Minimalist Recovery Steps
- **Normal fix (CI reachable)**: Fix the broken module on a PR to `LW-54/skidbladnir`, pass `nix flake check -L`, merge to `main`. CI publishes a higher epoch (`epoch + 1`); `verft-pull` automatically converges on the next tick.
- **Emergency Human Root override (CI compromised or unavailable)**:
  1. Build & push known-good host closure to `cache.adje.app`.
  2. Sign a higher-epoch `calibration.json` with the Offline Human Root key inside an offline `verft cap` session:
     ```bash
     verft pull sign --key-file "$HUMAN_ROOT_KEY" --manifest calibration.json --out calibration.json.sig
     ```
  3. Publish `calibration.json` + `.sig` to mirror or run `verft pull run --source <local-dir>` directly on the host.

## 5. Verification
```bash
verft pull --json status --state-file /var/lib/verft-pull/pull-state.json | jq '{active_epoch, rollback_alert, freeze_alert, failed_epochs}'
```
