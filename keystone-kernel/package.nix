{
  linux_6_1,
  linuxPackages_custom,
}:

linuxPackages_custom {
  inherit (linux_6_1) src version;
  configfile = ./config;
  allowImportFromDerivation = false;
}
