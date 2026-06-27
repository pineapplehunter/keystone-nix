{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    keystone-src = {
      url = "github:keystone-enclave/keystone";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  nixConfig = {
    extra-substituters = [ "https://niks3.s.ihavenojob.work" ];
    extra-trusted-public-keys = [ "niks3-cache:RW+9UW/AgeDvEawJndPbzNVYQcDPjXA4J23srAi5+sE=" ];
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];

        flake.nixosModules = {
          rootfs = ./rootfs-module.nix;
        };

        flake.nixosConfigurations.keystone = inputs.nixpkgs.lib.nixosSystem {
          system = null;
          modules = [
            config.flake.nixosModules.rootfs
            { nixpkgs.overlays = [ config.flake.overlays.default ]; }
            ./configuration.nix
          ];
        };

        flake.overlays.default = final: prev: {
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
            hello-ke = final.callPackage ./examples/hello/package.nix { };
            src = inputs.keystone-src;
          };
          nix-ld = prev.nix-ld.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./nix-ld-riscv.patch ];
            postInstall = (old.postInstall or "") + ''
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

        perSystem =
          {
            system,
            pkgs,
            self',
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ config.flake.overlays.default ];
            };
            packages =
              let
                osConfig = config.flake.nixosConfigurations.keystone.extendModules {
                  modules = [
                    {
                      nixpkgs.localSystem.system = pkgs.stdenv.buildPlatform.system;
                      nixpkgs.crossSystem.system = "riscv64-linux";
                    }
                  ];
                };
              in
              {
                default = self'.packages.qemu-run;
                inherit (pkgs.pkgsCross.riscv64.keystone)
                  driver
                  sm
                  sdk
                  runtime
                  hello-ke
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
                    inherit (pkgs.pkgsCross.riscv64-embedded.keystone) bootrom;
                    inherit (pkgs.pkgsCross.riscv64.keystone) sm;
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
                      -smp 4 \
                      -machine virt,rom=${bootrom}/bootrom.bin \
                      -bios ${sm}/platform/generic/firmware/fw_jump.bin \
                      -kernel ${systemPkg}/kernel \
                      -drive file=$TMP,format=raw \
                      -netdev user,id=net0,net=192.168.100.1/24,dhcpstart=192.168.100.128,hostfwd=tcp::10022-:22 \
                      -device virtio-net-device,netdev=net0 \
                      -device virtio-rng-pci \
                      -nographic \
                      -append "console=ttyS0 ro root=/dev/vda init=${systemPkg}/init cma=1G" \
                      "$@"
                    cleanup
                  '';
              };

            devShells.default = pkgs.mkShellNoCC {
              packages = [
                (pkgs.wrapBintoolsWith { bintools = pkgs.binutils-unwrapped-all-targets; })
              ];
            };

            legacyPackages = pkgs;
          };
      }
    );
}
