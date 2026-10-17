{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  writeText,
  alsa-lib,
  expat,
  nspr,
  nss,
  systemd,
}:
# Carbonyl is a Chromium fork; building it from source is a full Chromium
# build, so this repackages the upstream prebuilt release.
let
  arch =
    {
      x86_64-linux = "amd64";
      aarch64-linux = "arm64";
    }.${
      stdenv.hostPlatform.system
    } or (throw "carbonyl: unsupported system ${stdenv.hostPlatform.system}");
  hashes = {
    amd64 = "sha256-z4oYXTu2olzDioKJpe2ePraG2pQQYoBBR+f8aUiDF7Q=";
    arm64 = "sha256-iV8I0a4xv+UJmqADwHdzMgueoccDVUH+J3wFaBx7rF0=";
  };
  # The bundled fontconfig is from 2023 and floods the terminal with parse
  # errors on newer /etc/fonts/conf.d files, so only pull in the NixOS font
  # list and default families, with a separate cache (older cache format).
  fontsConf = writeText "carbonyl-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/conf.d/00-nixos-cache.conf</include>
      <include ignore_missing="yes">/etc/fonts/conf.d/52-nixos-default-fonts.conf</include>
      <dir prefix="xdg">fonts</dir>
      <cachedir prefix="xdg">carbonyl-fontconfig</cachedir>
    </fontconfig>
  '';
in
  stdenv.mkDerivation rec {
    pname = "carbonyl";
    version = "0.0.3";

    src = fetchzip {
      url = "https://github.com/fathyb/carbonyl/releases/download/v${version}/carbonyl.linux-${arch}.zip";
      hash = hashes.${arch};
    };

    nativeBuildInputs = [autoPatchelfHook makeWrapper];
    buildInputs = [alsa-lib expat nspr nss stdenv.cc.cc.lib];
    # dlopen()ed at startup; a missing libudev is a fatal CHECK.
    runtimeDependencies = [(lib.getLib systemd)];

    installPhase = ''
      runHook preInstall
      # Chromium locates icudtl.dat, the V8 snapshot and its bundled .so files
      # next to /proc/self/exe, so keep the release layout intact.
      mkdir -p $out/lib/carbonyl $out/bin
      cp -r . $out/lib/carbonyl/
      makeWrapper $out/lib/carbonyl/carbonyl $out/bin/carbonyl \
        --set-default FONTCONFIG_FILE ${fontsConf}
      runHook postInstall
    '';

    meta = {
      description = "Chromium-based browser that runs in a terminal";
      homepage = "https://github.com/fathyb/carbonyl";
      license = lib.licenses.bsd3;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "carbonyl";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
