{ pkgs, username, ... }:

{
  users.defaultUserShell = pkgs.zsh;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;

    # Set on first install with `passwd` after `nixos-install` prompts, or seed
    # one here with `initialPassword` / `hashedPassword` if preferred.
  };
}
