{ ... }:

{
  # Plasma 6's power widget talks to power-profiles-daemon over D-Bus, so this
  # is what makes the desktop's own battery/performance switcher functional.
  # TLP would give finer control and usually better battery life, but the two
  # cannot coexist. nixos-hardware's common/pc/laptop profile already defaults
  # services.tlp.enable to (! power-profiles-daemon.enable), so enabling ppd
  # here is sufficient to keep TLP out.
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # Intel thermal daemon. The Crystal Well package in this chassis reaches its
  # thermal limit readily; thermald throttles gradually instead of letting the
  # firmware do it abruptly.
  services.thermald.enable = true;

  # Fan control through applesmc. nixos-hardware's apple profile already turns
  # mbpfan on, stated explicitly here so the settings below have a visible
  # owner. The default "aggressive" curve (low 55C / high 58C / max 78C) is
  # the right call for hardware this old and is left alone; only the polling
  # interval is relaxed from 1s to 5s to cut needless wakeups.
  services.mbpfan = {
    enable = true;
    settings.general.polling_interval = 5;
  };
}
