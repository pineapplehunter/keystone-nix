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
    substituteInPlace src/verifier/json11.cpp \
      --replace-fail '#include <cassert>' $'#include <cassert>\n#include <cstdint>'
  '';

  cmakeFlags = [
    (lib.cmakeFeature "KEYSTONE_SDK_DIR" (placeholder "out"))
    (lib.cmakeFeature "KEYSTONE_BITS" "64")
  ];

  hardeningDisable = [ "stackprotector" ];
}
