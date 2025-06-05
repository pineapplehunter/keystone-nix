{
  opensbi_1_1,
  runCommand,
  stdenv,
  python3,
  keystone,
}:
let
  keystone-sm-patched = runCommand "keystone" { } ''
    cp -r ${keystone.src} $out
    substituteInPlace $out/sm/src/thread.{h,c} \
      --replace-warn sbadaddr stval
  '';
in
stdenv.mkDerivation {
  pname = "opensbi-kestone-sm";
  inherit (opensbi_1_1) version;
  srcs = [
    (opensbi_1_1.src.overrideAttrs { name = "opensbi"; })
    keystone-sm-patched
  ];
  nativeBuildInputs = [ python3 ];
  enableParallelBuilding = true;
  sourceRoot = ".";
  makeFlags = [
    "O=$(out)"
  ];
  postPatch = ''
    patchShebangs ./opensbi/scripts
      (cd opensbi; patch --verbose -p1 < ${./opensbi-change-basename.patch}; patch --verbose -p1 < ${./opensbi-firmware-secure-boot.patch})
      makeFlagsArray+=(
        "-C"
        "$(pwd)/opensbi"  
        "PLATFORM_DIR=$(pwd)/keystone/sm/plat/generic"
        "KEYSTONE_SM=$(pwd)/keystone/sm"
        "KEYSTONE_SDK_DIR=$(pwd)/keystone/sdk"
      )
  '';

}
# opensbi_1_1.overrideAttrs (old: {
#   postPatch = (old.postPatch or "") + '''';
# })
