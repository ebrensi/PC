{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, makeWrapper
, libva
, vulkan-loader
, wayland
, wayland-protocols
, ffmpeg
}:

rustPlatform.buildRustPackage rec {
  pname = "waywe-rs";
  version = "unstable-2026-01-16";

  src = fetchFromGitHub {
    owner = "hack3rmann";
    repo = "waywe-rs";
    rev = "0.0.10";  # You should pin this to a specific commit hash or tag
    hash = "";  # Run `nix build` to get the correct hash
  };

  cargoHash = "";  # Run `nix build` to get the correct hash

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

  # The project builds two binaries: waywe and waywe-daemon
  # Both are installed by cargo automatically
  
  # Ensure Vulkan and VA-API libraries can be found at runtime
  postInstall = ''
    wrapProgram $out/bin/waywe-daemon \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libva vulkan-loader ]}
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
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "waywe";
  };
}
