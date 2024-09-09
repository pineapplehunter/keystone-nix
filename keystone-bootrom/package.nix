{
  stdenv,
  fetchFromGitHub,
  ncurses,
}:

stdenv.mkDerivation {
  pname = "keystone-bootrom";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "keystone-enclave";
    repo = "keystone";
    rev = "80ffb2f9d4e774965589ee7c67609b0af051dc8b";
    hash = "sha256-bAJrWuuZaDR9hU3Wc8ZZ/l4NecriDMpLlY7f7kd/B8s=";
  };

  nativeBuildInputs = [
    ncurses
  ];

  makeFlags = [
    "O=build"
  ];

  preConfigure = ''
    cd bootrom
    substituteInPlace bootloader.lds \
      --replace-fail "ALIGN(4)" "ALIGN(8)"
    mkdir build
  '';

  installPhase = ''
    mkdir $out
    cp build/* $out
  '';
}
