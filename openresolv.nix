# TODO: services.iwd can refer to this... i guess we should call it programs.resolvconf
{ config, pkgs, lib, ... }:
let
  cfg = config.programs.openresolv;
in
{
  options.programs.openresolv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openresolv;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."resolvconf.conf".text = ''
      resolv_conf=/etc/resolv.conf
    '';

    environment.systemPackages = [ cfg.package ];

    finit.tasks.openresolv = {
      command = "${lib.getExe cfg.package} -u";
    };

    environment.etc."finit.d/openresolv.conf".text = lib.mkAfter ''

      # force a restart on configuration change
      # ${config.environment.etc."resolvconf.conf".source}
    '';
  };
}
