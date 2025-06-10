{
  keystone,
  stdenv,
  cmake,
  lib,
  plugins ? [ ],
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "keystone-runtime";
  version = "0";
  inherit (keystone) src;

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    (lib.cmakeFeature "KEYSTONE_SDK_DIR" "${keystone.sdk}")
  ] ++ map (p: lib.cmakeBool (lib.toUpper p) true) plugins;

  postPatch = ''
    cd runtime
    substituteInPlace sys/entry.S \
      --replace-fail sbadaddr stval
  '';

  # preInstall = "ls ..";
  installPhase = ''
    runHook preInstall

    cd ..
    install -Dt $out loader.bin
    install -Dt $out eyrie-rt
    install -Dt $out .options_log
    cp -r include $out

    runHook postInstall
  '';

  hardeningDisable = [ "stackprotector" ];

  passthru = {
    loader = "${finalAttrs.finalPackage}/loader.bin";
    rt = "${finalAttrs.finalPackage}/eyrie-rt";
  };
})
