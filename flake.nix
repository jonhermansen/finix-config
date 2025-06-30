{
  description = "my finix os config";

  inputs = {
    finix.url = "github:aanderse/finix";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { finix, nixpkgs, sops-nix, ... }:
    let
      inherit (nixpkgs) lib;

      pkgs = import nixpkgs {
        system = "x86_64-linux";

        config.allowUnfree = true;
        overlays = [
          finix.overlays.default
          sops-nix.overlays.default

          (final: prev: {
            # without-systemd
            hyprland = prev.hyprland.override { withSystemd = false; };
            niri = prev.niri.override { withSystemd = false; };
            # seatd = prev.seatd.override { systemdSupport = false; };
            swayidle = prev.swayidle.override { systemdSupport = false; };
            waybar = prev.waybar.override { systemdSupport = false; };
            xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
            xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };
          })
        ];
      };

      # modules = builtins.attrValues finix.nixosModules;
      modules = lib.attrValues {
        inherit (finix.nixosModules)
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
          mdevd # required for synit... see comment above
          niri
          nix-daemon
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
    {
      packages.x86_64-linux.default = os.config.system.topLevel;
    };

  nixConfig = {
    extra-experimental-features = [ "flakes" "nix-command" "pipe-operators" ];
  };
}
