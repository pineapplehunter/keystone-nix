{
  stdenv,
  lib,
  keystone,
}:

stdenv.mkDerivation {
  pname = "keystone-bootrom";
  inherit (keystone) version;

  inherit (keystone) src;

  makeFlags = [
    "-C bootrom"
    "O=$(out)"
  ];

  preConfigure = ''
    mkdir $out
  '';

  dontInstall = true;

  meta = {
    description = "Keystone test boot ROM for RISC-V";
    homepage = "https://keystone-enclave.org";
    license = [
      lib.licenses.bsd3
      lib.licenses.zlib
    ];
    maintainers = with lib.maintainers; [ pineapplehunter ];
    platforms = [ "riscv64-none" ];
  };
}
