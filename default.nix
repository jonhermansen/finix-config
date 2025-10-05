let
  inherit (pkgs) lib;

  pkgs = import <nixpkgs> {
    system = "x86_64-linux";

    config.allowUnfree = true;
    overlays = [
      (import (<finix> + "/overlays/default.nix"))

      (final: prev: {
        inherit (import <sops-nix> { pkgs = final; }) sops-install-secrets;
      })

      (final: prev: {
        # without-systemd
        hyprland = prev.hyprland.override { withSystemd = false; };
        niri = prev.niri.override { withSystemd = false; };
        # procps = prev.procps.override { withSystemd = false; };
        seatd = prev.seatd.override { systemdSupport = false; };
        swayidle = prev.swayidle.override { systemdSupport = false; };
        waybar = prev.waybar.override { systemdSupport = false; };
        xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
        xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };
      })
    ];
  };

  # modules = builtins.attrValues finix.nixosModules;
  modules = lib.attrValues {
    inherit (import (<finix> + "/modules"))
      # required for evaluation
      default # TODO: do we want to exclude finit when we build synit? and vice versa?
      elogind
      privileges
      scheduler #
      seatd

      # required for runtime
      dbus
      tmpfiles
      udev
      mdevd # required for synit... see comment above

      # selected modules
      atd
      bash
      bluetooth
      chronyd
      ddccontrol
      fcron
      fish
      fprintd
      fstrim
      getty
      gnome-keyring
      greetd
      hyprlock
      incus
      iwd
      labwc
      mariadb
      niri
      nix-daemon
      nzbget
      openssh
      polkit
      power-profiles-daemon
      regreet
      rtkit
      seahorse
      sysklogd
      tzupdate
      upower
      xwayland-satellite
      zerotierone
      zfs

      # testing
      hyprland
      sway
    ;
  };

  os = lib.evalModules {
    specialArgs = {
      inherit pkgs;
    };

    modules = [
      ./configuration.nix
    ] ++ modules;
  };
in
  os.config.system.topLevel
