let
  # Your system's SSH host public keys
  # laptop = "ssh-ed25519 AAAAC3Nza...your-laptop-key";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjqqggoXpaVqylXWGG1myX89SZeYpWkM78w+4t350TJ root@adder-ws";

  allSystems = [
    # laptop
    server
  ];
in {
  "github-key.age".publicKeys = allSystems;
  "angelProtection.age".publicKeys = allSystems;
}
