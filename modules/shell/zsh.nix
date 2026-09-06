{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    tree
  ];

  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
      ];
      theme = "robbyrussell";
    };

    shellAliases = {
      cat = "bat";
      c = "clear";
      ll = "ls -la";
    };
  };
}
