{
  opensbi,
  stdenv,
  lib,
  python3,
  keystone,
}:
stdenv.mkDerivation {
  pname = "opensbi-keystone-sm";
  inherit (keystone) version;
  srcs = [
    (opensbi.src.overrideAttrs { name = "opensbi"; })
    (builtins.path {
      name = "keystone";
      path = keystone.src;
    })
  ];
  nativeBuildInputs = [ python3 ];
  enableParallelBuilding = true;
  sourceRoot = ".";
  makeFlags = [
    "O=$(out)"
    "KEYSTONE_PLATFORM=generic"
    "KEYSTONE_SDK_DIR=${keystone.sdk}"
    "PLATFORM=generic"
    "PLATFORM_RISCV_ABI=lp64d"
    "PLATFORM_RISCV_ISA=rv64imafd_zifencei_zicsr"
    "PLATFORM_RISCV_TOOLCHAIN_DEFAULT=1"
    "FW_PATH=$(out)/platform/generic/firmware"
    # OpenSBI 1.1 otherwise copies the FDT to 0x82200000, inside today's
    # >32 MiB Linux Image. Keep it above the kernel and below QEMU's initrd.
    "FW_JUMP_FDT_ADDR=0x84000000"
  ];
  postPatch = ''
    patchShebangs ./opensbi/scripts
    substituteInPlace ./opensbi/Makefile \
      --replace-fail $'CFLAGS\t\t=\t-g -Wall' $'CFLAGS\t\t=\t-std=gnu11 -g -Wall'
    substituteInPlace ./keystone/sm/src/thread.{h,c} \
      --replace-warn sbadaddr stval
    (
      cd opensbi
      patch -p1 < ${./opensbi-change-basename.patch}
      patch -p1 < ${./opensbi-firmware-secure-boot.patch}
    )
    makeFlagsArray+=(
      "KEYSTONE_SM=$(pwd)/keystone/sm"
      "PLATFORM_DIR=$(pwd)/keystone/sm/plat/"
      "-C"
      "$(pwd)/opensbi"
    )
  '';

  meta = {
    description = "OpenSBI 1.1 firmware with the Keystone security monitor";
    homepage = "https://keystone-enclave.org";
    license = with lib.licenses; [
      bsd2
      bsd3
      mit
      zlib
    ];
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-linux" ];
  };
}
