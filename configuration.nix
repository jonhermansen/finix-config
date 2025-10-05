{ config, pkgs, lib, ... }:
let
  libudev-zero' = pkgs.libudev-zero.overrideAttrs (_: {
    src = pkgs.fetchFromGitHub {
      owner = "illiliti";
      repo = "libudev-zero";
      rev = "bbeb7ad51c1edb7ab3cf63f30a21e9bb383b7994";
      sha256 = "sha256-hQoLnKpT/cnGyUl56DnHjZ0nfenLPI9EvmOejqEPxfc=";
    };
  });

  wlroots' = pkgs.wlroots_0_19.override {
    libinput = libinput';
  };

  pipewire' = if config.services.udev.enable then
    pkgs.pipewire
  else
    pkgs.callPackage ./pipewire.nix {
      path = pkgs.path + "/pkgs/development/libraries/pipewire/";
      enableSystemd = false;
      udevSupport = false;
    };

  wireplumber' = if config.services.udev.enable then
    pkgs.wireplumber
  else
    pkgs.wireplumber.override {
      pipewire = pipewire';
    };

  pulseaudio' = pkgs.pulseaudio.override {
    udevSupport = false;
    useSystemd = false;
  };

  libinput' = (pkgs.libinput.override {
    udev = libudev-zero';
  }).overrideAttrs (o: {
    mesonFlags = (o.mesonFlags or [ ]) ++ [
      "-Dlibwacom=false"
    ];
  });

  niri' = if config.services.udev.enable then
    pkgs.niri
  else
    pkgs.niri.override {
      withSystemd = false;
      libinput = libinput';
      eudev = libudev-zero';
    };

  labwc' = if config.services.udev.enable then
    pkgs.labwc
  else
    pkgs.labwc.override {
      libinput = libinput';
      wlroots_0_19 = wlroots';
    };
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops
    ./openresolv.nix
    ./pam.nix
    ./system76-scheduler.nix
    ./fwupd.nix
    ./test.nix
    ./uptime-kuma.nix
    ./dropbear.nix

    ./limine.nix
    ./virtualbox.nix
  ];

  boot.limine.extraEntries = ''
    /Zorin OS
      protocol: linux
      cmdline: blahblah
      foo: bar

    /+finix
      //gen 1
        protocl: linux
        cmdline: blah

      //gen 2
        protocl: linux
        cmdline: blah

      //gen 3
        protocl: linux
        cmdline: blah

      //gen 4
        protocl: linux
        cmdline: blah
  '';

  security.pam.environment = {
    SSH_ASKPASS.default = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

    # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
    LIBVA_DRIVER_NAME.default = "iHD";
  };

  # TODO: grub.sh doesn't read boot.kernelParams yet
  boot.kernelParams = [
    # https://community.frame.work/t/linux-battery-life-tuning/6665/156
    "nvme.noacpi=1"
  ];

  services.uptime-kuma.enable = true;

  # TODO: options for nix remote builders
  environment.etc."nix/machines".enable = true;
  environment.etc."nix/machines".text = lib.concatMapStringsSep "\n" (v: "ssh://${v}.node x86_64-linux - 20 2 benchmark,big-parallel - -") [
    "arche"
    "callisto"
    "europa"
    "helike"
    "herse"
    "kore"
    "metis"
  ];
  finit.services.nix-daemon.env = pkgs.writeText "nix-daemon.env" ''
    PATH="${lib.makeBinPath [ config.services.nix-daemon.package pkgs.util-linux config.services.openssh.package ]}:$PATH"
    CURL_CA_BUNDLE=${config.security.pki.caBundle}
  '';

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = "/home/aaron/framework/secrets.yaml";
  sops.age.sshKeyPaths = [ "/var/lib/sshd/ssh_host_ed25519_key" ];

  sops.secrets."aaron/password".neededForUsers = true;
  # sops.secrets."dev0-hetz/bastion" = { };

