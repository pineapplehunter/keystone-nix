{
  keystone,
  stdenv,
  cmake,
  lib,
  which,
}:
stdenv.mkDerivation {
  pname = "keystone-sdk";
  version = "0";
  inherit (keystone) src;

  patches = [
    ./stdint.patch
  ];

  nativeBuildInputs = [
    cmake
    which
  ];

  postPatch = ''
    cd sdk
    substituteInPlace macros.cmake \
      --replace-fail 'riscv''${bits}-buildroot-linux-gnu-' "${stdenv.cc.targetPrefix}" 
  '';

  cmakeFlags = [
    (lib.cmakeFeature "KEYSTONE_SDK_DIR" (placeholder "out"))
    (lib.cmakeFeature "KEYSTONE_BITS" "64")
    (lib.cmakeFeature "cross_compile" stdenv.cc.targetPrefix)
  ];

  hardeningDisable = [ "stackprotector" ];
}
