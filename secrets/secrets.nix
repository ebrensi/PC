let
  home-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDLW9b8xLcTO+g31JJJEmzVOgLP4tKmQ2UVYXftGLYzw root@adder-ws";
  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA+n6JXJc1/RzoiDdKswMZL7toAQurB7lRULXUGJ4PS root@thinkpad";
  m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2+sxwrvNQvq0mzJIu/c6mwDadnLcDczBd3CyAZ6p9U root@m1";
  user-efrem = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXFGk5SnYLScFm7rmFUhx36jaYX0sol85ajQczJvMj+ BarefootEfrem@gmail.com";
  all-machines = [
    laptop
    home-server
    m1
  ];
  all-users = [user-efrem];
in {
  "efrem.age".publicKeys = all-machines ++ [user-efrem];
  "AngelProtection-efrem.age".publicKeys = all-machines ++ [user-efrem];
  "home-nix-cache.age".publicKeys = [home-server] ++ all-users;
  "wakatime.age".publicKeys = all-machines ++ [user-efrem];
  "aws-credentials.age".publicKeys = all-machines ++ [user-efrem];
  "wg-ws-adder.age".publicKeys = [home-server] ++ [user-efrem];
  "wg-thinkpad.age".publicKeys = [laptop] ++ [user-efrem];
}
