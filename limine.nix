{ config, pkgs, lib, ... }:
let
  cfg = config.boot.limine; # TODO: rename namespace

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v:
        if true == v then "yes"
        else if false == v then "no"
        else lib.generators.mkValueStringDefault { } v
      ;
    } ": ";
  };

  # configFile = format.generate "limine.conf" cfg.settings;

  entryOpts = {
    freeformType = (pkgs.formats.keyValue { }).type;
    options = {
      protocol = lib.mkOption {
        type = lib.types.enum [ "linux" "limine" "multiboot" "multiboot1" "multiboot2" "efi" "bios" ];
      };

      cmdline = lib.mkOption {
        type = with lib.types; nullOr str; # TODO: listOf str?
        default = null;
      };
    };
  };
in
{
  options.boot.limine = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.limine;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    # https://codeberg.org/Limine/Limine/src/branch/trunk/CONFIG.md
    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = { };
    };

    extraEntries = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    # boot.limine.settings = lib.mkIf cfg.debug {
    #   verbose = lib.mkForce true;
    # };

    boot.limine.settings = {
      timeout = 10;
      remember_last_entry = false;
      wallpaper = "boot():/boot/limine/wallpaper.png";
    };
  };
}
