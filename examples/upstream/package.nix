{
  stdenv,
  cmake,
  lib,
  makeBinaryWrapper,
  keystone,
}:
let
  runtime = keystone.runtime;
  firmware = "${keystone.sm}/platform/generic/firmware/fw_jump.bin";
in
stdenv.mkDerivation {
  pname = "keystone-samples";
  inherit (keystone) src version;

  setSourceRoot = ''
    sourceRoot=$(echo */examples)
  '';

  postPatch = ''
    cp ${./CMakeLists.txt} CMakeLists.txt
    substituteInPlace attestation/host/host.cpp \
      --replace-fail 'Enclave said value: %u' 'Enclave said value: %lu'
  '';

  nativeBuildInputs = [
    cmake
    makeBinaryWrapper
  ];
  buildInputs = [ keystone.sdk ];

  env.KEYSTONE_SDK_DIR = "${keystone.sdk}";

  hardeningDisable = [ "stackprotector" ];

  postInstall = ''
    makeWrapper $out/libexec/hello-native-runner $out/bin/hello-native-runner \
      --add-flag $out/share/keystone/hello-native \
      --add-flag ${runtime.rt} \
      --add-flag ${runtime.loader}
    makeWrapper $out/libexec/attestor-runner $out/bin/attestor-runner \
      --add-flag $out/share/keystone/attestor \
      --add-flag ${runtime.rt} \
      --add-flag ${runtime.loader} \
      --add-flags "--freemem-size 1024" \
      --add-flags "--sm-bin ${firmware}"
  '';

  passthru = { inherit firmware runtime; };

  meta = {
    description = "Keystone native hello-world and attestation samples";
    homepage = "https://keystone-enclave.org";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-linux" ];
  };
}
