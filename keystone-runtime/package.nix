{
  keystone,
  stdenv,
  cmake,
  lib,
  plugins ? [ ],
  internalStrace ? false,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "keystone-runtime";
  version = "0";
  inherit (keystone) src;

  patches = [ ./req_pages_define.patch ];

  nativeBuildInputs = [ cmake ];

  # The raw loader relies on its unoptimized, position-independent layout.
  cmakeBuildType = "Debug";

  cmakeFlags = [
    (lib.cmakeFeature "KEYSTONE_SDK_DIR" "${keystone.sdk}")
    (lib.cmakeBool "INTERNAL_STRACE" internalStrace)
  ]
  ++ map (p: lib.cmakeBool (lib.toUpper p) true) plugins;

  postPatch = ''
    cd runtime
    substituteInPlace sys/entry.S \
      --replace-fail sbadaddr stval
    substituteInPlace loader-binary/loader.S \
      --replace-fail '  la sp, _estack' $'.option push\n.option norvc\n.option nopic\n.option norelax\n  la sp, _estack\n.option pop' \
      --replace-fail '  la a0, root_page_table_storage' $'.option push\n.option norvc\n.option nopic\n.option norelax\n  la a0, root_page_table_storage\n.option pop'
  '';

  installPhase = ''
    runHook preInstall

    cd ..
    install -Dt $out/share loader.bin
    install -Dt $out/share eyrie-rt
    install -Dt $out/share .options_log

    runHook postInstall
  '';

  stripDebugList = [ "share" ];

  hardeningDisable = [ "all" ];

  makeFlags = [ "VERBOSE=1" ];

  # Only .text is copied into loader.bin, so it cannot contain a GOT.
  env.NIX_CFLAGS_COMPILE = "-march=rv64g_zifencei_zicsr -mabi=lp64d -fno-pic -fno-pie";

  passthru = {
    loader = "${finalAttrs.finalPackage}/share/loader.bin";
    rt = "${finalAttrs.finalPackage}/share/eyrie-rt";
  };
})
