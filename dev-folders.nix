#  When this module is included in a NixOS configuration, it will set up
#  the specified development folders by cloning the associated Git repositories
#  into the user's home directory under ~/dev.
{
  config,
  pkgs,
  ...
}: let
  user = "efrem";
  dev-folders = {
    Guardian = "git@github.com:AngelProtection/Guardian.git";
    Geminae = "git@github.com:Project-Geminae/Geminae.git";
    heatflask = "git@github.com:ebrensi/heatflask.git";
    PC = "git@github.com:ebrensi/PC.git";
  };
  # Helper function to flatten nested attributcde set into path/repo pairs
  flattenDevFolders = attrSet: path: let
    processValue = name: value: let
      newPath =
        if path == ""
        then name
        else "${path}/${name}";
    in
      if builtins.isString value
      then [
        {
          path = newPath;
          repo = value;
        }
      ]
      else flattenDevFolders value newPath;
  in
    builtins.concatLists (builtins.attrValues (builtins.mapAttrs processValue attrSet));

  # Get flattened list of all repos to clone
  reposToClone = flattenDevFolders dev-folders "";

  # Script to clone repositories
  cloneScript = pkgs.writeShellScript "setup-dev-folders" ''
    set -euo pipefail

    MAIN_USER="${user}"
    MAIN_USER_HOME=/home/$MAIN_USER
    DEV_DIR="$MAIN_USER_HOME/dev"

    # Set up SSH to use the correct key
    export GIT_SSH_COMMAND="ssh -i $MAIN_USER_HOME/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"

    echo "Setting up dev folders for user $MAIN_USER at $DEV_DIR"

    # Create base dev directory if it doesn't exist
    if [ ! -d "$DEV_DIR" ]; then
      mkdir -p "$DEV_DIR"
      chown "$MAIN_USER:users" "$DEV_DIR"
    fi

    ${builtins.concatStringsSep "\n" (map (repo: ''
        TARGET_DIR="$DEV_DIR/${repo.path}"
        if [ ! -d "$TARGET_DIR" ]; then
          mkdir -p "$(dirname $TARGET_DIR)"
          (git clone "${repo.repo}" "$TARGET_DIR" && echo "Successfully cloned ${repo.repo}" || echo "Failed to clone ${repo.repo}") &
        fi
      '')
      reposToClone)}

    # Wait for all background clone jobs to complete
    wait
  '';
in {
  environment.shellAliases = {
    pc = "cd /home/${user}/dev/PC";
    ap = "cd /home/${user}/dev/Guardian/provision/nix";
  };

  systemd.services.setup-dev-folders = {
    description = "Setup development folders";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      ExecStart = "${cloneScript}";
      RemainAfterExit = true;
    };
    path = with pkgs; [git coreutils openssh];
  };

  # Trigger the service asynchronously on every activation (rebuild)
  system.activationScripts.setup-dev-folders = {
    text = ''
      ${pkgs.systemd}/bin/systemctl start setup-dev-folders.service --no-block || true
    '';
    deps = [];
  };
}
