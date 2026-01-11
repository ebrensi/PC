{
  pkgs,
  lib,
  ...
}: {
  networking.hostName = lib.mkForce "installer";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "yes";
  };
  services.getty.greetingLine = lib.mkForce "   Check your network for installer.local";
  users.users.nixos.initialHashedPassword = lib.mkForce "p";
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce true;
  services.avahi = {
    enable = true;
    nssmdns4 = false;
    nssmdns6 = false;
    openFirewall = true;
    publish = {
      # see https://linux.die.net/man/5/avahi-daemon.conf
      enable = true;
      userServices = true;
      addresses = true;
    };
  };
}
