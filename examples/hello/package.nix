{
  stdenv,
  cmake,
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
  name = "hello.ke";
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
    wrapProgram $out/bin/hello-runner \
      --add-flag $out/share/hello \
      --add-flag ${runtime.rt} \
      --add-flag ${runtime.loader}
  '';

  # dontStrip = true;
  # cmakeBuildType = "RelWithDebInfo";
  # makeFlags = [ "VERBOSE=1" ];
}
