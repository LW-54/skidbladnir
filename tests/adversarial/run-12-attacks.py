#!/usr/bin/env python3
"""Skidbladnir F3 12-Attack Static Adversarial Regression Suite.

Clones the real Ivaldi + Skidbladnir roots into isolated temp directories, injects each
of the 12 canonical security, isolation, CALM, budget, and boundary-smuggling attacks
(`EXP-0015` §4-§7), invokes `baugr --strict-schemas check`, and asserts EVERY attack is
statically blocked with its exact expected diagnostic(s).
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"mutation anchor not found in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_text(path: Path, extra: str) -> None:
    path.write_text(path.read_text(encoding="utf-8") + "\n" + extra, encoding="utf-8")


def run_attack(
    idx: int,
    name: str,
    baugr_bin: str,
    ivaldi_src: Path,
    skid_src: Path,
    mutate: Callable[[Path, Path], None],
    expected_substrings: list[str],
) -> None:
    with tempfile.TemporaryDirectory(prefix=f"skid-attack-{idx:02d}-") as tmp:
        tmp_path = Path(tmp)
        iv = tmp_path / "ivaldi"
        sk = tmp_path / "skidbladnir"
        shutil.copytree(ivaldi_src, iv)
        shutil.copytree(skid_src, sk)
        # Ensure copies from read-only /nix/store are writable
        for root_dir in (iv, sk):
            for p in [root_dir, *root_dir.rglob("*")]:
                p.chmod(p.stat().st_mode | 0o200)

        mutate(iv, sk)

        proc = subprocess.run(
            [baugr_bin, "--strict-schemas", "--root", str(iv), "--root", str(sk), "check"],
            capture_output=True,
            text=True,
            check=False,
        )
        combined = proc.stdout + "\n" + proc.stderr
        if proc.returncode == 0:
            raise AssertionError(
                f"Attack #{idx:02d} ({name}) UNEXPECTEDLY PASSED baugr check!\n{combined}"
            )
        for substr in expected_substrings:
            if substr not in combined:
                raise AssertionError(
                    f"Attack #{idx:02d} ({name}) failed, but missing expected diagnostic {substr!r}.\nOutput:\n{combined}"
                )
        print(f"[BLOCKED {idx:02d}/12] {name} -> matched {expected_substrings}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baugr", required=True)
    parser.add_argument("--ivaldi-root", type=Path, required=True)
    parser.add_argument("--skidbladnir-root", type=Path, required=True)
    args = parser.parse_args()

    attacks: list[tuple[str, Callable[[Path, Path], None], list[str]]] = [
        (
            "Wire vaultwarden (prod secret) onto roaming laptop x240",
            lambda _iv, sk: replace_once(
                sk / "agents/hosts/x240.toml",
                '"cache-harmonia-dev",',
                '"cache-harmonia-dev",\n  "vaultwarden",',
            ),
            ["UnauthorizedPromise", "ab-read-secret", "x240", "vaultwarden-master"],
        ),
        (
            "Wire cap-sops-root inside AI diagnostic session cap-ai-session",
            lambda _iv, sk: replace_once(
                sk / "agents/sessions/ai-obs.toml",
                '"cap-obs-mcp",',
                '"cap-obs-mcp",\n  "cap-sops-root",',
            ),
            ["UnauthorizedPromise", "ab-assume-capability", "cap-ai-session", "sops-root"],
        ),
        (
            "Mix offline cap-breakglass into online cap-admin-session",
            lambda _iv, sk: replace_once(
                sk / "agents/sessions/admin.toml",
                '"cap-r2-admin",',
                '"cap-r2-admin",\n  "cap-breakglass",',
            ),
            ["UnauthorizedPromise", "ab-assume-capability", "breakglass-root", "DuplicateOffer"],
        ),
        (
            "Wire workstation cache-harmonia-dev onto prod server astrolabe",
            lambda _iv, sk: replace_once(
                sk / "agents/hosts/astrolabe.toml",
                '"docs-mdbook",',
                '"docs-mdbook",\n  "cache-harmonia-dev",',
            ),
            ["UnauthorizedPromise", "ab-admit-agent", "astrolabe", "harmonia-dev"],
        ),
        (
            "Remove caddy-mesh from astrolabe (test if mesh routes leak to caddy-public)",
            lambda _iv, sk: replace_once(
                sk / "agents/hosts/astrolabe.toml",
                '  "caddy-mesh",\n',
                "",
            ),
            ["ExclusiveMismatch", "proxy:mesh", "UnhandledPartitionedOffer"],
        ),
        (
            "Tag obs-hub perses route with BOTH zone:mesh and zone:public",
            lambda iv, _sk: replace_once(
                iv / "agents/obs/hub.toml",
                'tags = ["zone:mesh"]',
                'tags = ["zone:mesh", "zone:public"]',
            ),
            ["split-horizon-disjoint-zones", "OverlappingPartitionHandlers"],
        ),
        (
            "Strip monotonic tag from multi-writer sync-git-annex state:persist",
            lambda iv, _sk: replace_once(
                iv / "agents/storage/sync-git-annex/agent.toml",
                '"multi-writer", "monotonic"',
                '"multi-writer"',
            ),
            ["calm-monotonicity"],
        ),
        (
            "Overcommit constrained 1 GiB rpi RAM (supply 96 MiB < demand)",
            lambda _iv, sk: replace_once(
                sk / "agents/hosts/rpi.toml",
                "ram = 1024",
                "ram = 96",
            ),
            ["BudgetExceeded", '"ram"'],
        ),
        (
            "Compromised compute donor tuf claims NATS submitter role",
            lambda iv, _sk: append_text(
                iv / "agents/compute/nats-worker/agent.toml",
                '[offer."nats:claim".tuf-submit]\ntags = ["role:submitter"]\n',
            ),
            ["UnauthorizedPromise", "ab-nats-queue", "tuf"],
        ),
        (
            "PR-only AI bot actor-agent-bot attempts to assume cap-github-cli",
            lambda _iv, sk: replace_once(
                sk / "agents/actors/agent-bot.toml",
                '"cap-obs-mcp",',
                '"cap-obs-mcp",\n  "cap-github-cli",',
            ),
            ["UnauthorizedPromise", "ab-assume-capability", "actor-agent-bot", "github-cli"],
        ),
        (
            "Atomic CI runner actor-gha-ci claims prod vaultwarden-master secret",
            lambda _iv, sk: append_text(
                sk / "agents/actors/gha-ci.toml",
                '[offer."secret:claim".vaultwarden-master]\ntags = ["class:vault"]\n',
            ),
            ["atomic-auth:", "UnauthorizedPromise", "actor-gha-ci", "vaultwarden-master"],
        ),
        (
            "Unexported mandatory Broadcast offer smuggled inside auth-stack child auth-lldap",
            lambda iv, _sk: append_text(
                iv / "agents/apps/auth-lldap/agent.toml",
                '[offer."state:persist"."/var/lib/smuggled"]\ntags = ["survives-reboot", "single-auth-writer"]\npath = "/var/lib/smuggled"\n',
            ),
            ["DroppedMandatoryOffer", "/var/lib/smuggled"],
        ),
    ]

    for idx, (name, mut, expected) in enumerate(attacks, start=1):
        run_attack(idx, name, args.baugr, args.ivaldi_root, args.skidbladnir_root, mut, expected)

    print("ALL 12/12 ADVERSARIAL ATTACKS STATICALLY BLOCKED!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
