#!/bin/sh

nix --extra-experimental-features "flakes nix-command" build .#
./result/activate
initctl reload
nix --extra-experimental-features "flakes nix-command" build --profile /nix/var/nix/profiles/system .#
nix --extra-experimental-features "flakes nix-command" run .#grub
