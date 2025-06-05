{
  stdenv,
  keystone,
}:

stdenv.mkDerivation {
  pname = "keystone-bootrom";
  version = "0-unstable";

  inherit (keystone) src;

  makeFlags = [
    "-C bootrom"
    "O=$(out)"
  ];

  preConfigure = ''
    mkdir $out
  '';

  dontInstall = true;
}
