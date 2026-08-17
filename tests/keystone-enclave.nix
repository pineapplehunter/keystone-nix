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
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ (nixpkgs + "/nixos/modules/profiles/minimal.nix") ];

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        extraModulePackages = [
          (config.boot.kernelPackages.callPackage ../keystone-driver/package.nix { })
        ];
        kernelParams = [ "cma=256M" ];
        loader.grub.enable = false;
      };

      environment.systemPackages = [ pkgs.keystone.hello-ke ];

      networking = {
        dhcpcd.enable = false;
        useDHCP = false;
      };

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
        vlans = [ ];
        qemu.options = [
          "-bios ${secureMonitor}/platform/generic/firmware/fw_jump.bin"
        ];
      };
    };

  testScript = ''
    from datetime import timedelta
    print(machine.succeed("uname -a"))
    machine.succeed("uname -r | grep -q '^${guestPkgs.linuxPackages_latest.kernel.version}'")
    machine.succeed("modprobe keystone-driver")
    machine.succeed("test -c /dev/keystone_enclave")
    output = machine.succeed("hello-runner", timeout=timedelta(minutes=2))
    print(output)
    assert "hello, world!" in output
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
