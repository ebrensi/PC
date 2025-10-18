let
  home-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjqqggoXpaVqylXWGG1myX89SZeYpWkM78w+4t350TJ root@adder-ws";
  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA+n6JXJc1/RzoiDdKswMZL7toAQurB7lRULXUGJ4PS root@thinkpad";
  user-efrem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXFGk5SnYLScFm7rmFUhx36jaYX0sol85ajQczJvMj+ BarefootEfrem@gmail.com";
  all-machines = [
    laptop
    home-server
  ];
  all-users = [user-efrem];
in {
  "efrem.age".publicKeys = all-machines ++ [user-efrem];
  "AngelProtection-efrem.age".publicKeys = all-machines ++ [user-efrem];
  "home-nix-cache.age".publicKeys = [home-server] ++ all-users;
  "guardian-envrc.age".publicKeys = all-machines ++ [user-efrem];
  "wakatime.age".publicKeys = all-machines ++ [user-efrem];
}
