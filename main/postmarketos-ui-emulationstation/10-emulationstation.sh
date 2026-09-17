#!/bin/sh
# Sourced by /usr/share/cage-ui/cage-ui-session.sh before it execs
# $CAGE_UI_COMMAND, so this runs inside the Wayland session.

# EmulationStation needs a writable config tree and will not create the
# resources link itself. CMake installs only the binary, so point at the
# copy this package ships.
if [ ! -d "$HOME/.emulationstation" ]; then
	mkdir -p "$HOME/.emulationstation"
fi
if [ ! -e "$HOME/.emulationstation/resources" ]; then
	ln -sf /usr/share/emulationstation/resources \
		"$HOME/.emulationstation/resources"
fi

# ES looks for themes under ~/.emulationstation/themes as well as the system
# path; link them so installed theme packages are picked up.
if [ ! -e "$HOME/.emulationstation/themes" ] && \
   [ -d /usr/share/emulationstation/themes ]; then
	ln -sf /usr/share/emulationstation/themes "$HOME/.emulationstation/themes"
fi

# ES prefers ~/.emulationstation/es_systems.cfg and only falls back to
# /etc/emulationstation/es_systems.cfg. On a first run with no /etc copy it
# writes a one-system example into $HOME, which then permanently shadows the
# real config. Remove that example so /etc wins.
if [ -f "$HOME/.emulationstation/es_systems.cfg" ] && \
   [ -f /etc/emulationstation/es_systems.cfg ]; then
	rm -f "$HOME/.emulationstation/es_systems.cfg"
fi

# ES ignores every system that contains no matching file, and quits with
# "No systems found!" if that leaves none. Keep the tools system non-empty so
# it always starts, even with no ROMs installed.
mkdir -p "$HOME/.emulationstation/tools"
if [ ! -e "$HOME/.emulationstation/tools/about.sh" ]; then
	printf '#!/bin/sh\nuname -a\n' > "$HOME/.emulationstation/tools/about.sh"
	chmod 755 "$HOME/.emulationstation/tools/about.sh"
fi

# ArchR sets this in es_settings; pipewire-pulse provides the endpoint.
export SDL_AUDIODRIVER=pulseaudio

export CAGE_UI_COMMAND="emulationstation --no-splash"
