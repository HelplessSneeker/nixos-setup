# Gaming: Steam/Proton, GameMode, Gamescope, MangoHud. Shared -- bewusst
# hardware-agnostisch, damit fabricus-itinerans (Laptop) das gleiche Modul
# ziehen kann. Host-spezifisches (NVIDIA, 32-Bit-Grafik) bleibt im Host.
#
# VORAUSSETZUNG: nixpkgs.config.allowUnfree = true im Host -- Steam und
# proton-ge-bin sind unfree. Steht auf fabricus schon in der Host-Config;
# fuer einen NEUEN Host nicht vergessen, sonst bricht die Eval.
#
# Was programs.steam AUTOMATISCH mitbringt (also hier bewusst NICHT nochmal):
#   - hardware.graphics.enable32Bit = true   (32-Bit-Vulkan/GL fuer Proton)
#   - hardware.steam-hardware.enable = true  (udev-Regeln: Controller, Index, Deck)
#   - services.pipewire.alsa.support32Bit    (32-Bit-Audio)
# Beides ist auf fabricus schon anderweitig gesetzt -- gleicher Wert, also
# kein Options-Konflikt.
{ config, pkgs, lib, ... }:
{
  programs.steam = {
    enable = true;

    # Proton-GE deklarativ als Compat-Tool. Erscheint in Steam unter
    # Spiel -> Eigenschaften -> Kompatibilitaet als "GE-Proton...".
    # Damit ist protonup-qt ueberfluessig: Updates kommen ueber
    # `nix flake update` + rebuild, nicht ueber einen GUI-Downloader.
    extraCompatPackages = [ pkgs.proton-ge-bin ];

    # Steam laeuft in einer FHS-Sandbox: Tools, die per Launch-Option davor
    # gehaengt werden (`mangohud %command%`, `gamemoderun %command%`), muessen
    # INNERHALB dieser Env liegen. environment.systemPackages reicht dafuer
    # nicht -- die FHS-Env baut ihr /usr/bin nur aus diesen Paketen.
    extraPackages = with pkgs; [
      mangohud
      gamemode
    ];

    # Steam Input unter Wayland. Der Steam-Client verteilt Controller-Events
    # ueber X11-Input; unter Hyprland ohne XWayland-Client kommen sie nicht an.
    # extest uebersetzt sie auf uinput. Kostet nichts, wenn kein Controller da ist.
    extest.enable = true;

    # winetricks-Wrapper fuer Proton-Prefixes (fehlende DLLs, dxvk-Tweaks,
    # .NET-Installer). Braucht man frueher oder spaeter bei jedem zickigen Titel.
    protontricks.enable = true;

    # --- BEWUSST AUS: oeffnet Ports in der NixOS-Firewall ---
    # Erst aktivieren, wenn du die Funktion wirklich nutzt:
    # remotePlay.openFirewall = true;                # Remote Play, TCP/UDP 27031-27036
    # localNetworkGameTransfers.openFirewall = true; # Spiele-Kopie aus dem LAN, TCP 27040
    # dedicatedServer.openFirewall = true;           # SRCDS, TCP/UDP 27015

    # --- BEWUSST AUS: Big-Picture-Session direkt aus greetd ---
    # gamescopeSession + proprietaerer NVIDIA-Treiber + Wayland ist die
    # fragilste Kombination im ganzen Stack (und setzt zusaetzlich bwrap
    # setuid, wenn capSysNice an ist). Erst testen, wenn der normale
    # Desktop-Betrieb stabil laeuft.
    # gamescopeSession.enable = true;
  };

  # GameMode: setzt waehrend des Spiels CPU-Governor auf performance und
  # renict den Spielprozess. Aktiv wird es NUR, wenn ein Spiel es anfordert
  # -- entweder nativ (viele Titel koennen das) oder per Launch-Option
  # `gamemoderun %command%`. Im Leerlauf kostet es nichts, deshalb auch auf
  # dem Laptop unbedenklich.
  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 10;
      # GPU-Optimierungen (apply_gpu_optimisations) bleiben bewusst aus:
      # das ist Uebertakten per Config, upstream warnt explizit vor
      # Hardware-Schaeden. Wer das will, macht es bewusst und einzeln.
    };
  };

  # Gamescope: Micro-Compositor fuer Spiele (feste Aufloesung, FSR-Upscaling,
  # eigenes Fenster). Nuetzlich fuer Titel, die mit 4k/Wayland-Skalierung oder
  # Alt-Tab zicken -- Aufruf per Launch-Option, z.B.
  #   gamescope -W 2560 -H 1440 -f -- %command%
  programs.gamescope = {
    enable = true;
    # capSysNice bleibt aus: das setcap-Wrapping ist der haeufigste Grund,
    # warum gamescope auf NVIDIA gar nicht erst startet. Nur einschalten,
    # wenn Ruckler durch Scheduling nachweisbar sind.
    # capSysNice = true;
  };

  # Diagnose-Werkzeug: `vulkaninfo --summary` zeigt, welchen Treiber/GPU
  # Vulkan tatsaechlich sieht -- erste Frage bei "Spiel startet nicht".
  environment.systemPackages = with pkgs; [
    vulkan-tools
  ];

  # --- 32-Bit-Overlay (optional) ---
  # MangoHud ist ein Vulkan-Implicit-Layer. Bei 32-Bit-Titeln (aeltere Spiele,
  # einige Source-Engine-Games) braucht es die 32-Bit-Variante der Layer,
  # sonst bleibt das Overlay dort schwarz/leer. Erst aktivieren, wenn das
  # konkret auftritt -- der i686-Build kann lokal kompilieren muessen.
  # hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [ mangohud ];

  # --- Controller ueber Bluetooth (optional) ---
  # Auf fabricus ist bluetooth.service aktuell inaktiv. Fuer einen kabellosen
  # Xbox-Controller braucht es beides:
  # hardware.bluetooth.enable = true;
  # hardware.xpadneo.enable = true;   # Kernel-Modul mit korrektem Rumble/Mapping
  # Xbox-USB-Dongle statt Bluetooth waere stattdessen: hardware.xone.enable = true;
  # Per Kabel funktioniert jeder Xbox-/PS-Controller ohne Zusatz (xpad ist im Kernel).

  # --- Hinweise, die keine Option sind ---
  # * vm.max_map_count: auf Kernel 6.12 bereits 1048576 (geprueft auf fabricus
  #   am 06.08.2026). Der frueher uebliche sysctl-Workaround fuer Star Citizen &
  #   Co. ist damit obsolet.
  # * DLSS/Raytracing unter Proton sind PRO SPIEL Launch-Optionen, nichts
  #   Systemweites: PROTON_ENABLE_NVAPI=1 (DLSS), VKD3D_CONFIG=dxr (DX12-RT).
  # * Steam-Bibliothek auf der Windows-NTFS-Platte (nvme0n1p2) ist moeglich,
  #   aber Proton mag NTFS nicht (Case-Sensitivity, fehlende Symlinks, kaputte
  #   Permissions). Empfehlung: Bibliothek auf ext4 unter /home.
}