#   providers.generator.files = {
#     ssh_config = {
#       file = pkgs.writeText "ssh_config" ''
#         Host dev0-hetz
#           HostName ${config.providers.generator.values."dev0-hetz/bastion"}
#           # IdentityFile ~/.ssh/id_ed25519
#           IdentityFile /home/aaron/.cache/tvbeat/.ssh/id_ed25519
#           Port 443
#           User aanderse
#
#         Host arche.node
#           HostName arche.node
#           ProxyJump dev0-hetz
#           # IdentityFile ~/.ssh/id_ed25519
#           IdentityFile /home/aaron/.cache/tvbeat/.ssh/id_ed25519
#           User aanderse
#       '';
#
#       path = "/etc/ssh/ssh_config";
#       mode = "0444";
#     };
#   };

  # programs.ssh.extraConfig = with config.generators; ''
  #   Host dev0-hetz
  #     HostName ${values."dev0-hetz/bastion"}
  # '';

  networking.hostName = "framework";

  finit.runlevel = 3;

  finit.tasks.charge-limit.command = "${lib.getExe pkgs.framework-tool} --charge-limit 80";
  finit.tasks.nftables.command = "${lib.getExe pkgs.nftables} -f /etc/nftables.rules";

  finit.services.wifid = {
    command = pkgs.callPackage ./wifid/package.nix { };
    log = true;
  };

  finit.services.dropbear.conditions = [ "usr/with-an-e" ];

  # TODO: create a base system profile
  services.atd.enable = true;
  services.chrony.enable = true;
  services.fcron.enable = true;
  services.dbus.enable = true;
  services.fwupd.enable = false;
  services.fwupd.debug = false;
  services.iwd.enable = true;
  services.nix-daemon.enable = true;
  services.nix-daemon.nrBuildUsers = 32;
  services.nix-daemon.settings = {
    experimental-features = [ "flakes" "nix-command" ];
    download-buffer-size = 524288000;
    fallback = true;
    log-lines = 25;
    warn-dirty = false;
    builders-use-substitutes = true;
    build-dir = "/var/tmp";

    substituters = [ "https://jovian-nixos.cachix.org" ];
    trusted-public-keys = [ "jovian-nixos.cachix.org-1:mAWLjAxLNlfxAnozUjOqGj4AxQwCl7MXwOfu7msVlAo=" ];
    trusted-users = [ "root" "@wheel" ];
  };
  services.openssh.enable = false;
  services.dropbear.enable = true;

  # TODO: finit reload triggers...
  environment.etc."finit.d/sshd.conf" = lib.mkIf config.services.openssh.enable {
    text = lib.mkAfter ''

      # ${config.environment.etc."ssh/sshd_config".source}
    '';
  };
  services.sysklogd.enable = true;
  services.udev.enable = lib.mkForce true;
  services.mdevd.enable = ! config.services.udev.enable;
  services.mdevd.debug = true;
  # none of these rules validate that the groups actually exist...
  services.mdevd.hotplugRules = ''
    .* 0:0 660 @${pkgs.finit}/libexec/finit/logit -s -t mdevd "event=$ACTION dev=$MDEV subsystem=$SUBSYSTEM path=$DEVPATH"

    grsec       0:0 660
    kmem        0:0 640
    mem         0:0 640
    port        0:0 640
    console     0:${toString config.ids.gids.tty} 600 @chmod 600 $MDEV
    tty         0:${toString config.ids.gids.tty} 666
    card[0-9]   0:${toString config.ids.gids.video} 660 =dri/

    # alsa sound devices and audio stuff
    pcm.*       root:audio 0660 =snd/
    control.*   root:audio 0660 =snd/
    midi.*      root:audio 0660 =snd/
    seq         root:audio 0660 =snd/
    timer       root:audio 0660 =snd/

    adsp        root:audio 0660 >sound/
    audio       root:audio 0660 >sound/
    dsp         root:audio 0660 >sound/
    mixer       root:audio 0660 >sound/
    sequencer.* root:audio 0660 >sound/

    event[0-9]+ 0:${toString config.ids.gids.input} 660 =input/
    mice        0:${toString config.ids.gids.input} 660 =input/
    mouse[0-9]+ 0:${toString config.ids.gids.input} 660 =input/

    SUBSYSTEM=input;.* 0:${toString config.ids.gids.input} 660
    SUBSYSTEM=sound;.*  0:${toString config.ids.gids.audio} 660
  '';
  services.polkit.enable = true;
  programs.openresolv.enable = true;
  programs.bash.enable = true;
  programs.fish.enable = true;

  programs.virtualbox.enable = true;

  # TODO: create graphical desktop profiles
  services.rtkit.enable = true;
  services.bluetooth.enable = true;
  services.seatd.enable = true;
  services.ddccontrol.enable = true;
  programs.regreet.enable = config.services.udev.enable;
  programs.niri.enable = true;
  programs.niri.package = niri';
  programs.hyprlock.enable = true;
  programs.hyprland.enable = true;
  programs.sway.enable = true;
  programs.labwc.enable = true;
  programs.labwc.package = labwc';
  programs.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  programs.xwayland-satellite.enable = true;

  services.system76-scheduler.enable = true;

  # TODO: services.system76-scheduler.settings
  # nix-daemon io=(best-effort)4 sched="batch" {
  environment.etc."system76-scheduler/config.kdl".text = ''
    version "2.0"

    process-scheduler enable=true {
      refresh-rate 60
      execsnoop true

      assignments {
        nix-daemon io=(idle)4 sched="idle" {
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

  security.pki.certificates = [
    # homelab certificate authority
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

    # local caddy
    ''
      -----BEGIN CERTIFICATE-----
      MIIBozCCAUqgAwIBAgIRANr2xLr5ZiKvfJdzJgwaR2gwCgYIKoZIzj0EAwIwMDEu
      MCwGA1UEAxMlQ2FkZHkgTG9jYWwgQXV0aG9yaXR5IC0gMjAyNSBFQ0MgUm9vdDAe
      Fw0yNTA3MjkxNjI3MjlaFw0zNTA2MDcxNjI3MjlaMDAxLjAsBgNVBAMTJUNhZGR5
      IExvY2FsIEF1dGhvcml0eSAtIDIwMjUgRUNDIFJvb3QwWTATBgcqhkjOPQIBBggq
      hkjOPQMBBwNCAAQ+87jFZAi3YtgPTi6ttp0jSboslaUq1AsQHZ1yOYcTLOoVoTrF
      NZjvu2dMFjImBY8M0093ySHyhTnyKm+jGf6io0UwQzAOBgNVHQ8BAf8EBAMCAQYw
      EgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUK7hD+/RQrUzT8agu9K0hkmsj
      xcQwCgYIKoZIzj0EAwIDRwAwRAIgBp8H/IGb7DtKzCK8/y66L+uqJgOyKqFE6l4W
      SfgIeDMCIHjVvjsyFh3Nhero7LwiB0kZbszT5stt9Hb9pt35nC58
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
      config.services.seatd.group "audio" "incus-admin" "input" "video" "wheel" "vboxusers"
    ];
  };

  environment.pathsToLink = [
    # TODO: xdg.icon module
    "/share/icons"
    "/share/pixmaps"
  ];

  environment.systemPackages = [
    pkgs.alacritty
    pkgs.bzmenu
    pkgs.dex
    pkgs.ghostty
    pkgs.iwmenu
    pkgs.kanshi
    pkgs.mako
    pkgs.musikcube
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
    pkgs.nix-diff
    pkgs.nix-output-monitor
    pkgs.nix-top
    pkgs.nixd
    pkgs.npins
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.tree
    pkgs.wget
    pkgs.yazi

    (pkgs.chromium.override {
      commandLineArgs = [
        "--enable-features=AcceleratedVideoEncoder"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
    pkgs.firefox
    pkgs.qbittorrent
    pkgs.steam
    pkgs.xarchiver

    pkgs.lite-xl
    pkgs.marp-cli
    pkgs.tdf
    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        Google.gemini-cli-vscode-ide-companion
        mkhl.direnv
        ms-python.python
        rust-lang.rust-analyzer
      ];
    })
    pkgs.zed-editor

    pkgs.discord
    (pkgs.element-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.joplin-desktop
    (pkgs.pidgin.override {
      plugins = [
        pkgs.pidgin-otr
        pkgs.pidgin-carbons
        pkgs.pidgin-osd
        pkgs.pidgin-window-merge
        pkgs.purple-plugin-pack
      ];
    })
    pkgs.quasselClient
    (pkgs.signal-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.slack

    pkgs.bluetui
    pkgs.brightnessctl
    pkgs.framework-tool
    pkgs.impala
    pkgs.libnotify
    pkgs.mixxc
    pkgs.wiremix
    pipewire'
    pkgs.pmutils
    wireplumber'
    pkgs.wl-clipboard
    pkgs.xdg-utils

    pkgs.iproute2
    pkgs.iputils
    pkgs.nettools
    pkgs.nftables


    pkgs.bustle
    pkgs.d-spy
    pkgs.dconf-editor
    libinput'

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

    (pkgs.kodi-wayland.withPackages (p: [ p.jellyfin p.jellycon p.a4ksubtitles ]))

    # TODO: add `programs.ssh.*` options
    pkgs.openssh
  ];

  hardware.console.keyMap = "us";
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.graphics.extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];
}
