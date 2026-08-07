# Gaming-Stack: Steam + Proton. Shared geschrieben, aktuell nur von
# hosts/fabricus importiert -- der Laptop entscheidet spaeter selbst.
#
# Voraussetzungen, die NICHT hier stehen, weil sie schon woanders leben:
#   hardware.graphics.enable32Bit        (hosts/fabricus)      -> 32-bit Vulkan/GL fuer Proton
#   services.pipewire.alsa.support32Bit  (modules/system-base) -> Ton in aelteren Titeln
# Fehlt eins davon auf einem neuen Host, startet Steam zwar, aber Proton-Titel
# nicht (bzw. stumm). Vor dem Import auf einem anderen Host also pruefen.
{ config, pkgs, lib, ... }:
{
  programs.steam = {
    enable = true;

    # Proton-GE als zusaetzliches Compat-Tool. Taucht in Steam unter
    # Eigenschaften -> Kompatibilitaet als waehlbare Proton-Version auf.
    # Deckt Titel ab, bei denen Valves Proton an Codecs/Anti-Cheat scheitert.
    # Weitere Versionen kann man spaeter mit protonup-qt nachziehen (siehe unten),
    # die landen dann in ~/.steam -- diese hier ist die deklarative Grundlage.
    extraCompatPackages = [ pkgs.proton-ge-bin ];

    # Eigene gamescope-Session: Steam Big Picture laeuft in einem eigenen
    # Micro-Compositor statt in Hyprland. Damit sind Aufloesungswechsel,
    # Skalierung und Tearing das Problem von gamescope, nicht des Desktops --
    # unter Wayland/NVIDIA der ruhigere Weg fuer Fullscreen.
    #
    # ACHTUNG: greetd startet in hosts/fabricus tuigreet mit fixem
    # `--cmd start-hyprland` und zeigt deshalb GAR KEINE Session-Auswahl.
    # Diese Session ist also erst sichtbar, wenn tuigreet auf `--sessions`
    # umgestellt wird. Ohne das bleibt sie ungenutzt -- Steam laeuft dann
    # einfach als normales Fenster unter Hyprland (voellig brauchbar).
    gamescopeSession.enable = true;
  };

  # udev-Regeln fuer Steam-Controller/-Deck-Peripherie. bfn hat aktuell keinen
  # Controller (07.08.2026), das Modul kostet aber nichts ausser ein paar
  # udev-Regeln -- und erspart die Sucherei, falls doch mal einer dazukommt.
  hardware.steam-hardware.enable = true;

  # gamemode: hebt beim Spielstart CPU-Governor auf performance, priorisiert
  # den Prozess und drosselt Hintergrund-Kram. Greift nur, wenn das Spiel
  # ueber den Wrapper startet -- Steam-Launch-Option:  gamemoderun %command%
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    # Auch einzeln nutzbar als Launch-Option, z.B. fuer einen Titel, der
    # unter Hyprland Skalierungsprobleme macht:
    #   gamescope -f -w 1920 -h 1080 -- %command%
    gamescope

    # FPS/Frametime/Temperatur-Overlay. Launch-Option:  mangohud %command%
    # Wichtig zur Beurteilung, ob die RTX 2060 (6 GB VRAM) limitiert oder
    # ob es an Proton liegt -- Frametime-Graph statt Bauchgefuehl.
    mangohud

    # GUI zum Nachziehen weiterer Proton-GE-/Wine-Builds ins User-Verzeichnis.
    # Ergaenzt das deklarative proton-ge-bin oben, ersetzt es nicht.
    protonup-qt
  ];
}
