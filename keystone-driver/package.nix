{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:
let
  KERNEL_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in

stdenv.mkDerivation rec {
  name = "keystone-driver-${version}-${kernel.version}";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "keystone-enclave";
    repo = "keystone";
    rev = "80ffb2f9d4e774965589ee7c67609b0af051dc8b";
    hash = "sha256-bAJrWuuZaDR9hU3Wc8ZZ/l4NecriDMpLlY7f7kd/B8s=";
  };

  preConfigure = ''
    export KEYSTONE_SDK_DIR=$(pwd)/sdk
    cd linux-keystone-driver
  '';

  buildPhase = ''
    runHook preBuild
    make -C ${KERNEL_DIR} ARCH=riscv M=$(pwd) $makeFlags KEYSTONE_SDK_DIR=$KEYSTONE_SDK_DIR modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C ${KERNEL_DIR} ARCH=riscv M=$(pwd) $makeFlags KEYSTONE_SDK_DIR=$KEYSTONE_SDK_DIR modules_install
    runHook postInstall 
  '';

  hardeningDisable = [
    "pic"
    "format"
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    "ARCH=riscv"
  ];

  meta = {
    description = "An Open Framework for Architecting Trusted Execution Environments";
    homepage = "https://keystone-enclave.org";
    # license = with lib.licenses ;[gpl2 bsd2]; #  
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-linux" ];
  };
}
