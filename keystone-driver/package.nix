{
  stdenv,
  lib,
  kernel,
  keystone,
}:
stdenv.mkDerivation (finalAttrs: {
  name = "keystone-driver-${finalAttrs.version}-${kernel.version}";
  version = "0-unstable";

  inherit (keystone) src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KERNELRELEASE=${kernel.modDirVersion}"
    "INSTALL_MOD_PATH=$(out)"
    "ARCH=riscv"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];
  buildFlags = [ "modules" ];
  installTargets = "modules_install";

  preConfigure = ''
    cd linux-keystone-driver
    makeFlagsArray+=(M=$(pwd) KEYSTONE_SDK_DIR=$(pwd)/../sdk)
  '';

  hardeningDisable = [
    "pic"
    "format"
  ];

  meta = {
    description = "An Open Framework for Architecting Trusted Execution Environments";
    homepage = "https://keystone-enclave.org";
    # license = with lib.licenses ;[gpl2 bsd2]; #
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-linux" ];
  };
})
