{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:
let
  KERNEL_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in

stdenv.mkDerivation (finalAttrs: {
  name = "keystone-driver-${finalAttrs.version}-${kernel.version}";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "keystone-enclave";
    repo = "keystone";
    rev = "80ffb2f9d4e774965589ee7c67609b0af051dc8b";
    hash = "sha256-bAJrWuuZaDR9hU3Wc8ZZ/l4NecriDMpLlY7f7kd/B8s=";
  };

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
