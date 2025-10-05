{ config, pkgs, lib, ... }:
{
  # provider module
  options.providers.generator = {
    backend = lib.mkOption {
      type = lib.types.enum [ "sops" ];
      default = "sops";
      description = ''
      '';
    };

    values = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.mkOptionType {
          name = "coercibleToString";
          description = "value that can be coerced to string";
          check = lib.strings.isConvertibleWithToString;
          merge = lib.mergeEqualOption;
        }
      );
      default = { };
      visible = false;
    };

    files = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          # text = lib.mkOption {
          #   type = lib.types.lines;
          # };

          file = lib.mkOption {
            type = lib.types.path;
          };

          path = lib.mkOption {
            type = lib.types.singleLineStr;

            # TODO: implementation specific default value
            default = "/run/secrets/rendered/${name}";
          };
        };
      }));
      default = { };
      description = ''
      '';
    };
  };

  config = {
    # sops.templates."your-config-with-secrets.toml".content

    sops.templates = lib.mapAttrs (k: v: {
      inherit (v) file;
    }) config.providers.generator.files;

    providers.generator.values = lib.mapAttrs (
      name: _: lib.mkDefault "<SOPS:${builtins.hashString "sha256" name}:PLACEHOLDER>"
    ) config.sops.secrets;
  };


#   config = {
#     # forgejo module
#     providers.generator.files =
#     let
#       configFileTemplate = (pkgs.formats.ini { }).generate "forgejo.ini" config.services.forgejo.settings;
#     in
#     {
#       forgejo = {
#         file = configFileTemplate;
#         user = "forgejo";
#         group = "forgejo";
#       };
#     };
#
#     finit.services.forgejo =
#     let
#       configFile = config.providers.generator.files.forgejo.path;
#     in
#     {
#       description = "forgejo service";
#       # TODO: would it be nice to have usr/sops/forgejo condition?
#       conditions = [ "services/syslog/running" "sops" ];
#       command = "${lib.getExe config.services.forgejo.package} --config-file ${configFile}";
#     };
#
#     # user configuration
#     services.forgejo.settings = {
#       mail.PASSWD = config.providers.generator.values."mail/password";
#     };
#   };
}
