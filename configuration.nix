{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
{
  imports = [
    # enable sdcard image generation
    "${modulesPath}/installer/sd-card/sd-image-riscv64-qemu.nix"
  ];

  # for size reduction
  # programs.nix-ld.enable = true;
  boot.enableContainers = false;
  boot.supportedFilesystems = lib.mkForce [ ];
  documentation.enable = false;
  hardware.firmware = lib.mkForce [ ];
  networking.dhcpcd.wait = "if-carrier-up";
  networking.firewall.enable = false;
  nix.enable = false;
  nixpkgs.flake.source = lib.mkForce null;
  programs.command-not-found.enable = false;
  programs.less.lessopen = null;
  services.logrotate.enable = false;
  services.lvm.enable = false;
  services.openssh.enable = false;
  services.udisks2.enable = false;
  system.disableInstallerTools = true;
  system.switch.enable = false;
  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;

  boot = {
    # adds keystone-driver kernel module to the system
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./keystone-driver/package.nix { })
    ];
    # uncomment next line to load keystone-driver by default
    kernelModules = [ "keystone-driver" ];
    blacklistedKernelModules = [
      "8021q"
      "cfg80211"
      "configfs"
      "efi_pstore"
      "fuse"
      "ip_tables"
      "nfnetlink"
      "pstore"
      "qemu_fw_cfg"
      "sch_fq_codel"
      "uio_pdrv_genirq"
    ];
    initrd.kernelModules = lib.mkForce [ ];
    initrd.luks.fido2Support.enable = false;
  };

  # add packages here
  # https://search.nixos.org/packages
  environment.systemPackages =
    let
      kp = pkgs.stdenv.mkDerivation {
        name = "hello.ke";
        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeself
        ];
        buildInputs = [
          pkgs.pkgsCross.riscv64.stdenv.cc.cc.lib
        ];
        dontUnpack = true;
        dontInstall = true;
        buildPhase = ''
          mkdir -p $out/bin
          cp -v ${./hello.ke} hello.ke
          ./hello.ke --noexec --target hello
          rm hello.ke
          autoPatchelf hello/*
          makeself hello $out/bin/hello.ke "Custom keystone" ./hello-runner hello eyrie-rt loader.bin
        '';
      };
    in
    with pkgs;
    [
      # makeself deps
      gawk
      gnutar
      gzip

      # optional
      file
      systemd
      # gdb
      glibc
      hello
      microfetch
      strace
      vim
      which

      kp
    ];

  # password is "sifive"
  users.users.root.initialHashedPassword = "$y$j9T$qYGfDRIz2NmouNl3h/L6F.$aTymFw.ljxMmR7DpUGoHEevdPL4pX9kFftAUngxTc98";
  system.stateVersion = config.system.nixos.release;
}
