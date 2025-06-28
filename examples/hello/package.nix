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
    internalStrace = true;
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
    ${../../hello.ke} --noexec --target $out/lib
    wrapProgram $out/bin/hello-runner \
      --add-flag $out/share/hello \
      --add-flag ${runtime.rt} \
      --add-flag $out/lib/loader.bin
  '';

  # dontStrip = true;
  # cmakeBuildType = "RelWithDebInfo";
  # makeFlags = [ "VERBOSE=1" ];
}
