{
  opensbi_1_1,
  fetchFromGitHub,
  runCommand,
}:
let
  keystone-src = fetchFromGitHub {
    owner = "keystone-enclave";
    repo = "keystone";
    rev = "80ffb2f9d4e774965589ee7c67609b0af051dc8b";
    hash = "sha256-bAJrWuuZaDR9hU3Wc8ZZ/l4NecriDMpLlY7f7kd/B8s=";
  };
  keystone-sm-patched = runCommand "keystone-sm-patched" { } ''
    cp -r ${keystone-src}/sm $out
    substituteInPlace $out/src/thread.{h,c} \
      --replace-warn sbadaddr stval
  '';
in
opensbi_1_1.overrideAttrs (old: {
  makeFlags = (old.makeFlags or [ ]) ++ [
    "PLATFORM_DIR=${keystone-sm-patched}/plat/"
    "KEYSTONE_SM=${keystone-sm-patched}/"
    "KEYSTONE_SDK_DIR=${keystone-src}/sdk"
  ];
  postPatch = (old.postPatch or "") + '''';
})
