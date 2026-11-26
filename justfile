# Skidbladnir — <= 40-LOC zero-logic developer shortcuts (ADR-0016 / ADR-0017)

default:
    @just --list

# Fast (< 10 ms) strict ERG-L2 + Promise + SST + 6-plane Cedar verification
check-fast:
    nix build --no-link -L .#checks.x86_64-linux.fleet-check-and-drt

# Run 12-attack static adversarial regression suite
attacks:
    nix build --no-link -L .#checks.x86_64-linux.adversarial-12-attacks

# Audit compiled .sops.yaml, policy/tailscale.json & policy/nats-rbac.json for 0 drift
audit:
    nix build --no-link -L .#checks.x86_64-linux.policy-emitters-audit

# Build out-of-Git mdBook documentation site
docs:
    nix build -L .#packages.x86_64-linux.docs-site

# Run live KVM QEMU smoke test for astrolabe (adje.app)
vm:
    nix build --no-link -L .#checks.x86_64-linux.vm-astrolabe-smoke

# Run full hermetic F3 flake verification suite
check:
    nix flake check -L

# Format all Nix files
fmt:
    alejandra flake.nix agents/ tests/
