# Skidbladnir Agent Context (`ADR-0016` / `ADR-0017`, L3 Personal Situated Fleet)

- **Role**: Personal NixOS fleet composing [`baugr`](https://github.com/LW-54/baugr) (L0), [`verft`](https://github.com/LW-54/verft) (L1), and [`ivaldi`](https://github.com/LW-54/ivaldi) (L2) in one barrier-free fractal namespace (`roots = [ ivaldi.lib.rootDir ./. ]`).
- **Topology**: `agents/fleet.toml` -> 6 hosts (`astrolabe`, `x240`, `tuf`, `rpi` `aarch64`, `wsl`, `live-iso`), 2 bespoke hardware agents (`hw-astrolabe`, `hw-x240`), 2 actors (`actor-gha-ci`, `actor-agent-bot`), 3 capability sessions (`cap-{admin,breakglass,ai}-session`), and 5 external platform stubs.
- **Authorization SSOT**: `policies/fleet.toml` governs all 6 Cedar planes (`read-secret`, `mesh-connect`, `nats-queue`, `obs-query`, `assume-capability`, `admit-agent`). Never hand-edit `.sops.yaml`, `policy/tailscale.json`, or `policy/nats-rbac.json` without regenerating via `baugr --json project <action> | ivaldi-emit-*` (enforced by `checks.policy-emitters-audit`).
- **Non-Piercing Invariant**: Atomic `interior.nix` files MUST return a plain NixOS attrset (never `{ config, ... }:`). `nixos.imports` is gated on factual attribute `foreign:nixos-module`.
- **Verification**: Run `nix flake check -L` (or `just check`) before committing. Commit messages follow `<type>: <description>` (no parenthetical scope, lowercase, no trailing period).
- **3 AM Crisis Runbooks**: See `docs/runbooks/` (`01-vps-loss-and-breakglass-dr.md`, `02-pull-rollback-and-quarantine.md`, `03-m1-sunset-cutover.md`).
