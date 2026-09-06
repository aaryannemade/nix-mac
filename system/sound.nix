{ ... }:

{
  # Sound via PipeWire.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    wireplumber.enable = true;
  };
}
