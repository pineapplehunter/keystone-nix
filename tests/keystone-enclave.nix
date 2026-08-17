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

  bootrom = hostPkgs.pkgsCross.riscv64-embedded.keystone.bootrom;
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
        extraModulePackages = [ (pkgs.keystone.driverFor config.boot.kernelPackages) ];
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
          "-machine rom=${bootrom}/bootrom.bin"
          "-bios ${secureMonitor}/platform/generic/firmware/fw_jump.bin"
        ];
      };
    };

  interactive.qemu.package = hostPkgs.lib.mkForce hostPkgs.keystone.qemu;

  testScript =
    let
      hello = guestPkgs.keystone.hello-ke;
      runtime = hello.runtime;
      runner = "${hello}/libexec/hello-runner";
    in
    ''
      from datetime import timedelta

      print(machine.succeed("uname -a"))

      output = machine.fail("${runner} 2>&1")
      assert "usage:" in output

      output = machine.fail("hello-runner 2>&1")
      assert "enclave initialization failed" in output

      machine.succeed("modprobe keystone-driver")
      machine.succeed("test -c /dev/keystone_enclave")

      output = machine.fail(
          "${runner} /does-not-exist ${runtime.rt} ${runtime.loader} 2>&1"
      )
      assert "cannot read enclave input" in output

      output = machine.fail(
          "${runner} ${hello}/share/hello-fail ${runtime.rt} ${runtime.loader} 2>&1",
          timeout=timedelta(minutes=2),
      )
      assert "enclave execution returned 42" in output

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
