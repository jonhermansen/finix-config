{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "igc"
  ];
  boot.kernelModules = [
    # FIXME: causing virtualbox not to work
    # "kvm-intel"

    # bluetooth keyboard didn't work without this
    # https://github.com/bluez/bluez/issues/531#issuecomment-1913058753
    "uhid"
  ];

  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos2";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/boot2";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/tmp" = {
    fsType = "tmpfs";
    options = [
      "rw"
      "nosuid"
      "nodev"
      "mode=1777"
      "X-mount.mkdir"
    ];
  };
}
