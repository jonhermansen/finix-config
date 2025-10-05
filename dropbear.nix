{ config, pkgs, lib, ... }:
let
  cfg = config.services.dropbear;

  keyOpts = { config, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "rsa" "ecdsa" "ed25519" ];
        default = "ed25519";
      };

      path = lib.mkOption {
        type = lib.types.path;
      };

      bits = lib.mkOption {
        type = with lib.types; nullOr int;
        default = null;
      };

      comment = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };
    };

    config = {
      path = "/var/lib/dropbear/dropbear_${config.type}_host_key";
    };
  };

  # -r hostkey
  # -F don't fork
  # -P /run/dropbear.pid

  # -b banner
  # -E log to standard error rather than syslog
  # -m don't display motd
  # -w disallow root logins
  # -s disable password logins
  # -g disable password logins for root
  # -t enable two-factor authentication
  # -j disable local port forwarding
  # -k disable remote port forwarding
  # -p [address:]port - can be repeated up to 10 times
  # -l listen on the specified interface
  # -a allow remote hosts to connect to forwarded ports
  # -D authorized_keys_dir
in
{
  options.services.dropbear = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dropbear;
    };

    authorizedKeysDir = lib.mkOption {
      type = with lib.types; nullOr str;
      default = "/etc/dropbear/authorized_keys_dir.d";
      example = "~/.ssh";
    };

    # Key size in bits, should be a multiple of 8
    # ECDSA has sizes 256 384 521
    # Ed25519 has a fixed size of 256 bits
    hostKeys = lib.mkOption {
      type = with lib.types; listOf (submodule keyOpts);
      default = [ { } ];
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    # services.dropbear.hostKeys = [
    #   { type = "ed25519"; }
    # ];

    # services.dropbear.extraArgs = lib.optionals (cfg.authorizedKeysDir != null) [
    #   "-D" cfg.authorizedKeysDir
    # ] ++ lib.map (key: [ "-r" key.path ]) cfg.hostKeys;

    # services.dropbear.extraArgs = lib.mkBefore ([
    #   "-F"
    # ] ++ lib.optionals (c)
    #   "-r" "/var/lib/dropbear/dropbear_ed25519_host_key"
    # ] ++ lib.optionals (cfg.authorizedKeysDir != null) [
    #   "-D" cfg.authorizedKeysDir
    # ]);

    environment.systemPackages = [
      cfg.package
    ];

    # environment.etc =
    #   let
    #     usersWithKeys = lib.filterAttrs (user: user.authorizedKeys or null != null) config.users.users;
    #     mkAuthKeyFile = user: lib.nameValuePair "dropbear/authorized_keys.d/${user.name}" {
    #       mode = "0444";
    #       text = lib.concatStringsSep "\n" user.authorizedKeys;
    #     };
    #   in
    #     lib.mkIf (cfg.authorizedKeysDir == "/etc/dropbear/authorized_keys_dir.d") (lib.listToAttrs (map mkAuthKeyFile usersWithKeys));

    # lib.concatMapStringsSep "\n" (value:
    # let
    #   args = [
    #     "-t" value.type
    #     "-f" value.path
    #   ] ++ lib.optional (value.bits != null) [
    #     "-s" value.bits
    #   ] ++ lib.optional (value.comment != null) [
    #     "-C" value.comment
    #   ];
    # in
    # ''
    #   if ! [ -s "${value.path}" ]; then
    #     ${cfg.pacage}/bin/dropbearkey ${lib.escapeShellArgs args}
    #   fi
    # '') os.config.services.dropbear.hostKeys

    finit.tasks.dropbear-keygen = {
      description = "generate ssh host keys";
      log = true;
      command = pkgs.writeShellScript "ssh-keygen.sh" ''
        if ! [ -s "/var/lib/dropbear/dropbear_ed25519_host_key" ]; then
          ${cfg.package}/bin/dropbearkey -t ed25519 -f "/var/lib/dropbear/dropbear_ed25519_host_key"
        fi
      '';
    };

    finit.services.dropbear = {
      description = "dropbear ssh daemon";
      conditions = [ "net/lo/up" "service/syslogd/ready" "task/dropbear-keygen/success" ];
      command = "${pkgs.dropbear}/bin/dropbear -F -r /var/lib/dropbear/dropbear_ed25519_host_key" + lib.escapeShellArgs cfg.extraArgs;
      cgroup.name = "user";
      log = true;
      nohup = true;

      # TODO: dropbear doesn't use PAM so we need to keep these variables in sync with security.pam.environment!
      env = pkgs.writeText "dropbear.env" ''
        PATH=${config.security.wrapperDir}:/run/current-system/sw/bin
      '';
      # only PATH and LD_LIBRARY_PATH will pass through
    };

    services.tmpfiles.dropbear.rules = [
      "d /var/lib/dropbear 0755"
    ];
  };
}
