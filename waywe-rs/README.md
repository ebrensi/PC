# waywe-rs Nix Package

A Nix package for [waywe-rs](https://github.com/hack3rmann/waywe-rs), a blazingly fast video wallpaper engine for Wayland.

## What is waywe-rs?

waywe-rs is a highly efficient wallpaper software for wlroots-based Wayland compositors (like Hyprland or Sway). It supports:

- Image wallpapers in various formats
- Video wallpapers (h.264 and h.265 encoded MP4)
- Hardware-accelerated video decoding via libva
- Configurable transition animations with effects

## Files Included

- `waywe-rs.nix` - The main Nix package derivation
- `waywe-module.nix` - Example NixOS module with systemd service
- `build-waywe.sh` - Helper script with instructions

## Building the Package

### Step 1: Get the source hash

First, you need to get the correct hash for the source:

```bash
nix-prefetch-github hack3rmann waywe-rs --rev main
```

This will output JSON with a hash. Copy the hash value and update it in `waywe-rs.nix` where it says `hash = "";`

Alternatively, to pin to a specific commit:

```bash
nix-prefetch-github hack3rmann waywe-rs --rev <commit-hash>
```

### Step 2: Get the cargo hash

After updating the source hash, try building:

```bash
nix build -f waywe-rs.nix
```

This will fail with a hash mismatch error showing the correct `cargoHash`. Copy that hash and update `cargoHash = "";` in `waywe-rs.nix`.

### Step 3: Build successfully

Run the build command again and it should succeed:

```bash
nix build -f waywe-rs.nix
```

## Using in Your NixOS Configuration

### Method 1: Simple Installation

Add to your NixOS configuration:

```nix
environment.systemPackages = [
  (pkgs.callPackage ./waywe-rs.nix {})
];
```

### Method 2: With Systemd Service (Recommended)

Import the module in your configuration:

```nix
# In your flake.nix or configuration.nix
imports = [
  ./waywe-module.nix
];
```

This will:
- Install the waywe package
- Create a systemd user service that auto-starts on login
- Set up example configuration

### Method 3: Direct Usage with Flake

You can also add it to your flake inputs:

```nix
{
  inputs = {
    # ... your other inputs
    waywe-rs = {
      url = "github:hack3rmann/waywe-rs";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, waywe-rs, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            (pkgs.callPackage ./waywe-rs.nix {
              src = waywe-rs;
            })
          ];
        }
      ];
    };
  };
}
```

## Usage

Once installed:

```bash
# Start the daemon (or enable the systemd service)
waywe start

# Set a video wallpaper
waywe video path/to/video.mp4

# Set an image wallpaper
waywe image path/to/image.jpg

# Set wallpaper for specific monitor
waywe video --monitor 0 path/to/video.mp4

# Create a preview
waywe preview preview.png

# Get help
waywe help
```

## Configuration

Configuration file location: `~/.config/waywe/config.toml`

Example configuration:

```toml
[animation]
duration-milliseconds = 2000
direction = "out"
easing = "ease-out"

[animation.center-position]
type = "random"
position = [0.0, 0.0]

[[effects]]
type = "blur"
n_levels = 4
level_multiplier = 2
```

## Troubleshooting

### Video Driver Issues

If you get `ERROR_FORMAT_NOT_SUPPORTED`, set the correct VA-API driver:

For Intel integrated graphics:
```bash
export LIBVA_DRIVER_NAME=iHD
```

For AMD:
```bash
export LIBVA_DRIVER_NAME=Gallium
```

You can add this to your NixOS configuration:

```nix
environment.sessionVariables = {
  LIBVA_DRIVER_NAME = "iHD"; # or "Gallium" for AMD
};
```

### Check VA-API Support

```bash
vainfo
```

This should show your VA-API driver and supported profiles.

## Requirements

- wlroots-based Wayland compositor (Hyprland, Sway, etc.)
- Hardware video acceleration support (libva)
- Vulkan with these extensions:
  - `VK_KHR_external_memory_fd`
  - `VK_EXT_image_drm_format_modifier`

## Dependencies

The package automatically includes:
- libva (hardware video acceleration)
- vulkan-loader
- wayland & wayland-protocols
- ffmpeg (for video decoding)

## License

waywe-rs is licensed under the MIT license.

## Credits

- Original project: https://github.com/hack3rmann/waywe-rs
- Inspired by [swww](https://github.com/LGFae/swww)
