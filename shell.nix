let
  sources = import ./lon.nix;

  pkgs = import sources.nixpkgs { };
in
  pkgs.mkShell {
    shellHook = ''
      export NIX_PATH=${pkgs.lib.concatMapAttrsStringSep ":" (k: v: "${k}=${v}") sources}
    '';
  }
