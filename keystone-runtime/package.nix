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

  patches = [
    ./req_pages_define.patch
    ./norelax.patch
  ];

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    (lib.cmakeFeature "KEYSTONE_SDK_DIR" "${keystone.sdk}")
    (lib.cmakeBool "INTERNAL_STRACE" internalStrace)
  ]
  ++ map (p: lib.cmakeBool (lib.toUpper p) true) plugins;

  postPatch = ''
    cd runtime
    substituteInPlace sys/entry.S \
      --replace-fail sbadaddr stval
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

  env.NIX_CFLAGS_COMPILE = "-march=rv64g_zifencei_zicsr -mabi=lp64d";

  passthru = {
    loader = "${finalAttrs.finalPackage}/share/loader.bin";
    rt = "${finalAttrs.finalPackage}/share/eyrie-rt";
  };
})
