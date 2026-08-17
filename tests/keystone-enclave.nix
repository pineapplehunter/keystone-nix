{
  pkgsCross,
  testers,
  lib,
  keystone,
  stdenv,
}:
let
  bootrom = pkgsCross.riscv64-embedded.keystone.bootrom;
  secureMonitor = pkgsCross.riscv64.keystone.sm;
in
testers.nixosTest {
  name = "keystone-enclave";
  globalTimeout = 600;

  nodes.machine =
    { config, pkgs, ... }:
    {
      nixpkgs.pkgs = pkgsCross.riscv64;

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        extraModulePackages = [ (pkgs.keystone.driverFor config.boot.kernelPackages) ];
        kernelParams = [ "cma=256M" ];
        loader.grub.enable = false;
      };

      environment.systemPackages = [
        pkgs.keystone.hello-ke
        pkgs.keystone.samples
      ];

      virtualisation = {
        cores = 4;
        memorySize = 4096;
        qemu = {
          options = [
            "-machine rom=${bootrom}/bootrom.bin"
            "-bios ${secureMonitor}/platform/generic/firmware/fw_jump.bin"
          ];
          package = lib.mkForce keystone.qemu;
        };
      };
    };

  interactive.qemu.package = lib.mkForce keystone.qemu;

  testScript =
    let
      hello = pkgsCross.riscv64.keystone.hello-ke;
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

      output = machine.succeed("hello-runner", timeout=timedelta(minutes=1))
      print(output)
      assert "hello, world!" in output

      output = machine.succeed("hello-native-runner", timeout=timedelta(minutes=1))
      print(output)

      output = machine.succeed("attestor-runner", timeout=timedelta(minutes=1))
      print(output)
    '';
}
