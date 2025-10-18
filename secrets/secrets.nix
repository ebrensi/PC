let
  host-home-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjqqggoXpaVqylXWGG1myX89SZeYpWkM78w+4t350TJ root@adder-ws";
  host-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA+n6JXJc1/RzoiDdKswMZL7toAQurB7lRULXUGJ4PS root@thinkpad";
  user-efrem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXFGk5SnYLScFm7rmFUhx36jaYX0sol85ajQczJvMj+ BarefootEfrem@gmail.com";
  all-hosts = [
    host-laptop
    host-home-server
  ];
  users = [user-efrem];
in {
  "efrem.age".publicKeys = all-hosts ++ users;
  "AngelProtection-efrem.age".publicKeys = all-hosts ++ users;
  "home-nix-cache.age".publicKeys = [host-home-server] ++ users;
  "guardian-envrc.age".publicKeys = all-hosts ++ users;
}
