{
  localSystem,
  nixpkgs,
  overlay,
}:
let
  hostPkgs = import nixpkgs {
    inherit localSystem;
    overlays = [ overlay ];
  };

  guestPkgs = import nixpkgs {
    inherit localSystem;
    crossSystem = "riscv64-linux";
    overlays = [ overlay ];
  };

  secureMonitor = hostPkgs.pkgsCross.riscv64.keystone.sm;

  nixos = import (nixpkgs + "/nixos/lib") {
    inherit (hostPkgs) lib;
  };
in
(nixos.runTest {
  name = "keystone-enclave";
  globalTimeout = 300;

  # QEMU and the Python test driver run on the host.
  inherit hostPkgs;
  qemu.package = hostPkgs.keystone.qemu;

  # The kernel and userspace are cross-compiled for the RISC-V guest.
  node.pkgs = guestPkgs;

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [ (nixpkgs + "/nixos/modules/profiles/minimal.nix") ];

      boot = {
        extraModulePackages = [ pkgs.keystone.driver ];
        kernelModules = [ "keystone-driver" ];
        kernelParams = [ "cma=1G" ];
        loader.grub.enable = false;
      };

      environment.systemPackages = [ pkgs.keystone.hello-ke ];

      # Avoid unrelated cross-builds in this test.
      system.disableInstallerTools = true;
      systemd.package = pkgs.systemd.override {
        withImportd = false;
        withSysupdate = false;
      };
      security.wrappers = lib.mkForce { };

      virtualisation = {
        cores = 4;
        memorySize = 4096;
        qemu.options = [
          "-bios ${secureMonitor}/platform/generic/firmware/fw_jump.bin"
        ];
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target", timeout=300)
    machine.succeed("uname -m | grep -qx riscv64")
    machine.succeed("test -c /dev/keystone_enclave")
    machine.succeed(
        "systemd-run --unit=hello-enclave --collect taskset -c 0 $(command -v hello-runner)"
    )
    machine.wait_until_succeeds(
        "systemctl is-active --quiet hello-enclave && systemctl kill hello-enclave",
        timeout=90,
    )
  '';

  passthru = {
    hostSystem = hostPkgs.stdenv.hostPlatform.system;
    guestSystem = guestPkgs.stdenv.hostPlatform.system;
    guestBuildSystem = guestPkgs.stdenv.buildPlatform.system;
    qemuSystem = hostPkgs.keystone.qemu.stdenv.hostPlatform.system;
  };
}).config.rawTestDerivation.overrideAttrs
  (_: {
    # qemu-system-riscv64 uses software emulation rather than KVM.
    requiredSystemFeatures = [ "nixos-test" ];
  })
