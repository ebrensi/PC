let
  # Your system's SSH host public keys
  laptop = "ssh-ed25519 AAAAC3Nza...your-laptop-key";
  server = "ssh-ed25519 AAAAC3Nza...your-server-key";

  allSystems = [laptop server];
in {
  "github-ssh-key.age".publicKeys = allSystems;
}
