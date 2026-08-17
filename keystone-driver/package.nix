{
  stdenv,
  lib,
  kernel,
  keystone,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "keystone-driver";
  inherit (keystone) version;
  name = "${finalAttrs.pname}-${finalAttrs.version}-${kernel.version}";

  inherit (keystone) src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KERNELRELEASE=${kernel.modDirVersion}"
    "INSTALL_MOD_PATH=$(out)"
    "ARCH=riscv"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    "KEYSTONE_SDK_DIR=${keystone.sdk}"
    "M=$(PWD)"
  ];
  buildFlags = [ "modules" ];
  installTargets = "modules_install";

  preConfigure = ''
    cd linux-keystone-driver
  '';

  hardeningDisable = [ "pic" ];

  meta = {
    description = "An Open Framework for Architecting Trusted Execution Environments";
    homepage = "https://keystone-enclave.org";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-linux" ];
  };
})
