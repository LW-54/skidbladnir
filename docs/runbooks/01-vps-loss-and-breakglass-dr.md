# Runbook 01 — VPS Loss & Offline Break-Glass Disaster Recovery

## 1. Trigger
- `astrolabe` (`adje.app`) is permanently unreachable or destroyed, AND Vaultwarden (hosted on `astrolabe`) is down.

## 2. Blast Radius & Invariants
- **No Circular DR Deadlock** (`quint/lifecycle_recovery.qnt`): Cold offline recovery media (USB/paper) holds the root `age` private key (`breakglass`) and emergency SSH key, independent of Vaultwarden and Tailscale.
- **Data Safety**: Off-host Restic backups exist on Cloudflare R2 (`skidbladnir-backups`, 14d Governance WORM lock) and Hetzner Storage Box (`sftp://hbox`).

## 3. Immediate Diagnosis
```bash
# Confirm whether WAN/Tailscale or VPS hardware is dead
ping -c 3 adje.app
curl -fsS --max-time 5 https://vault.adje.app/alive || echo "VAULT_DOWN"
```

## 4. Minimalist Recovery Steps
1. **Enter offline break-glass session** (never mix with online admin tokens):
   ```bash
   export SKIDBLADNIR_SOPS_AGE_KEY="$(cat /mnt/cold-usb/age.key)"
   verft cap run --cap-dir ./capabilities --posture offline breakglass -- bash
   ```
2. **Decrypt cold recovery secrets**:
   ```bash
   sops -d secrets/recovery.sops.yaml
   ```
3. **Provision replacement VPS & boot NixOS `live-iso`** (or fresh NixOS image).
4. **Restore `/persist` data from Restic WORM / `hbox`**:
   ```bash
   restic -r s3:https://<r2-endpoint>/skidbladnir-backups restore latest --target /mnt/persist
   ```
5. **Deploy `astrolabe` closure** (from local bare mirror or `github:LW-54/skidbladnir#nixosConfigurations.astrolabe`):
   ```bash
   nixos-install --flake .#astrolabe
   ```

## 5. Verification & Post-Incident Cleanup
```bash
curl -fsS https://vault.adje.app/alive
curl -fsS https://ntfy.adje.app/v1/health
verft pull status --state-file /var/lib/verft-pull/pull-state.json
# Unmount cold USB and exit break-glass shell (CLONE_NEWNS tmpfs vanishes automatically)
```
