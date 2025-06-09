{
  opensbi_1_1,
  stdenv,
  python3,
  keystone,
}:
stdenv.mkDerivation {
  pname = "opensbi-kestone-sm";
  inherit (opensbi_1_1) version;
  srcs = [
    (opensbi_1_1.src.overrideAttrs { name = "opensbi"; })
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
  ];
  postPatch = ''
    patchShebangs ./opensbi/scripts
    substituteInPlace ./keystone/sm/src/thread.{h,c} \
      --replace-warn sbadaddr stval
    (
      cd opensbi
      patch --verbose -p1 < ${./opensbi-change-basename.patch}
      patch -p1 < ${./opensbi-firmware-secure-boot.patch}
    )
    makeFlagsArray+=(
      "KEYSTONE_SM=$(pwd)/keystone/sm"
      "PLATFORM_DIR=$(pwd)/keystone/sm/plat/"
      "-C"
      "$(pwd)/opensbi"
    )
  '';
}
