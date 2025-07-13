{ config, pkgs, lib, ... }:
let
#   libinput' = (pkgs.libinput.override {
#     udev = pkgs.libudev-zero;
#   }).overrideAttrs (o: {
#     mesonFlags = (o.mesonFlags or [ ]) ++ [
#       "-Dlibwacom=false"
#     ];
#   });
#
#   niri' = pkgs.niri.override {
#     withSystemd = false;
#     libinput = libinput';
#   };
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops
    ./openresolv.nix
    ./pam.nix
    ./system76-scheduler.nix
  ];

  # TODO: grub.sh doesn't read boot.kernelParams yet
  boot.kernelParams = [
    # https://community.frame.work/t/linux-battery-life-tuning/6665/156
    "nvme.noacpi=1"
  ];

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = "/home/aaron/framework/secrets.yaml";
  sops.age.sshKeyPaths = [ "/var/lib/sshd/ssh_host_ed25519_key" ];

  sops.secrets."aaron/password".neededForUsers = true;

  networking.hostName = "framework";

  finit.runlevel = 3;

  finit.tasks.charge-limit.command = "${lib.getExe pkgs.framework-tool} --charge-limit 80";
  finit.tasks.nftables.command = "${lib.getExe pkgs.nftables} -f /etc/nftables.rules";

  # TODO: create a base system profile
  services.atd.enable = true;
  services.chrony.enable = true;
  services.fcron.enable = true;
  services.dbus.enable = true;
  services.dbus.package = pkgs.dbus.override { enableSystemd = false; };
  services.iwd.enable = true;
  services.nix-daemon.enable = true;
  services.nix-daemon.nrBuildUsers = 32;
  services.nix-daemon.settings = {
    experimental-features = [ "flakes" "nix-command" ];
    download-buffer-size = 524288000;
    fallback = true;
    log-lines = 25;
    warn-dirty = false;

    substituters = [ "https://aanderse.cachix.org" ];
    trusted-public-keys = [ "aanderse.cachix.org-1:IJprPrTexBBGauCxrGF9KizIQJUZCDwMT+R9OisqCPM=" ];
  };
  services.openssh.enable = true;
  # TODO: finit reload triggers...
  environment.etc."finit.d/sshd.conf".text = lib.mkAfter ''

    # ${config.environment.etc."ssh/sshd_config".source}
  '';
  services.sysklogd.enable = true;
  services.udev.enable = true;
  services.mdevd.enable = false;
  # none of these rules validate that the groups actually exist...
  services.mdevd.hotplugRules = [
    "null        root:root 666 @chmod 666 $MDEV"
    "zero        root:root 666"
    "full        root:root 666"
    "random      root:root 444"
    "urandom     root:root 444"
    "hwrandom    root:root 444"
    "grsec       root:root 660"
    "kmem        root:root 640"
    "mem         root:root 640"
    "port        root:root 640"
    "console     root:tty 600 @chmod 600 $MDEV"
    "ptmx        root:tty 666"
    "pty.*       root:tty 660"
    "tty         root:tty 666"
    "tty[0-9]*   root:tty 660"
    "vcsa*[0-9]* root:tty 660"
    "ttyS[0-9]*  root:dialout 660"
    "card[0-9]   root:video 660 =dri/"
    "dri/.*      root:video 660"
    "SUBSYSTEM=input;.* root:input 660"
    "SUBSYSTEM=sound;.*  root:audio 660"
  ];
  services.polkit.enable = true;
  programs.openresolv.enable = true;
  programs.bash.enable = true;
  programs.fish.enable = true;

  # TODO: create graphical desktop profiles
  services.rtkit.enable = true;
  services.bluetooth.enable = true;
  services.seatd.enable = true;
  services.ddccontrol.enable = true;
  programs.regreet.enable = true;
  programs.niri.enable = true;
  # programs.niri.package = niri';
  programs.hyprlock.enable = true;
  programs.hyprland.enable = true;
  programs.sway.enable = true;
  programs.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  programs.xwayland-satellite.enable = true;

  services.system76-scheduler.enable = true;

  # TODO: services.system76-scheduler.settings
  environment.etc."system76-scheduler/config.kdl".text = ''
    version "2.0"

    process-scheduler enable=true {
      refresh-rate 60
      execsnoop true

      assignments {
        nix-daemon io=(best-effort)4 sched="batch" {
          include cgroup="/system/nix-daemon"
        }
      }
    }
  '';

  finit.services.nix-daemon.cgroup.settings = {
    "cpu.max" = "800000 100000";
    "cpu.weight" = 80;
  };

  # misc
  services.fprintd.enable = true;
  services.fstrim.enable = true;
  services.zfs.autoSnapshot.enable = true;
  services.zfs.autoSnapshot.flags = "-k -p --utc";
  services.zfs.autoScrub.enable = true;
  services.tzupdate.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.zerotierone.enable = true;
  services.incus.enable = true;
  finit.services.incusd.manual = true;

  # NOTE: https://wiki.alpinelinux.org/wiki/Polkit#Using_polkit_with_seatd
  services.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      // allow user "aaron" to utilize the fingerprint reader
      // not great for security but acceptible given this is a single user laptop... i guess
      if (subject.user == "aaron" && action.id.startsWith("net.reactivated.fprint.device.")) {
        return polkit.Result.YES;
      }

      if (subject.isInGroup("${config.services.seatd.group}") && action.id.startsWith("org.freedesktop.RealtimeKit1.")) {
        return polkit.Result.YES;
      }

      if (subject.isInGroup("${config.services.seatd.group}") && action.id.startsWith("org.freedesktop.UPower.PowerProfiles.")) {
        return polkit.Result.YES;
      }
    });
  '';

  # homelab certificate authority
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIBoTCCAUmgAwIBAgIQe2OFt43uF4Sb5jDGhPnyhDAKBggqhkjOPQQDAjAwMRIw
      EAYDVQQKEwlzbWFsbHN0ZXAxGjAYBgNVBAMTEXNtYWxsc3RlcCBSb290IENBMB4X
      DTI0MDgxMDE2MzIzOFoXDTM0MDgwODE2MzIzOFowMDESMBAGA1UEChMJc21hbGxz
      dGVwMRowGAYDVQQDExFzbWFsbHN0ZXAgUm9vdCBDQTBZMBMGByqGSM49AgEGCCqG
      SM49AwEHA0IABJDOXimoUROCIChjTjF+ZUBBVJdRR2Tlf14bpaLXLfqSJsuP3KO9
      tCLF0qp+iwksOfZur7oIw/Fq1i+zt592J/ajRTBDMA4GA1UdDwEB/wQEAwIBBjAS
      BgNVHRMBAf8ECDAGAQH/AgEBMB0GA1UdDgQWBBSXX+tNn8NffSeoabfNBwenT2Nh
      3DAKBggqhkjOPQQDAgNGADBDAiABz4DuLfUnP4O0rpjawvqkzV42jG2IfFPpKGFn
      n4IkxQIfaUGmo6r05finZYU2zKbmUsfL5BrQ8XBcOcFlG6UQkQ==
      -----END CERTIFICATE-----
    ''
  ];

  xdg.portal.portals = [
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-wlr
    pkgs.xdg-desktop-portal-gtk
  ];

  services.dbus.packages = [
    pkgs.dconf
  ];

  environment.etc."sudoers".text = lib.mkAfter ''
    %${config.services.seatd.group} ALL = (root) NOPASSWD: /run/current-system/sw/bin/pm-suspend
  '';

  fonts.fontconfig.enable = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome
    liberation_ttf
    mplus-outline-fonts.githubRelease
    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    noto-fonts
    noto-fonts-emoji
    proggyfonts
  ];

  # TODO: move to services.sysklogd module
  environment.etc."syslog.d/rotate.conf".text = ''
    rotate_size  1M
    rotate_count 5
  '';

  providers.privileges.rules = [
    { command = "/run/current-system/sw/bin/poweroff";
      users = [ "aaron" ];
      requirePassword = false;
    }
    { command = "/run/current-system/sw/bin/reboot";
      users = [ "aaron" ];
      requirePassword = false;
    }
  ];

  services.udev.packages = [
    config.services.udev.package

    pkgs.brightnessctl
  ];

  hardware.firmware = with pkgs; [
    linux-firmware
    intel2200BGFirmware
    rtl8192su-firmware
    rt5677-firmware
    rtl8761b-firmware
    zd1211fw
    alsa-firmware
    sof-firmware
    libreelec-dvb-firmware

    broadcom-bt-firmware
    b43Firmware_5_1_138
    b43Firmware_6_30_163_46
    xow_dongle-firmware

    pkgs.wireless-regdb
  ];

  users.users.aaron = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;
    group = "users";
    home = "/home/aaron";
    createHome =  true;

    extraGroups = [
      config.services.seatd.group "audio" "incus-admin" "input" "video" "wheel"
    ];
  };

  environment.pathsToLink = [
    # TODO: xdg.icon module
    "/share/icons"
    "/share/pixmaps"

    # login managers
    # "/share/wayland-sessions"
  ];

  environment.systemPackages = [
    pkgs.alacritty
    pkgs.bzmenu
    pkgs.dex
    pkgs.ghostty
    pkgs.iwmenu
    pkgs.kanshi
    pkgs.mako
    pkgs.playerctl
    pkgs.swaybg
    pkgs.swayidle
    pkgs.walker
    pkgs.waybar

    pkgs.direnv
    pkgs.dnsutils
    pkgs.git
    pkgs.htop
    pkgs.lnav
    pkgs.jq
    pkgs.mailutils
    pkgs.man
    pkgs.micro
    pkgs.nano
    pkgs.ncdu
    pkgs.nix-output-monitor
    pkgs.nix-top
    pkgs.nixd
    pkgs.npins
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.tree
    pkgs.wget
    pkgs.yazi

    pkgs.chromium
    pkgs.firefox
    pkgs.qbittorrent
    pkgs.steam
    pkgs.xarchiver

    pkgs.lite-xl
    pkgs.zed-editor
    pkgs.vscode

    pkgs.discord
    (pkgs.element-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.joplin-desktop
    pkgs.quasselClient
    (pkgs.signal-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.slack

    pkgs.bluetui
    pkgs.brightnessctl
    pkgs.framework-tool
    pkgs.libnotify
    pkgs.mixxc
    pkgs.ncpamixer
    pkgs.pipewire
    pkgs.pmutils
    pkgs.wireplumber
    pkgs.wl-clipboard
    pkgs.xdg-utils

    pkgs.iproute2
    pkgs.iputils
    pkgs.nettools
    pkgs.nftables


    pkgs.bustle
    pkgs.d-spy
    pkgs.dconf-editor

    pkgs.perl
    pkgs.strace
		pkgs.tcl-9_0

		pkgs.nix-tree

    pkgs.hicolor-icon-theme # TODO: xdg.icon module
    pkgs.catppuccin-cursors.mochaLight

    pkgs.dconf

    pkgs.util-linux
    pkgs.e2fsprogs
    pkgs.kbd

    # TODO: grub module
    pkgs.efibootmgr
    pkgs.grub2_efi


    pkgs.rink
    pkgs.libqalculate

    pkgs.imv # TODO: set as default image viewer

    (pkgs.kodi-wayland.withPackages (p: [ p.jellyfin p.jellycon ]))
  ];

  hardware.console.keyMap = "us";
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
