{ config, pkgs, lib, ... }:
let
  cfg = config.services.system76-scheduler;
in
{
  options.services.system76-scheduler = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.system76-scheduler;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];

    finit.services.system76-scheduler = {
      description = "manage process priorities and CFS scheduler latencies for improved responsiveness on the desktop";
      command = "${cfg.package}/bin/system76-scheduler daemon";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      nohup = true;
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "system76-scheduler.env" (''
        PATH="${lib.makeBinPath [ pkgs.kmod pkgs.gnutar pkgs.xz ]}:$PATH"
      '' + lib.optionalString cfg.debug ''
        RUST_LOG=system76_scheduler=debug
      '');
    };
  };
}
