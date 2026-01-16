{
  pkgs,
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  libva,
  vulkan-loader,
  wayland,
  wayland-protocols,
  llvmPackages,
  stdenv,
}:
let
  ffmpeg = pkgs.ffmpeg-full.overrideAttrs (_: { doCheck = false; });
in
rustPlatform.buildRustPackage rec {
  pname = "waywe-rs";
  version = "unstable-2026-01-16";

  src = fetchFromGitHub {
    owner = "hack3rmann";
    repo = "waywe-rs";
    rev = "0.0.10"; # You should pin this to a specific commit hash or tag
    hash = "sha256-I64T3F+BA2aipc94K1oYQ/WvfYHw0KBjkImQ8F9p2cg="; # Run `nix build` to get the correct hash
  };

  cargoHash = "sha256-ccBfg3B9mTzIOvrlHRVAZeH6NIOOU82qHbdluQLHAsM=";

  # Tests require a running Wayland compositor
  doCheck = false;

  # Patch the video crate's Cargo.toml to remove build-vaapi feature
  # This prevents ffmpeg-sys-next from trying to build from source
  postPatch = ''
    substituteInPlace crates/video/Cargo.toml \
      --replace-fail 'ffmpeg-sys-next = { version = "7.1.3", features = ["build-vaapi"] }' \
                     'ffmpeg-sys-next = { version = "7.1.3" }'

    # Add build script to video crate to link against libva
    cat >> crates/video/build.rs <<'EOF'
fn main() {
    println!("cargo:rustc-link-lib=va");
}
EOF
  '';

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libva
    vulkan-loader
    wayland
    wayland-protocols
    ffmpeg
  ];

  # Set LIBCLANG_PATH for bindgen
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  # Help bindgen find system headers
  BINDGEN_EXTRA_CLANG_ARGS = builtins.concatStringsSep " " [
    "-isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion llvmPackages.clang}/include"
    "-isystem ${stdenv.cc.libc.dev}/include"
    "-isystem ${ffmpeg.dev}/include"
  ];

  # The project builds two binaries: waywe and waywe-daemon
  # Both are installed by cargo automatically

  # Ensure Vulkan and VA-API libraries can be found at runtime
  postInstall = ''
    wrapProgram $out/bin/waywe-daemon \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libva vulkan-loader ffmpeg]}
  '';

  meta = with lib; {
    description = "Blazingly fast video wallpaper engine for Wayland";
    longDescription = ''
      waywe is a highly efficient wallpaper software for wlroots-based Wayland
      compositors. It supports image and video wallpapers with hardware-accelerated
      decoding via libva and configurable transition animations.

      Features:
      - Image wallpapers in various formats
      - Video wallpapers (h.264 and h.265 encoded MP4)
      - Configurable transition animations
      - Hardware-accelerated video decoding
    '';
    homepage = "https://github.com/hack3rmann/waywe-rs";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "waywe";
  };
}
