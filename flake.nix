{
  description = "Nix packages and VM tests for the Keystone RISC-V enclave stack";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    keystone-src = {
      url = "github:keystone-enclave/keystone";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  nixConfig = {
    extra-substituters = [ "https://niks3.gweb.ihavenojob.work" ];
    extra-trusted-public-keys = [ "niks3-cache:RW+9UW/AgeDvEawJndPbzNVYQcDPjXA4J23srAi5+sE=" ];
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        # This is the host platform continuously exercised by CI. All Keystone
        # guest artifacts are cross-compiled for RISC-V.
        systems = [ "x86_64-linux" ];

        flake.nixosModules.rootfs = ./rootfs-module.nix;

        flake.nixosConfigurations.keystone = inputs.nixpkgs.lib.nixosSystem {
          system = null;
          modules = [
            config.flake.nixosModules.rootfs
            { nixpkgs.overlays = [ config.flake.overlays.default ]; }
            ./configuration.nix
          ];
        };

        flake.overlays.default = final: prev: {
          keystone =
            let
              # Keystone's OpenSBI integration targets the pre-domain API from
              # 1.1. Keep this private to Keystone instead of replacing the
              # nixpkgs OpenSBI package for every overlay consumer.
              sourceDate = inputs.keystone-src.lastModifiedDate;
              opensbi = prev.opensbi.overrideAttrs rec {
                version = "1.1";
                src = final.fetchFromGitHub {
                  owner = "riscv-software-src";
                  repo = "opensbi";
                  tag = "v${version}";
                  hash = "sha256-k6f4/lWY/f7qqk0AFY4tdEi4cDilSv/jngaJYhKFlnY=";
                };
              };
            in
            rec {
              version = "0-unstable-${builtins.substring 0 4 sourceDate}-${builtins.substring 4 2 sourceDate}-${
                builtins.substring 6 2 sourceDate
              }";
              src = inputs.keystone-src;
              inherit opensbi;

              driverFor = kernelPackages: kernelPackages.callPackage ./keystone-driver/package.nix { };
              driver = driverFor final.linuxPackages;
              bootrom = final.callPackage ./keystone-bootrom/package.nix { };
              sm = final.callPackage ./keystone-sm/package.nix { inherit opensbi; };
              kernelPackages = final.callPackage ./keystone-kernel/package.nix { };
              sdk = final.callPackage ./keystone-sdk/package.nix { };
              runtime = final.callPackage ./keystone-runtime/package.nix { };
              qemu =
                (final.qemu.override {
                  hostCpuTargets = [ "riscv64-softmmu" ];
                }).overrideAttrs
                  (old: {
                    patches = (old.patches or [ ]) ++ [ ./qemu.patch ];
                    postInstall = (old.postInstall or "") + "rm -f $out/bin/qemu-kvm";
                  });
              hello-ke = final.callPackage ./examples/hello/package.nix { };
              samples = final.callPackage ./examples/upstream/package.nix { };
            };
        };

        perSystem =
          {
            system,
            pkgs,
            self',
            ...
          }:
          let
            keystoneTest = import ./tests/keystone-enclave.nix {
              nixpkgs = inputs.nixpkgs.outPath;
              localSystem = system;
              overlay = config.flake.overlays.default;
            };
          in
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ config.flake.overlays.default ];
            };

            checks = {
              keystone-enclave = keystoneTest;

              qemu-rom-property = pkgs.runCommand "qemu-rom-property-check" { } ''
                ${pkgs.keystone.qemu}/bin/qemu-system-riscv64 \
                  -machine virt,help | grep -F 'rom=<string>'

                touch "$TMPDIR/first-rom"
                status=0
                timeout 1 ${pkgs.keystone.qemu}/bin/qemu-system-riscv64 \
                  -machine virt,rom="$TMPDIR/first-rom" \
                  -display none -S >valid-rom.log 2>&1 || status=$?
                test "$status" -eq 124

                if ${pkgs.keystone.qemu}/bin/qemu-system-riscv64 \
                  -machine virt,rom="$TMPDIR/does-not-exist" \
                  -display none -S >qemu.log 2>&1; then
                  echo "QEMU unexpectedly accepted a missing ROM" >&2
                  exit 1
                fi
                grep -F 'could not load ROM image' qemu.log
                touch "$out"
              '';

              package-set = pkgs.linkFarm "keystone-package-check" (
                map
                  (name: {
                    inherit name;
                    path = self'.packages.${name};
                  })
                  [
                    "bootrom"
                    "driver"
                    "hello-ke"
                    "qemu"
                    "qemu-run"
                    "runtime"
                    "runtime-with-plugin"
                    "samples"
                    "sdk"
                    "sm"
                    "systemConfig"
                  ]
              );
            };

            formatter = pkgs.nixfmt-tree;

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
                  samples
                  ;
                inherit (pkgs.pkgsCross.riscv64-embedded.keystone) bootrom;

                qemu = pkgs.keystone.qemu;
                runtime-with-plugin = pkgs.pkgsCross.riscv64.keystone.runtime.override {
                  plugins = [
                    "io_syscall"
                    "linux_syscall"
                    "env_setup"
                  ];
                };
                systemConfig = osConfig.config.system.build.toplevel;

                qemu-run = keystoneTest.driverInteractive;

                # CI tools are explicit outputs rather than accidental exports
                # through the entire nixpkgs legacyPackages set.
                inherit (pkgs) niks3 omnix;
              };

            apps.default = {
              type = "app";
              program = "${self'.packages.qemu-run}/bin/nixos-test-driver";
              meta.description = "Launch an interactive Keystone NixOS test VM";
            };

            devShells.default = pkgs.mkShellNoCC {
              packages = [
                (pkgs.wrapBintoolsWith { bintools = pkgs.binutils-unwrapped-all-targets; })
                pkgs.shellcheck
              ];
            };
          };
      }
    );
}
