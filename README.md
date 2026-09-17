# NixOS flake for personal/developer machines

A NixOS flake that builds every machine I use from one repo. Start by reading
[flake.nix](./flake.nix) — it defines all the `nixosConfigurations` and the
deployment/installer outputs.

Everything specific to me lives in [user-efrem.nix](./user-efrem.nix) and
[secrets/](./secrets); you will want to replace most of that.

## Machines

| Attribute | Hardware | Role |
|---|---|---|
| `adder-ws` | System76 Adder WS | Desktop laptop that also acts as an always-on home server |
| `thinkpad` | Lenovo ThinkPad X1 Carbon 11th Gen | Personal laptop |
| `m1` | Apple Mac Mini M1 (Asahi / `nixos-apple-silicon`) | Headless `aarch64` remote builder |

## How the configurations are layered

Configurations are composed with `extendModules` rather than a flat list of
imports, so each machine only adds what makes it different:

```
system-base                     base.nix + user-efrem.nix + disko + agenix
├── gui-base                    + desktop-cosmic.nix + graphical.nix + disko-laptop-ssd.nix
│   ├── adder-ws                + machines/system76-adderws.nix + home-server.nix
│   └── thinkpad                + machines/thinkpad.nix + personal-laptop.nix
└── m1                          + machines/mac-mini-m1.nix + aarch64-builder.nix
```

### Module map

**Shared base**
- [base.nix](./base.nix) — bootloader, nix settings, binary caches, unfree, common CLI packages
- [user-efrem.nix](./user-efrem.nix) — the `efrem` user, shell, aliases (including `yay`), dotfiles
- [dev-folders.nix](./dev-folders.nix) — clones my project repos into `~/dev` on activation
- [micro.nix](./micro.nix) — `micro` editor config and colorscheme
- [hmon.nix](./hmon.nix) — out-of-tree package derivation (`callPackage`d from `base.nix`)

**Graphical**
- [desktop-cosmic.nix](./desktop-cosmic.nix) — COSMIC desktop + greeter, system76-scheduler
- [graphical.nix](./graphical.nix) — Chrome, VS Code, fonts, GUI apps
- [vscode-custom-extensions.nix](./vscode-custom-extensions.nix) — marketplace extensions missing from nixpkgs

**Roles**
- [home-server.nix](./home-server.nix) — always-on services, no sleep, auto-login
- [personal-laptop.nix](./personal-laptop.nix) — laptop-only tweaks and SSH config
- [aarch64-builder.nix](./aarch64-builder.nix) — headless profile, exposes the box as a remote builder
- [wireguard-peer.nix](./wireguard-peer.nix) — WireGuard mesh with endpoint discovery for NAT hole punching

**Disks and installers**
- [disko-laptop-ssd.nix](./disko-laptop-ssd.nix) — unencrypted GPT/NVMe layout used by both laptops
- [disko-usb-nvme.nix](./disko-usb-nvme.nix) — standalone layout for the m1's external USB NVMe (applied manually)
- [network-installer.nix](./network-installer.nix) — SSH-reachable installer ISO base
- [offline-installer.nix](./offline-installer.nix) — wraps a target system into a fully offline install ISO

## Secrets

Secrets are [agenix](https://github.com/ryantm/agenix)-encrypted under
[secrets/](./secrets). Recipients are declared in
[secrets/secrets.nix](./secrets/secrets.nix) — each machine's SSH host key plus
my personal key. `agenix` is in the dev shell, so `agenix -e somefile.age` works
after `nix develop` (or automatically via direnv).

## Dev shell

There is an [.envrc](./.envrc) (`use flake`), so with direnv the dev shell loads
on `cd`. Otherwise:

```bash
nix develop
```

That puts `agenix` and all the scripts from [dev-scripts.nix](./dev-scripts.nix)
on `$PATH`:

| Script | Purpose |
|---|---|
| `apply <store-path>` | Set the system profile to a store path and switch to it |
| `copy-to <host:port> <store-path>` | `nix copy` a closure straight to a remote machine |
| `deploy-binaries <flakeAttr> <host:port>` | Build locally, copy the closure over, activate remotely |
| `remote-build <flakeAttr> <host:port>` | Build a system closure *on* the remote machine, print the store path |
| `remote-build-deploy <flakeAttr> <host:port>` | Same, then activate it there |
| `install-direct <flakeAttr> <host:port>` | Full `nixos-anywhere` install (prompts before formatting the disk) |
| `tmx [name]` | Create/attach a named tmux session |

## Everyday use

Rebuild the machine you're sitting at — [user-efrem.nix](./user-efrem.nix)
defines a `yay` alias that runs `nixos-rebuild switch` through `nom` and warns
you if the kernel changed and you need to reboot:

```bash
yay
```

The long form:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

Deploy to another machine without making it build anything:

```bash
deploy-binaries .#nixosConfigurations.thinkpad thinkpad
```

## Build outputs

```bash
nix build .#adder-ws            # system toplevel (also .#thinkpad, .#m1)
nix build .#all-systems         # every machine at once, as a linkFarm
nix run  .#test                 # nix-fast-build over all-systems, skipping cached paths
```

## Installing onto a new machine

### Method 1: build the toplevel and activate it

Requires a machine already running NixOS with flakes enabled. Clone this repo
anywhere (`git clone git@github.com:ebrensi/PC.git`) and:

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
nix run .#apply ./result
```

On success `./result` is a symlink to the built system closure, and `apply`
sets it as the system profile and switches to it. Equivalent to
`sudo nixos-rebuild switch --flake .#<hostname>`.

### Method 2: offline installer ISO

Builds an ISO with the whole target system closure baked in, so the install
happens with no network at all:

```bash
nix build .#thinkpad-offline-installer-iso   # or .#adder-ws-offline-installer-iso
```

This takes a while, and the ISO is as big as the system closure (~7 GB for
`thinkpad`), so use an 8 GB or larger USB stick. Write it to `/dev/sdX`:

```bash
sudo dd if=./result/iso/*.iso of=/dev/sdX status=progress bs=4M conv=fsync oflag=direct
sudo eject /dev/sdX
```

It boots straight to a simple install menu.

### Method 3: network installer ISO

`nix build .#network-installer-iso` produces a minimal ISO that joins wifi and
starts `sshd` with my key authorized, plus avahi so the target announces itself
as `installer.local`. Boot the target off it, then install it remotely from
here (note the `root@` — the key is only authorized for root):

```bash
install-direct .#nixosConfigurations.thinkpad root@installer.local
```

It builds the closure locally, asks whether to format the disk (answer no to
reuse existing partitions), and hands both the disko script and the system
closure to `nixos-anywhere`. The whole closure goes over the network, so this
is slower than Method 2 on a slow link.

## Flake inputs

- `nixpkgs` — `nixos-unstable` (what everything tracks)
- `nixpkgs-stable` — `nixos-25.11`, passed through as `pkgs-stable` for the occasional package that needs to lag
- [`disko`](https://github.com/nix-community/disko) — declarative partitioning
- [`agenix`](https://github.com/ryantm/agenix) — secrets
- [`nixos-apple-silicon`](https://github.com/nix-community/nixos-apple-silicon) — Asahi support for the m1
- [`claude-code-nix`](https://github.com/sadjow/claude-code-nix) — applied as an overlay on all machines
