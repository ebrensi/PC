let
  # Your system's SSH host public keys
  host-home-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjqqggoXpaVqylXWGG1myX89SZeYpWkM78w+4t350TJ root@adder-ws";
  host-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA+n6JXJc1/RzoiDdKswMZL7toAQurB7lRULXUGJ4PS root@thinkpad";
  all-hosts = [
    host-laptop
    host-home-server
  ];
in {
  "github-key.age".publicKeys = all-hosts; # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXFGk5SnYLScFm7rmFUhx36jaYX0sol85ajQczJvMj+ efrem-github
  "angelProtection.age".publicKeys = all-hosts; # ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY efrem-angelProtection
  "home-nix-cache.age".publicKeys = [host-home-server]; # home-cache:J+HKp0Hm3fkc1jK8ovnt5bPbRuH7Coq3d+Ukxx/pW2w=
}
