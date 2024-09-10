{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://keystone-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "keystone-nix.cachix.org-1:I0zDDsziHqpZDmrNp4mTJGj77AroVJj91IMFZVFEJt8="
    ];
  };

  outputs =
    {
      nixpkgs,
      self,
      treefmt-nix,
      flake-utils,
      systems,
    }:
    flake-utils.lib.eachSystem ((import systems) ++ [ "riscv64-linux" ]) (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        crossPkgs = pkgs.pkgsCross.riscv64;
        crossPkgsEmbedded = pkgs.pkgsCross.riscv64-embedded;
        inherit (nixpkgs) lib;

        osConfiguration = lib.nixosSystem {
          system = null;
          modules = [
            {
              nixpkgs.localSystem.system = system;
              nixpkgs.crossSystem.system = "riscv64-linux";
            }
            ./configuration.nix
          ];
        };
      in
      {
        packages = {
          default = self.packages.${system}.qemu-run;
          driver = crossPkgs.linuxPackages.callPackage ./keystone-driver/package.nix { };
          bootrom = crossPkgsEmbedded.callPackage ./keystone-bootrom/package.nix { };
          sm = crossPkgs.callPackage ./keystone-sm/package.nix { };
          sdImage = osConfiguration.config.system.build.sdImage;
          systemConfig = osConfiguration.config.system.build.toplevel;
          qemu-run =
            let
              systemPkg = osConfiguration.config.system.build.toplevel;
              imgPkg = osConfiguration.config.system.build.sdImage;
              romPkg = self.packages.${system}.bootrom;
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
              TMP=$(mktemp --suffix=.img)
              echo Extracting sd image file to $TMP
              zstd -f -d ${imgPkg}/sd-image/nixos*.img.zst -o $TMP
              chmod +w $TMP

              cleanup(){
                echo Removing $TMP
                rm -f $TMP
              }
              trap cleanup SIGINT

              ${qemu}/bin/qemu-system-riscv64 \
                -m 2G \
                -machine virt,rom=${romPkg}/bootrom.bin \
                -bios ${crossPkgs.opensbi}/share/opensbi/lp64/generic/firmware/fw_jump.bin \
                -kernel ${systemPkg}/kernel \
                -drive file=$TMP,format=raw \
                -nographic \
                -initrd ${systemPkg}/initrd \
                -append "init=${systemPkg}/init" \
                "$@"
              cleanup
            '';
        };

        formatter =
          (treefmt-nix.lib.evalModule pkgs {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          }).config.build.wrapper;
      }

    );
}
