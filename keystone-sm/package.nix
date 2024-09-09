{
  opensbi,
  fetchFromGitHub,
}:
let
  keystone-src = fetchFromGitHub {
    owner = "keystone-enclave";
    repo = "keystone";
    rev = "80ffb2f9d4e774965589ee7c67609b0af051dc8b";
    hash = "sha256-bAJrWuuZaDR9hU3Wc8ZZ/l4NecriDMpLlY7f7kd/B8s=";
  };
in
opensbi.overrideAttrs {
  makeFlags = [
    "PLATFORM_DIR=${keystone-src}/sm/plat/generic"
  ];
}
