{...}: {
  nixos = {
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    zramSwap.enable = true;
    environment.etc."verft/hardware-profile.json".text = builtins.toJSON {
      host = "x240";
      vendor = "lenovo-thinkpad-x240";
      zramSwap = true;
    };
  };
}
