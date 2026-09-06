{ config, lib, ... }:

# Central unfree allowlist.
#
# `allowUnfreePredicate` is a *function*, so it can only be defined once and
# cannot be merged across modules. Feature modules append names to the
# `my.unfreePackages` list option instead, and this file turns the accumulated
# list into the single predicate.
#
# Usage from any module:
#   { ... }: { my.unfreePackages = [ "broadcom-sta" ]; }
{
  options.my.unfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "steam" ];
    description = "Unfree package names (lib.getName) permitted on this host.";
  };

  config.nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) config.my.unfreePackages;
}
