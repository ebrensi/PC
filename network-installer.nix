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
  # Empty string = no password, same as the upstream installation-device profile.
  # (A bare "p" here is not a valid hash, so it locked out password login entirely.)
  # Console access is via getty autologin; remote access is via the SSH key below.
  users.users.nixos.initialHashedPassword = lib.mkForce "";
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
