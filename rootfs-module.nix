{
  lib,
  pkgs,
  modulesPath,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs;
in
{
  config.system.build.rootfsImage =
    (pkgs.callPackage "${modulesPath}/../lib/make-ext4-fs.nix" (
      {
        inherit (config.sdImage) storePaths;
        compressImage = config.sdImage.compressImage;
        populateImageCommands = config.sdImage.populateRootCommands;
        volumeLabel = "NIXOS_SD";
      }
      // optionalAttrs (config.sdImage.rootPartitionUUID != null) {
        uuid = config.sdImage.rootPartitionUUID;
      }
    )).overrideAttrs
      {
        preferLocalBuild = true;
      };
}
