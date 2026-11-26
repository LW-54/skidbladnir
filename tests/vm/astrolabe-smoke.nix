# Skidbladnir F3 Live KVM QEMU Integration Gate — Situated `astrolabe` (`adje.app`) Smoke Test
# Boots Skidbladnir's real `hw-astrolabe` + Ivaldi core services wired with `adje.app` &
# `obs.astrolabe.tailnet.ts.net`, verifying offline TLS ingress (`vault.adje.app`, `ntfy.adje.app`),
# all `/etc/verft/*.json` manifests, and live `systemctl stop tailscaled.service` survival!
{
  pkgs,
  lib,
  inputs,
}: let
  ivAgents = inputs.ivaldi.lib.agentsDir;
  hwAstrolabe = (import ../../agents/hardware/hw-astrolabe/interior.nix) {inherit inputs;};
  tailscaleMod = (import (ivAgents + "/mesh/tailscale/interior.nix")) {};
  caddyMod = (import (ivAgents + "/mesh/caddy-public/interior.nix")) {
    inherit lib;
    bound = {
      "config:domain".value = "adje.app";
      "http:route" = {
        vault = {
          subdomain = "vault";
          port = 8222;
        };
        ntfy = {
          subdomain = "ntfy";
          port = 2586;
        };
      };
    };
  };
  vaultwardenMod = (import (ivAgents + "/apps/vaultwarden/interior.nix")) {
    inherit lib;
    self = {
      promises = [
        {
          polarity = "offer";
          ptype = "http:route";
          key = "vault";
          payload = {
            subdomain = "vault";
            port = 8222;
          };
        }
      ];
    };
    bound = {
      "config:domain".value = "adje.app";
    };
  };
  ntfyMod = (import (ivAgents + "/apps/notify-ntfy/interior.nix")) {
    bound = {
      "config:domain".value = "adje.app";
    };
  };
  gitMod = (import (ivAgents + "/apps/git/interior.nix")) {inherit pkgs lib;};
  pullMod = (import (ivAgents + "/gitops/pull/interior.nix")) {
    inherit inputs pkgs lib;
    bound = {
      "cache:cdn" = {
        r2-cdn.url = "https://cache.adje.app";
      };
      "critical-probes" = {
        vaultwarden-alive = {};
        caddy-public = {};
        tailscale-alive = {};
      };
    };
  };
  resticMod = (import (ivAgents + "/storage/backup-restic/interior.nix")) {
    inherit pkgs lib;
    bound = {
      "state:backup" = {
        "/var/lib/vaultwarden".path = "/var/lib/vaultwarden";
        "/var/lib/verft-pull".path = "/var/lib/verft-pull";
      };
      "backup:offhost" = {
        r2-worm = {};
        hbox-sftp = {};
      };
    };
  };
  fluentMod = (import (ivAgents + "/obs/fluent-node/interior.nix")) {
    inherit lib;
    bound = {
      "obs-ingest" = {
        obs-ingest = {
          host = "obs.astrolabe.tailnet.ts.net";
          port = 9428;
        };
      };
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "skidbladnir-vm-astrolabe-smoke";

    nodes.astrolabe = {
      imports = [
        hwAstrolabe.nixos
        tailscaleMod.nixos
        caddyMod.nixos
        vaultwardenMod.nixos
        ntfyMod.nixos
        gitMod.nixos
        pullMod.nixos
        resticMod.nixos
        fluentMod.nixos
      ];

      virtualisation.memorySize = 1024;
      networking.hostName = "astrolabe";
      environment.systemPackages = [pkgs.curl pkgs.jq];
      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };
      services.caddy.globalConfig = ''
        local_certs
      '';
      system.stateVersion = "25.05";
    };

    testScript = ''
      import json

      astrolabe.start()
      astrolabe.wait_for_unit("multi-user.target")
      for unit in ["sshd.service", "tailscaled.service", "vaultwarden.service", "ntfy-sh.service", "caddy.service", "fluent-bit.service"]:
          astrolabe.wait_for_unit(unit)

      for port in [22, 8222, 2586, 443]:
          astrolabe.wait_for_open_port(port)

      # 1. Verify situated adje.app TLS endpoints offline
      astrolabe.succeed("curl -kfsS --resolve vault.adje.app:443:127.0.0.1 https://vault.adje.app/alive")
      astrolabe.succeed("curl -kfsS --resolve ntfy.adje.app:443:127.0.0.1 https://ntfy.adje.app/v1/health")

      # 2. Verify all situated /etc/verft/*.json artifacts reflect real Skidbladnir bindings
      hw = json.loads(astrolabe.succeed("cat /etc/verft/hardware-profile.json"))
      assert hw["host"] == "astrolabe" and hw["vendor"] == "qemu-kvm" and hw["zramSwap"] is True, hw

      fluent = json.loads(astrolabe.succeed("cat /etc/verft/fluent-node.json"))
      assert fluent["ingestTargets"] == ["https://obs.astrolabe.tailnet.ts.net:9428"], fluent

      restic = json.loads(astrolabe.succeed("cat /etc/verft/restic-plan.json"))
      assert restic["keepDaily"] > restic["wormLockDays"] and set(restic["repos"]) == {"hbox-sftp", "r2-worm"}, restic

      probes = json.loads(astrolabe.succeed("cat /etc/verft/pull-rollback-probes.json"))
      assert set(probes) == {"caddy-public", "tailscale-alive", "vaultwarden-alive"}, probes

      # 3. Stop tailscaled live — public adje.app HTTPS & sshd MUST stay 100% operational!
      astrolabe.succeed("systemctl stop tailscaled.service")
      astrolabe.succeed("curl -kfsS --resolve vault.adje.app:443:127.0.0.1 https://vault.adje.app/alive")
      astrolabe.succeed("curl -kfsS --resolve ntfy.adje.app:443:127.0.0.1 https://ntfy.adje.app/v1/health")
      astrolabe.succeed("systemctl is-active sshd.service caddy.service vaultwarden.service ntfy-sh.service fluent-bit.service")
    '';
  }
