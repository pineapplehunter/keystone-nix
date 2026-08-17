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
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  nixpkgs.system = "riscv64-linux";

  services.getty.autologinUser = "root";
  # environment.enableDebugInfo = true;
  system.switch.enable = false;
  nix.enable = false;
  boot.supportedFilesystems = lib.mkForce [ ];
  hardware.firmware = lib.mkForce [ ];
  networking.dhcpcd.wait = "if-carrier-up";
  networking.firewall.enable = false;

  boot = {
    # adds keystone-driver kernel module to the system
    extraModulePackages = [ (pkgs.keystone.driverFor config.boot.kernelPackages) ];
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
  environment.systemPackages = with pkgs; [
    # optional
    file
    hello
    microfetch
    strace
    systemd
    vim
    which

    keystone.hello-ke
  ];

  # password is "sifive"
  users.users.root.initialHashedPassword = "$y$j9T$qYGfDRIz2NmouNl3h/L6F.$aTymFw.ljxMmR7DpUGoHEevdPL4pX9kFftAUngxTc98";
  # Update only after reviewing the corresponding NixOS state migrations.
  system.stateVersion = "25.05";
}
