# NixOS flake for personal/developer PC configurations

Start by looking at [flake.nix](./flake.nix).  The default setup has two machine configurations, both inheriting from a
base configuration that contains non machine-specific stuff.  Everything that I felt was specific to my own interests I put in [./users.nix](./users.nix), and you will want to change much of that.


 ## Initial Setup/Install
 For now you will need a system with NixOS already on it and configured to use flakes. Then copy this folder to there or `git clone git@github.com:ebrensi/PC.git`.
 Then build it with 
 ```bash
 nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
 ```

 If everything goes successfully `./result` will be a symbolic link to the nix store path of the built system-closure.
This flake provides a convenient script `apply` to switch to an arbitrary system configuration given as a store path.

```bash
nix run .#apply ./result
```

Then your system will be the one defined in flake.nix nixosConfigurations as `<hostname>`.

Note this could have also been done with
```bash
nixos-rebuild switch --flake .#<hostname>
```

In [./users.nix](./users.nix) I defined a few aliases to make updating the system a terminal shortcut `yay`.
