# Runbook 03 — `M1-Sunset` Zero-Carry-Forward Cutover (`nixconf` -> `skidbladnir`)

## 1. Trigger
- Migrating physical hosts (`x240`, `astrolabe`, `tuf`, `rpi`, `wsl`) from legacy `LW-54/nixconf` to `LW-54/skidbladnir` (`ADR-0017` / `RES-0024` §6).

## 2. Blast Radius & Invariants
- Zero legacy `nixconf` module carry-forward; rollback to the previous NixOS boot generation stays 1 command / 1 `systemd-boot` entry away at every wave.
- `x240` serves as the non-production canary before touching production `astrolabe`.

## 3. Six-Wave Cutover Sequence
1. **Wave 0 — Pre-Flight & Cold Backup**:
   - Run `nix flake check -L` on `skidbladnir` (all 7 `F3` gates GREEN).
   - Take fresh verified Restic snapshot on `astrolabe` (`hbox` + R2 WORM) and test cold USB `age` key decryption.
2. **Wave 1 — `x240` Canary Switch**:
   - `nixos-rebuild test --flake github:LW-54/skidbladnir#x240` -> verify Tailscale, SSH, `harmonia.cache`, and `fluent-bit` -> `nixos-rebuild switch`.
3. **Wave 2 — Cloudflare R2 `niks3` Cache & TUF Calibration Bootstrap**:
   - Provision R2 bucket + GitHub OIDC credentials; verify CI publishes signed `calibration.json` + `.sig`.
4. **Wave 3 — `astrolabe` Production Cutover**:
   - Pre-realise closure (`nix build .#nixosConfigurations.astrolabe.config.system.build.toplevel`).
   - Run `switch-to-configuration test` -> verify `vault.adje.app`, `ntfy.adje.app`, `perses`, `caddy-mesh`, `sshd`, `tailscaled` -> commit `boot`.
5. **Wave 4 — Secondary Targets (`tuf`, `rpi`, `wsl`, `live-iso`)**:
   - Cut over `tuf` (NATS worker), `rpi` (`aarch64`), and `wsl`; build fresh `live-iso` rescue USB.
6. **Wave 5 — `nixconf` Archive**:
   - After 14 clean days on `skidbladnir` (`verft-pull` converging cleanly with 0 rollbacks), mark `LW-54/nixconf` read-only / archived on GitHub.

## 4. Instant Rollback
```bash
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch # or reboot & select prior systemd-boot generation
```
