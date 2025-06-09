{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.keystone-src = {
    url = "github:keystone-enclave/keystone";
    flake = false;
  };

  nixConfig = {
    extra-substituters = [ "https://attic.s.ihavenojob.work/keystone-nix-cache" ];
    extra-trusted-public-keys = [
      "keystone-nix-cache:5b9qjOQSEMpslVDH7Si6ptmH0m//o48KbtxiI1rDb/s="
    ];
  };

  outputs =
    {
      nixpkgs,
      keystone-src,
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
          sdk = final.callPackage ./keystone-sdk/package.nix { };
          runtime = final.callPackage ./keystone-runtime/package.nix { };
          qemu =
            (final.qemu.override {
              hostCpuTargets = [ "riscv64-softmmu" ];
            }).overrideAttrs
              (old: {
                patches = [ ./qemu.patch ];
                postInstall = (old.postInstall or "") + "rm $out/bin/qemu-kvm";
              });
          src = keystone-src;
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
      nixosModules = {
        rootfs = ./rootfs-module.nix;
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
            self.nixosModules.rootfs
            ./configuration.nix
          ];
        }
      );
      packages = eachSystem (
        pkgs:
        let
          system = pkgs.system;
          osConfig = self.osConfig.${system};
        in
        {
          default = self.packages.${system}.qemu-run;
          inherit (pkgs.pkgsCross.riscv64.keystone)
            driver
            sm
            sdk
            runtime
            ;
          runtime-with-plugin = pkgs.pkgsCross.riscv64.keystone.runtime.override {
            plugins = [
              "io_syscall"
              "linux_syscall"
              "env_setup"
            ];
          };
          inherit (pkgs.pkgsCross.riscv64-embedded.keystone) bootrom;
          systemConfig = osConfig.config.system.build.toplevel;
          qemu-run =
            let
              systemPkg = osConfig.config.system.build.toplevel;
              imgPkg = osConfig.config.system.build.rootfsImage;
              romPkg = self.packages.${system}.bootrom;
            in
            pkgs.writeShellScriptBin "qemu-run" ''
              TMP=$(mktemp --suffix=.img)
              KEYSTONE_PORT=9821
              echo Extracting sd image file to $TMP
              zstd -f -d ${imgPkg} -o $TMP
              chmod +w $TMP

              cleanup(){
                echo Removing $TMP
                rm -f $TMP
              }
              trap cleanup SIGINT

              ${pkgs.keystone.qemu}/bin/qemu-system-riscv64 \
                -m 4G \
                -machine virt,rom=${romPkg}/bootrom.bin \
                -bios /home/shogo/tmp/keystone/build-generic64/buildroot.build/images/fw_jump.bin \
                -kernel ${systemPkg}/kernel \
                -drive file=$TMP,format=raw \
                -netdev user,id=net0,net=192.168.100.1/24,dhcpstart=192.168.100.128,hostfwd=tcp::10022-:22 \
                -device virtio-net-device,netdev=net0 \
                -device virtio-rng-pci \
                -nographic \
                -append "console=ttyS0 ro root=/dev/vda init=${systemPkg}/init" \
                "$@"
              cleanup
            '';
        }
      );

      checks = eachSystem (pkgs: self.packages.${pkgs.system});
      legacyPackages = eachSystem lib.id;
    };
}
