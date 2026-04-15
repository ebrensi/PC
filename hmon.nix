{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  ncurses,
}:
stdenv.mkDerivation rec {
  pname = "hmon";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "sdk445";
    repo = "hmon";
    rev = "v${version}";
    hash = "sha256-EJbubUeQMa5yxIG1xf16wOSnXBor1mUKwyzIN4+Wa5k=";
  };

  nativeBuildInputs = [cmake pkg-config];
  buildInputs = [ncurses];

  meta = {
    description = "Terminal system resource monitor with GPU, CPU, process, and service monitoring";
    homepage = "https://github.com/sdk445/hmon";
    license = lib.licenses.mit;
    mainProgram = "hmon";
    platforms = lib.platforms.linux;
  };
}
