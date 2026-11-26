{
  description = "Skidbladnir — Personal Situated NixOS Fleet composing Baugr (L0) -> Verft (L1) -> Ivaldi (L2) in One Barrier-Free Fractal Namespace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    baugr = {
      url = "github:LW-54/baugr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "crane";
    };
    verft = {
      url = "github:LW-54/verft";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "crane";
      inputs.baugr.follows = "baugr";
    };
    ivaldi = {
      url = "github:LW-54/ivaldi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "crane";
      inputs.baugr.follows = "baugr";
      inputs.verft.follows = "verft";
      inputs.impermanence.follows = "impermanence";
      inputs.hjem.follows = "hjem";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      flake = false;
    };
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    baugr,
    verft,
    ivaldi,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f:
      lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = import nixpkgs {inherit system;};
        });

    # Strict `lib.fileset.toSource` fences (ZERO `${self}` references!)
    skidbladnirRoot = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./schemas
        ./policies
        ./agents
      ];
    };

    capabilitiesSrc = lib.fileset.toSource {
      root = ./capabilities;
      fileset = ./capabilities;
    };

    runbooksSrc = lib.fileset.toSource {
      root = ./docs/runbooks;
      fileset = ./docs/runbooks;
    };

    policyArtifactsSrc = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./.sops.yaml
        ./secrets/keys.json
        ./policy
      ];
    };

    adversarialSrc = lib.fileset.toSource {
      root = ./tests/adversarial;
      fileset = ./tests/adversarial;
    };

    nixFilesSrc = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./flake.nix
        ./agents
        ./tests
      ];
    };

    # Single Barrier-Free Multi-Root Fractal Composition (`ivaldi` L2 + `skidbladnir` L3)!
    realized = verft.lib.realize {
      inherit inputs;
      roots = [
        ivaldi.lib.rootDir
        skidbladnirRoot
      ];
      fleetRoot = "fleet";
    };

    mkDocsSite = system: pkgs: let
      baugrBin = "${baugr.packages.${system}.baugr}/bin/baugr";
      baugrDocBin = "${baugr.packages.${system}.baugr-doc}/bin/baugr-doc";
    in
      pkgs.runCommand "skidbladnir-docs-site" {nativeBuildInputs = [pkgs.mdbook];} ''
        set -euo pipefail
        mkdir -p book-work/src/runbooks

        ${baugrBin} --strict-schemas --root ${ivaldi.lib.rootDir} --root ${skidbladnirRoot} --json graph \
          | ${baugrDocBin} --out book-work/src --title "Skidbladnir Fleet Architecture"

        cp ${runbooksSrc}/*.md book-work/src/runbooks/
        cat >> book-work/src/SUMMARY.md <<'EOF'

        # 3 AM Crisis Runbooks
        - [VPS Loss & Break-Glass DR](runbooks/01-vps-loss-and-breakglass-dr.md)
        - [Pull Rollback & Quarantine](runbooks/02-pull-rollback-and-quarantine.md)
        - [M1-Sunset Cutover](runbooks/03-m1-sunset-cutover.md)
        EOF

        cat > book-work/book.toml <<'EOF'
        [book]
        title = "Skidbladnir Fleet Architecture"
        language = "en"
        src = "src"
        EOF

        mdbook build book-work -d "$out"
        test -s "$out/index.html"
        test -s "$out/promises.html"
        test -s "$out/runbooks/01-vps-loss-and-breakglass-dr.html"
      '';

    mkFleetCheckAndDrt = system: pkgs: let
      baugrBin = "${baugr.packages.${system}.baugr}/bin/baugr";
      oracleBin = "${baugr.packages.${system}.baugr-oracle}/bin/baugr-oracle";
      commonArgs = "--strict-schemas --root ${ivaldi.lib.rootDir} --root ${skidbladnirRoot}";
    in
      pkgs.runCommand "skidbladnir-fleet-check-and-drt" {nativeBuildInputs = [pkgs.jq];} ''
        set -euo pipefail

        echo "=== 1. Strict ERG-L2 + Promise + SST + Invariant + 6-Plane Cedar Check ==="
        ${baugrBin} ${commonArgs} check

        echo "=== 2. 514-Case Rust <-> Lean 4 DRT (14 Real Superagents + 500 Fuzzed) ==="
        ${baugrBin} ${commonArgs} drt --oracle ${oracleBin} --cases 500

        echo "=== 3. SST γ(3,4) Impact Cone & 6-Plane Policy Projections ==="
        ${baugrBin} ${commonArgs} graph --impact obs-victoriametrics
        for action in read-secret assume-capability admit-agent mesh-connect nats-queue obs-query; do
          echo "--- plane: $action ---"
          ${baugrBin} ${commonArgs} project "$action"
        done

        echo "SKIDBLADNIR_FLEET_CHECK_AND_DRT_OK" > $out
      '';

    mkAdversarialCheck = system: pkgs: let
      baugrBin = "${baugr.packages.${system}.baugr}/bin/baugr";
    in
      pkgs.runCommand "skidbladnir-adversarial-12-attacks" {nativeBuildInputs = [pkgs.python3];} ''
        set -euo pipefail
        python3 ${adversarialSrc}/run-12-attacks.py \
          --baugr ${baugrBin} \
          --ivaldi-root ${ivaldi.lib.rootDir} \
          --skidbladnir-root ${skidbladnirRoot}
        echo "SKIDBLADNIR_12_ADVERSARIAL_ATTACKS_BLOCKED_OK" > $out
      '';

    mkS1EquivCheck = system: pkgs: let
      baugrBin = "${baugr.packages.${system}.baugr}/bin/baugr";
      commonArgs = "--strict-schemas --root ${ivaldi.lib.rootDir} --root ${skidbladnirRoot}";
      r = realized;

      desugaredFiles =
        lib.genAttrs r.allAgentIds
        (aid: pkgs.writeText "skid-nix-desugar-${aid}.json" (builtins.toJSON r.desugaredAgents.${aid}));
      resolvedFiles =
        lib.genAttrs r.allSuperagentIds
        (sid: pkgs.writeText "skid-nix-resolve-${sid}.json" (builtins.toJSON r.resolvedBindings.${sid}));

      # Realize ALL 6 heterogeneous personal NixOS hosts (`x86_64-linux` + `aarch64-linux`)!
      astrolabeCfg = r.nixosConfigurations.astrolabe.config;
      x240Cfg = r.nixosConfigurations.x240.config;
      tufCfg = r.nixosConfigurations.tuf.config;
      rpiCfg = r.nixosConfigurations.rpi.config;
      wslCfg = r.nixosConfigurations.wsl.config;
      isoCfg = r.nixosConfigurations.live-iso.config;

      hostAssertions = assert astrolabeCfg.networking.hostName == "astrolabe";
      assert astrolabeCfg.zramSwap.enable == true;
      assert astrolabeCfg.boot.loader.systemd-boot.bootCounting.enable == true;
      assert astrolabeCfg.boot.loader.systemd-boot.bootCounting.tries == 3;
      assert astrolabeCfg.systemd.network.wait-online.enable == false;
      assert astrolabeCfg.services.vaultwarden.enable == true;
      assert astrolabeCfg.services.vaultwarden.config.DOMAIN == "https://vault.adje.app";
      assert astrolabeCfg.services.ntfy-sh.settings.base-url == "https://ntfy.adje.app";
      assert astrolabeCfg.services.victoriametrics.enable == true;
      assert astrolabeCfg.services.victorialogs.enable == true;
      assert astrolabeCfg.services.victoriatraces.enable == true;
      assert astrolabeCfg.services.perses.enable == true;
      assert astrolabeCfg.services.fluent-bit.enable == true;
      assert astrolabeCfg.services.nats.enable == true;
      assert x240Cfg.networking.hostName == "x240";
      assert x240Cfg.services.harmonia.cache.enable == true;
      assert x240Cfg.hardware.cpu.intel.updateMicrocode == true;
      assert x240Cfg.zramSwap.enable == true;
      assert tufCfg.networking.hostName == "tuf";
      assert builtins.elem "astrolabe.tailnet.ts.net:4222" (builtins.fromJSON tufCfg.environment.etc."verft/nats-worker.json".text).brokers;
      assert rpiCfg.networking.hostName == "rpi";
      assert r.nixosConfigurations.rpi.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
      assert (builtins.fromJSON rpiCfg.environment.etc."verft/fluent-node.json".text).ingestTargets == ["https://obs.astrolabe.tailnet.ts.net:9428"];
      assert wslCfg.networking.hostName == "wsl";
      assert wslCfg.boot.isContainer == true;
      assert isoCfg.networking.hostName == "live-iso"; true;
    in
      assert hostAssertions;
        pkgs.runCommand "skidbladnir-s1-erg-l2-equiv" {nativeBuildInputs = [pkgs.jq];} ''
          set -euo pipefail

          echo "=== S1 Bit-for-Bit Desugar Equivalence (${toString (builtins.length r.allAgentIds)} agents) ==="
          ${lib.concatMapStringsSep "\n" (aid: ''
              ${baugrBin} ${commonArgs} desugar --agent ${aid} | jq -S . > rust-desugar-${aid}.json
              jq -S . ${desugaredFiles.${aid}} > nix-desugar-${aid}.json
              diff -u rust-desugar-${aid}.json nix-desugar-${aid}.json
            '')
            r.allAgentIds}

          echo "=== S1 Bit-for-Bit Resolve Equivalence (${toString (builtins.length r.allSuperagentIds)} closed superagents) ==="
          ${lib.concatMapStringsSep "\n" (sid: ''
              ${baugrBin} ${commonArgs} resolve ${sid} | jq -S . > rust-resolve-${sid}.json
              jq -S . ${resolvedFiles.${sid}} > nix-resolve-${sid}.json
              diff -u rust-resolve-${sid}.json nix-resolve-${sid}.json
            '')
            r.allSuperagentIds}

          echo "SKIDBLADNIR_S1_ERG_L2_AND_6_HOST_REALIZATION_OK" > $out
        '';

    mkPolicyEmittersAudit = system: pkgs: let
      baugrBin = "${baugr.packages.${system}.baugr}/bin/baugr";
      verftCapBin = "${verft.packages.${system}.verft-cap}/bin/verft-cap";
      emitSops = "${ivaldi.packages.${system}.emit-sops}/bin/ivaldi-emit-sops";
      emitTailscale = "${ivaldi.packages.${system}.emit-tailscale}/bin/ivaldi-emit-tailscale";
      emitNats = "${ivaldi.packages.${system}.emit-nats}/bin/ivaldi-emit-nats";
      commonArgs = "--strict-schemas --root ${ivaldi.lib.rootDir} --root ${skidbladnirRoot}";
    in
      pkgs.runCommand "skidbladnir-policy-emitters-audit" {nativeBuildInputs = [pkgs.jq];} ''
        set -euo pipefail

        echo "=== 1. Zero-Drift .sops.yaml Audit ==="
        ${baugrBin} ${commonArgs} --json project read-secret \
          | ${emitSops} --keys ${policyArtifactsSrc}/secrets/keys.json --audit ${policyArtifactsSrc}/.sops.yaml

        echo "=== 2. Zero-Drift policy/tailscale.json Audit ==="
        ${baugrBin} ${commonArgs} --json project mesh-connect \
          | ${emitTailscale} > generated-tailscale.json
        diff -u ${policyArtifactsSrc}/policy/tailscale.json generated-tailscale.json

        echo "=== 3. Zero-Drift policy/nats-rbac.json Audit ==="
        ${baugrBin} ${commonArgs} --json project nats-queue \
          | ${emitNats} > generated-nats.json
        diff -u ${policyArtifactsSrc}/policy/nats-rbac.json generated-nats.json

        echo "=== 4. verft-cap Declarative Capability DAG & Posture Checks ==="
        ${verftCapBin} --json list --cap-dir ${capabilitiesSrc} | jq -e 'length == 5' >/dev/null
        ${verftCapBin} --json plan --cap-dir ${capabilitiesSrc} --posture online sops-root github-cli r2-admin \
          | jq -e '(.ordered_ids | sort) == ["github-cli", "r2-admin", "sops-root"] and .effective_ttl_seconds == 900' >/dev/null
        ${verftCapBin} --json plan --cap-dir ${capabilitiesSrc} --posture offline breakglass \
          | jq -e '.ordered_ids == ["sops-root", "breakglass"]' >/dev/null

        # Negative posture/conflict guard: online session MUST reject breakglass!
        if ${verftCapBin} plan --cap-dir ${capabilitiesSrc} --posture online breakglass; then
          echo "ERROR: verft-cap unexpectedly allowed offline breakglass in online posture!" >&2
          exit 1
        fi
        # Negative conflict guard: breakglass + github-cli MUST conflict!
        if ${verftCapBin} plan --cap-dir ${capabilitiesSrc} --posture offline breakglass github-cli; then
          echo "ERROR: verft-cap unexpectedly allowed breakglass + github-cli together!" >&2
          exit 1
        fi

        echo "SKIDBLADNIR_POLICY_EMITTERS_AND_CAP_AUDIT_OK" > $out
      '';
  in {
    inherit (realized) nixosConfigurations;

    packages = forAllSystems ({
      system,
      pkgs,
    }:
      (realized.standalonePackages system)
      // {
        default = verft.packages.${system}.verft;
        docs-site = mkDocsSite system pkgs;
      });

    devShells = forAllSystems ({
      system,
      pkgs,
    }: let
      baseShells = realized.devShells system;
    in
      baseShells
      // {
        default = pkgs.mkShell {
          inputsFrom = [baseShells.default];
          packages = [
            verft.packages.${system}.verft
            ivaldi.packages.${system}.emit-sops
            ivaldi.packages.${system}.emit-tailscale
            ivaldi.packages.${system}.emit-nats
          ];
        };
      });

    checks = forAllSystems ({
      system,
      pkgs,
    }:
      {
        fleet-check-and-drt = mkFleetCheckAndDrt system pkgs;
        adversarial-12-attacks = mkAdversarialCheck system pkgs;
        s1-erg-l2-equiv = mkS1EquivCheck system pkgs;
        policy-emitters-audit = mkPolicyEmittersAudit system pkgs;
        docs-site = mkDocsSite system pkgs;
        nix-fmt = pkgs.runCommand "skidbladnir-nix-fmt" {nativeBuildInputs = [pkgs.alejandra];} ''
          alejandra --check ${nixFilesSrc}
          echo "ALEJANDRA_OK" > $out
        '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        vm-astrolabe-smoke = import ./tests/vm/astrolabe-smoke.nix {inherit pkgs lib inputs;};
      });

    formatter = forAllSystems ({pkgs, ...}: pkgs.alejandra);
  };
}
