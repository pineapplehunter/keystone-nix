{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-riscv64-qemu.nix"
  ];
  boot = {
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./keystone-driver/package.nix { })
    ];
    # uncomment next line to load keystone-driver by default
    # kernelModules = [ "keystone-driver" ];
  };

  # add packages here
  # https://search.nixos.org/packages
  environment.systemPackages = with pkgs; [
    file
    vim
  ];

  # password is "sifive"
  users.users.root.initialHashedPassword = "$y$j9T$qYGfDRIz2NmouNl3h/L6F.$aTymFw.ljxMmR7DpUGoHEevdPL4pX9kFftAUngxTc98";
  networking.firewall.enable = false;
  system.stateVersion = config.system.nixos.release;
}
