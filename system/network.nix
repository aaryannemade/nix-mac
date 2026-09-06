{ hostname, pkgs, ... }:

{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    curl
    git
  ];
}
