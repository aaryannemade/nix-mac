{ pkgs, ... }:

{
  home.sessionVariables.BROWSER = "librewolf";

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "librewolf.desktop" ];
      "text/xml" = [ "librewolf.desktop" ];
      "application/xhtml+xml" = [ "librewolf.desktop" ];
      "application/xml" = [ "librewolf.desktop" ];
      "x-scheme-handler/http" = [ "librewolf.desktop" ];
      "x-scheme-handler/https" = [ "librewolf.desktop" ];
      "x-scheme-handler/about" = [ "librewolf.desktop" ];
      "x-scheme-handler/unknown" = [ "librewolf.desktop" ];
    };
  };

  programs.librewolf = {
    enable = true;

    # Optional, but explicit.
    package = pkgs.librewolf;

    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      settings = {
        # LibreWolf ships WebGL off. Plenty of ordinary sites need it.
        "webgl.disable" = false;

        # ---- Hardware video decode ------------------------------------------
        # Software-decoding 1080p on a Haswell quad-core costs real battery and
        # spins the fans up, so push video onto the iGPU's fixed-function
        # decoder. intel-vaapi-driver is installed by hosts/peach/graphics.nix.
        #
        # `vaapi.enabled` is the VA-API switch itself; recent Firefox-derived
        # builds already default it on under Wayland, so this mostly documents
        # intent. `force-enabled` is the one that actually matters here: Firefox
        # keeps an allowlist of drivers it trusts for hardware decode, and this
        # machine's combination of an old Intel driver and a GCN 1.0 AMD part is
        # unlikely to be on it.
        #
        # Verify on real hardware: about:support -> Media -> "Hardware decoding"
        # should not read "unsupported" while a video plays.
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;

        # ---- Persistence -----------------------------------------------------
        # LibreWolf's defaults wipe cookies, history and cache on every
        # shutdown and enable resistFingerprinting. That means logging into
        # everything on each launch, and RFP additionally forces a fixed window
        # size and blocks timezone/locale leaks in ways that visibly break
        # sites. Traded away deliberately.
        "privacy.resistFingerprinting" = false;
        "network.cookie.lifetimePolicy" = 0;

        # Master switch for clear-on-shutdown.
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.cache" = false;
        "privacy.clearOnShutdown.offlineApps" = false;
        "privacy.clearOnShutdown.sessions" = false;

        # Firefox 128+ renamed these; both sets are set so the prefs keep
        # working across a LibreWolf major bump.
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
        "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
        "privacy.clearOnShutdown_v2.cache" = false;

        # Theme
        "ui.systemUsesDarkTheme" = 1;
      };
    };
  };

  # NOTE: nix-desktop also sets widget.wayland.fractional-scale.enabled = false.
  # Deliberately not carried over: this machine has a 2880x1800 Retina panel, so
  # whether disabling the fractional-scale protocol helps or produces blurry
  # rendering depends on the scale factor Plasma ends up using. Decide after
  # seeing it on the actual display.
}
