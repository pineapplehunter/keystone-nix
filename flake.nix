{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  nixConfig = {
    extra-substituters = [ "https://attic.s.ihavenojob.work/keystone-nix-cache" ];
    extra-trusted-public-keys = [
      "keystone-nix-cache:5b9qjOQSEMpslVDH7Si6ptmH0m//o48KbtxiI1rDb/s="
    ];
  };

  outputs =
    {
      nixpkgs,
      self,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            }
          )
        );
    in
    {
      overlays.default = final: prev: {
        keystone = {
          driver = final.linuxPackages.callPackage ./keystone-driver/package.nix { };
          bootrom = final.callPackage ./keystone-bootrom/package.nix { };
          sm = final.callPackage ./keystone-sm/package.nix { };
          kernelPackages = final.callPackage ./keystone-kernel/package.nix { };
          qemu = final.qemu.overrideAttrs {
            patches = [ ./qemu.patch ];
          };
        };
        nix-ld = prev.nix-ld.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./nix-ld-riscv.patch ];
          postInstall =
            (old.postInstall or "")
            + ''
              echo /lib/ld-linux-riscv64-lp64d.so.1 > $out/nix-support/ldpath
            '';
        });
        opensbi_1_1 = prev.opensbi.overrideAttrs rec {
          version = "1.1";
          src = final.fetchFromGitHub {
            owner = "riscv-software-src";
            repo = "opensbi";
            tag = "v${version}";
            hash = "sha256-k6f4/lWY/f7qqk0AFY4tdEi4cDilSv/jngaJYhKFlnY=";
          };
        };
      };
      osConfig = eachSystem (
        pkgs:
        lib.nixosSystem {
          system = null;
          modules = [
            {
              nixpkgs.localSystem.system = pkgs.buildPlatform.system;
              nixpkgs.crossSystem.system = "riscv64-linux";
              nixpkgs.overlays = [ self.overlays.default ];
            }
            ./configuration.nix
          ];
        }
      );
      packages = eachSystem (
        pkgs:
        let
          system = pkgs.system;
          crossPkgs = pkgs.pkgsCross.riscv64;
          osConfig = self.osConfig.${system};
        in
        {
          default = self.packages.${system}.qemu-run;
          inherit (pkgs.pkgsCross.riscv64.keystone) driver sm;
          inherit (pkgs.pkgsCross.riscv64-embedded.keystone) bootrom;
          systemConfig = osConfig.config.system.build.toplevel;
          qemu-run =
            let
              systemPkg = osConfig.config.system.build.toplevel;
              imgPkg = osConfig.config.system.build.sdImage;
              romPkg = self.packages.${system}.bootrom;
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

              ${pkgs.keystone.qemu}/bin/qemu-system-riscv64 \
                -m 2G \
                -machine virt,rom=${romPkg}/bootrom.bin \
                -bios ${crossPkgs.keystone.sm}/share/opensbi/lp64/generic/firmware/fw_jump.bin \
                -kernel ${systemPkg}/kernel \
                -drive file=$TMP,format=raw \
                -nographic \
                -initrd ${systemPkg}/initrd \
                -append "init=${systemPkg}/init" \
                "$@"
              cleanup
            '';
        }
      );

      checks = eachSystem (pkgs: self.packages.${pkgs.system});
      legacyPackages = eachSystem lib.id;
    };
}
