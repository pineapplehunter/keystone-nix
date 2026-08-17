{
  stdenv,
  cmake,
  lib,
  glibc,
  makeBinaryWrapper,
  keystone,
}:
let
  runtime = keystone.runtime.override {
    plugins = [
      "io_syscall"
      "linux_syscall"
      "env_setup"
    ];
  };
in
stdenv.mkDerivation {
  pname = "hello-ke";
  inherit (keystone) version;

  src = ./.;
  nativeBuildInputs = [
    cmake
    makeBinaryWrapper
  ];
  buildInputs = [
    glibc
    glibc.static
    keystone.sdk
  ];
  postInstall = ''
    mkdir -p $out/libexec
    mv $out/bin/hello-runner $out/libexec/hello-runner
    makeWrapper $out/libexec/hello-runner $out/bin/hello-runner \
      --add-flag $out/share/hello \
      --add-flag ${runtime.rt} \
      --add-flag ${runtime.loader}
  '';

  passthru = { inherit runtime; };

  meta = {
    description = "Keystone hello-world enclave and host runner";
    homepage = "https://keystone-enclave.org";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ pineapplehunter ];
    mainProgram = "hello-runner";
    platforms = [ "riscv64-linux" ];
  };
}
