#!/bin/sh

nix build .#
./result/activate
initctl reload

nix build --profile /nix/var/nix/profiles/system .#
nix run .#grub
