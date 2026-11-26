{inputs, ...}: {
  nixos = {
    imports = [
      (inputs.nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
    ];
    zramSwap.enable = true;
    environment.etc."verft/hardware-profile.json".text = builtins.toJSON {
      host = "astrolabe";
      vendor = "qemu-kvm";
      zramSwap = true;
    };
  };
}
