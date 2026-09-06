{ username, ... }:

{
  # Temporary remote access while validating the MacBook hardware. Remove this
  # module and its import once the machine is stable.
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKZjdVoJHVwRVqLKlq3zswIGf44sZ+3ZcqYchvN1cl7 nix-mac-debug"
  ];
}
