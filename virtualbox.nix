# virtualbox host, not guest...
{ config, pkgs, lib, ... }:
let
  cfg = config.programs.virtualbox;

  # TODO: mdevd
  udevRules = pkgs.writeTextDir "/etc/udev/rules.d/virtualbox.rules" ''
    SUBSYSTEM=="usb_device", ACTION=="add", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
    SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
    SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
    SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"

    # if not kvm
    KERNEL=="vboxdrv",    OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
    KERNEL=="vboxdrvu",   OWNER="root", GROUP="root",      MODE="0666", TAG+="systemd"
    KERNEL=="vboxnetctl", OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
  '';
in
{
  options.programs.virtualbox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.virtualbox;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "vboxdrv"
      "vboxnetadp"
      "vboxnetflt"
    ];

    boot.extraModulePackages = [
      (config.boot.kernelPackages.virtualbox.override { virtualbox = cfg.package; })
    ];

    environment.systemPackages = [ cfg.package ];

    services.udev.packages = [
      udevRules
    ];

    users.groups = {
      vboxusers.gid = config.ids.gids.vboxusers;
    };

    # https://forums.virtualbox.org/viewtopic.php?p=556540#p556540
    environment.etc."modprobe.d/blacklist-kvm.conf".text = ''
      # kernel 6.12 and later ship with kvm enabled by default, which breaks vbox
      blacklist kvm
      blacklist kvm_intel
    '';
  };
}
