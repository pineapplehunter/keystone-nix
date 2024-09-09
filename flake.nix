{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, self }:
    let
      pkgsForSystem = system: import nixpkgs { inherit system; };
      inherit (nixpkgs) lib;
    in
    {

      packages.x86_64-linux.default =
        (pkgsForSystem "x86_64-linux").linuxPackages.callPackage ./package.nix
          { };
      packages.riscv64-linux.default =
        (pkgsForSystem "riscv64-linux").linuxPackages.callPackage ./package.nix
          { };
      packages.rvcross = rec {
        default = bootrom;
        driver =
          (pkgsForSystem "x86_64-linux").pkgsCross.riscv64.linuxPackages.callPackage
            ./keystone-driver/package.nix
            { };
        bootrom =
          (pkgsForSystem "x86_64-linux").pkgsCross.riscv64-embedded.callPackage ./keystone-bootrom/package.nix
            { };
        sm =
          (pkgsForSystem "x86_64-linux").pkgsCross.riscv64.callPackage ./keystone-sm/package.nix
            { };
      };

      packages.x86_64-linux.qemu-run =
        let
          systemPkg = self.nixosConfiguration.sample.config.system.build.toplevel;
          imgPkg = self.nixosConfiguration.sample.config.system.build.sdImage;
          romPkg = self.packages.rvcross.bootrom;
          pkgs = (pkgsForSystem "x86_64-linux");
          crossPkgs = pkgs.pkgsCross.riscv64;
          qemu =
            (pkgs.qemu.override {
              hostCpuTargets = [ "riscv64-softmmu" ];
            }).overrideAttrs
              {
                patches = [
                  ./qemu.patch
                ];
              };
        in
        pkgs.writeShellScriptBin "qemu-run" ''
          zstd -f -d ${imgPkg}/sd-image/nixos*.img.zst -o /tmp/riscv-nixos.img
          chmod +w /tmp/riscv-nixos.img
          ${qemu}/bin/qemu-system-riscv64 \
            -m 2G \
            -machine virt,rom=${romPkg}/bootrom.bin \
            -bios ${crossPkgs.opensbi}/share/opensbi/lp64/generic/firmware/fw_jump.bin \
            -kernel ${systemPkg}/kernel \
            -drive file=/tmp/riscv-nixos.img,format=raw \
            -nographic \
            -initrd ${systemPkg}/initrd \
            -append "init=${systemPkg}/init" \
            "$@"
        '';
      # -bios ${./fw_jump.elf} \

      nixosConfiguration.sample = lib.nixosSystem {
        system = null;
        modules = [
          {
            nixpkgs.localSystem.system = "x86_64-linux";
            nixpkgs.crossSystem.system = "riscv64-linux";
          }
          (nixpkgs + /nixos/modules/installer/sd-card/sd-image-riscv64-qemu.nix)
          (
            { config, pkgs, ... }:
            {
              boot = {
                extraModulePackages = [
                  (config.boot.kernelPackages.callPackage ./keystone-driver/package.nix { })
                ];
                # kernelModules = [ "keystone-driver" ];
              };
              documentation.enable = false;
              system.stateVersion = config.system.nixos.release;
              environment.systemPackages = with pkgs; [
                # fd
                # htop
                # fastfetch
                file
              ];
              users.users.root.initialHashedPassword = "$y$j9T$OyOB1AEyqQTmJw.Ahh2hS0$DD4g89KLJFsLi4PPbHg4kpeNxZ2RHJSA8Hp6.tmta24";
              networking.firewall.enable = false;
            }
          )
        ];
      };

    };
}
