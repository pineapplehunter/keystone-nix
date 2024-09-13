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
  boot.enableContainers = false;
  boot.initrd.luks.fido2Support.enable = false;
  boot.supportedFilesystems = lib.mkForce [ ];
  documentation.enable = false;
  environment.defaultPackages = lib.mkForce [ ];
  environment.noXlibs = true;
  hardware.firmware = lib.mkForce [ ];
  networking.firewall.enable = false;
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

  # enable nix flake support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot = {
    # adds keystone-driver kernel module to the system
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./keystone-driver/package.nix { })
    ];
    # uncomment next line to load keystone-driver by default
    # kernelModules = [ "keystone-driver" ];
  };

  # add packages here
  # https://search.nixos.org/packages
  environment.systemPackages = lib.mkForce (
    with pkgs;
    [
      # essentials
      systemd
      bashInteractive
      coreutils

      # optional
      microfetch
      which
      vim
      file
      nix
    ]
  );

  # password is "sifive"
  users.users.root.initialHashedPassword = "$y$j9T$qYGfDRIz2NmouNl3h/L6F.$aTymFw.ljxMmR7DpUGoHEevdPL4pX9kFftAUngxTc98";
  system.stateVersion = config.system.nixos.release;
}
