#!/bin/sh
# Sourced by /usr/share/cage-ui/cage-ui-session.sh before it execs
# $CAGE_UI_COMMAND, so this runs inside the Wayland session.

# Exported first, deliberately. This file is SOURCED by cage-ui-session.sh,
# so a failure anywhere below aborts the sourcing shell; if that happened
# before this line the session would exec nothing, cage would exit and tinydm
# would loop back to a login prompt with no UI. Setting it up front means the
# worst a broken tweak below can do is leave a setting unapplied.
export CAGE_UI_COMMAND="emulationstation --no-splash"

# The INFORMATION page renders VERSION blank because ES reads it from the
# ENVIRONMENT, not from any file: ApiSystem::getVersion() is just
# GetEnv("OS_VERSION"), and the "extra" variant is GetEnv("OS_BUILD").
# ArchR exports both from its own profile; nothing on postmarketOS does.
#
# Read in a subshell rather than sourcing os-release into this one: it
# defines generic names (NAME, VERSION, ID) that would leak into every
# login shell and into the ports launched from here.
OS_VERSION=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-${NAME:-postmarketOS} ${VERSION_ID:-}}")
OS_BUILD=$(. /etc/os-release 2>/dev/null; echo "${BUILD_ID:-${VERSION_ID:-}}")
export OS_VERSION OS_BUILD

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

# Pad mapping. Without es_input.cfg EmulationStation opens on its CONFIGURE
# INPUT wizard on a brand new card, and every button has to be walked through
# by hand before the UI is usable at all. The shipped file is the merged pad
# from r36s-mapper, mapped on this hardware - b=0 is the bottom face button,
# 4 is the unused Capture button, and the d-pad is a hat rather than buttons.
#
# Seeded only when absent, so reconfiguring input from the menu sticks: ES
# rewrites this file itself and must stay the owner of it.
if [ ! -f "$HOME/.emulationstation/es_input.cfg" ] && \
   [ -f /usr/share/emulationstation/es_input.cfg ]; then
	cp /usr/share/emulationstation/es_input.cfg \
		"$HOME/.emulationstation/es_input.cfg"
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

# ES opens the ALSA card named by AudioCard, and its default of "default"
# (i.e. sysdefault) exposes no mixer on this board -- the controls live on
# hw:0. Without this ES logs "VolumeControl::init() - Failed to find mixer
# elements!" and has no volume control of its own. ES rewrites es_settings.cfg
# on exit, so this has to be set before it starts.
ES_CFG="$HOME/.emulationstation/es_settings.cfg"
if [ -f "$ES_CFG" ]; then
	sed -i 's|name="AudioCard" value="[^"]*"|name="AudioCard" value="hw:0"|' "$ES_CFG"
	grep -q 'name="AudioCard"' "$ES_CFG" || \
		sed -i 's|</config>|    <string name="AudioCard" value="hw:0" />\n</config>|' "$ES_CFG"
fi

# RetroArch reads ~/.config/retroarch/retroarch.cfg in preference to
# /etc/retroarch.cfg, creates it on first launch and rewrites it on exit, so a
# system-wide file alone never takes effect. Inject what the device needs each
# session; this is idempotent and leaves everything else alone.
#
# The merged pad impersonates a real Nintendo Switch Pro Controller, so
# RetroArch's own profile from retroarch-joypad-autoconfig matches it on
# name and vendor/product (1406/8201) and configures it with no help from us.
#
# joypad_autoconfig_dir must be set to the SYSTEM path. Leaving it unset does
# not fall back there - RetroArch defaults to an autoconfig directory beside
# its own config, which is empty, and reports the pad as not configured.
# Pointing it at a user directory fails the same way, since the setting
# replaces the search path rather than adding to it. RetroArch appends the
# joypad driver's subdirectory (udev/) itself.
#
# Hotkeys are ours: the profile leaves them unbound, and without them there is
# no way back to EmulationStation. Indices come from that profile, which
# numbers the pad in ascending evdev code order - 9 is SELECT (Minus), 10 is
# START (Plus), 2 is X (BTN_NORTH).
RA_DIR="$HOME/.config/retroarch"
RA_CFG="$RA_DIR/retroarch.cfg"
mkdir -p "$RA_DIR" "$HOME/ROMs/bios" "$HOME/ROMs/saves" \
	"$HOME/ROMs/states" "$HOME/ROMs/screenshots" "$HOME/ROMs/config/retroarch"

# Every system directory es_systems.cfg declares, created up front on the ROM
# share. EmulationStation logs "System <x> path does not exist" and skips the
# system otherwise, so a fresh card shows nothing and gives no hint of where
# games are meant to go - and with the share on its own partition the tree no
# longer arrives with the rootfs. Cheap: 91 empty directories.
sed -n 's|.*<path>~/\(.*\)</path>.*|\1|p' /etc/emulationstation/es_systems.cfg |
	sort -u | while read -r _sysdir; do
		case "$_sysdir" in
			ROMs/*) mkdir -p "$HOME/$_sysdir" ;;
		esac
	done

# Preinstall Freedoom, so a fresh card has something to launch. With no game
# anywhere EmulationStation has no system to show and opens on its "no games
# found" error, which reads like a broken image rather than an empty one.
# Freedoom is a complete, freely licensed IWAD pair, and the doom system is
# already wired to gzdoom - which art-book-next themes as "id".
#
# Copied rather than symlinked so the share stays self contained: it is meant
# to survive a reflash that replaces /usr underneath it. Skipped once anything
# is in there, so deleting them makes them stay gone.
# GZDoom ships no joystick bindings at all, so a pad does nothing until a
# config exists. Seed ours once; GZDoom rewrites the file on exit, so anything
# changed from its own menus is kept.
if [ ! -f "$HOME/.config/gzdoom/gzdoom.ini" ]; then
	mkdir -p "$HOME/.config/gzdoom"
	cp /usr/share/emulationstation/gzdoom.ini "$HOME/.config/gzdoom/gzdoom.ini"
fi

if [ -z "$(ls -A "$HOME/ROMs/doom" 2>/dev/null)" ]; then
	mkdir -p "$HOME/ROMs/doom/iwads"
	for _wad in /usr/share/doom/freedoom*.wad \
			/usr/share/games/doom/freedoom*.wad \
			/usr/share/freedoom/freedoom*.wad; do
		[ -f "$_wad" ] && cp -f "$_wad" "$HOME/ROMs/doom/iwads/"
	done

	# One game list entry per game, named here rather than after whatever
	# the wad happens to be called. Only .doom is scanned, so the wads
	# themselves stay out of the list.
	if [ -f "$HOME/ROMs/doom/iwads/freedoom1.wad" ]; then
		echo "IWAD=iwads/freedoom1.wad" >"$HOME/ROMs/doom/Freedoom - Phase 1.doom"
	fi
	if [ -f "$HOME/ROMs/doom/iwads/freedoom2.wad" ]; then
		echo "IWAD=iwads/freedoom2.wad" >"$HOME/ROMs/doom/Freedoom - Phase 2.doom"
	fi
fi

# Anything a core previously wrote into the old system directory moves
# across once, so Dreamcast VMU saves and MAME hiscore data are not
# stranded.
#
# NEWER wins, and the loser is kept. These are not interchangeable
# assets: dc/vmu_save_*.bin are Dreamcast memory cards, i.e. actual game
# progress. A plain "skip if it already exists" silently shadows newer
# saves with whatever the ROM share happened to carry, which reads as
# lost progress.
if [ -d "$HOME/.config/retroarch/system" ]; then
	(cd "$HOME/.config/retroarch/system" 2>/dev/null &&
	 find . -mindepth 1 -type f | while read -r _f; do
		_t="$HOME/ROMs/bios/${_f#./}"
		if [ ! -e "$_t" ]; then
			mkdir -p "$(dirname "$_t")" && mv "$_f" "$_t"
		elif [ "$_f" -nt "$_t" ]; then
			cp -p "$_t" "$_t.pre-migration" && mv "$_f" "$_t"
		fi
	 done) || :
fi
[ -f "$RA_CFG" ] || : > "$RA_CFG"

# Consoles whose face layout is not Nintendo's get A/B and X/Y swapped
# back to this board's printed labels, per core.
#
# The pad itself stays positional, which is correct: RetroPad B is the
# bottom button, so it becomes SNES B, PlayStation Cross, Dreamcast A.
# That matches a real Switch Pro Controller and keeps SNES, GBA, GBC,
# NES, N64 and DS correct, because their layout genuinely matches this
# board. It is only the consoles that disagree that need adjusting:
#
#   Dreamcast   A bottom, B right, X left, Y top
#   PlayStation X bottom, O right, [] left, /\ top
#
# On both, the primary action sits at the bottom - where this board
# prints B - so without this the printed A cancels. Swapping per core
# puts accept back under A without disturbing the systems that are
# already right. Do NOT solve this by swapping the pad binds globally:
# that fixes these two and breaks every Nintendo system, and it also
# double-swaps whichever cores already have a remap.
#
# Written only when absent, so each stays editable by hand.
# Named by each core's RetroArch display name, which is also the
# directory name it uses under config/. Cores that are not installed
# simply leave an unused file behind, so listing the whole PlayStation
# family here costs nothing and covers a later install.
for _core in Flycast \
	PCSX-ReARMed "Beetle PSX" "Beetle PSX HW" SwanStation DuckStation PPSSPP; do
	_rmp="$RA_DIR/config/remaps/$_core/$_core.rmp"
	[ -e "$_rmp" ] && continue
	mkdir -p "$(dirname "$_rmp")"
	cat >"$_rmp" <<-'RMP'
	input_player1_btn_a = "0"
	input_player1_btn_b = "8"
	input_player1_btn_x = "1"
	input_player1_btn_y = "9"
	RMP
done

while IFS= read -r _kv; do
	case "$_kv" in '' | \#*) continue ;; esac

	# Drop every existing line for this key before appending, rather than
	# editing in place. RetroArch honours the FIRST occurrence of a key, so
	# an in-place edit that misses a duplicate - or an append next to one
	# already present - silently keeps the old value.
	_k=${_kv%% =*}
	sed -i "\\|^$_k *=|d" "$RA_CFG"
	echo "$_kv" >>"$RA_CFG"
done <<'RACFG'
# BIOS and core data live on the ROM share, not under ~/.config. They are
# content: they belong beside the games, they are what every other handheld
# firmware does (ArkOS, JELOS and the ArchR card this device came from all
# use <roms>/bios), and a config reset or a reinstall must not take them
# with it. One setting covers every core, since they all read
# system_directory - Beetle Saturn looks for mpr-17933.bin there, Flycast
# for dc/, MAME for its hiscore.dat, and so on.
#
# Cores also WRITE here (Dreamcast VMU saves, MAME hiscore data), so the
# directory has to stay writable - it is not a read-only asset store.
system_directory = "~/ROMs/bios"

# Everything a player would be upset to lose goes on the ROM share too, for
# the same reason the BIOS does: it is content, not configuration. It also
# makes the partition the only thing worth preserving across a reinstall -
# flash boot and root, leave STORAGE alone, and saves, states, screenshots
# and per-core overrides all survive. Left under ~/.config they sit on the
# root filesystem and every reflash wipes them.
savefile_directory = "~/ROMs/saves"
savestate_directory = "~/ROMs/states"
screenshot_directory = "~/ROMs/screenshots"
rgui_config_directory = "~/ROMs/config/retroarch"

# Input. The pad impersonates a Switch Pro Controller, so RetroArch's own
# profile configures it; only the hotkeys are ours. 9 is SELECT (Minus), 10 is
# START (Plus), 2 is X (BTN_NORTH).
input_driver = "udev"
input_joypad_driver = "udev"
joypad_autoconfig_dir = "/usr/share/libretro/autoconfig"
input_enable_hotkey_btn = "9"
input_exit_emulator_btn = "10"
input_menu_toggle_btn = "2"
input_autodetect_enable = "true"
input_max_users = "5"

# Explicit player-1 binds rather than relying on a joypad profile.
#
# RetroArch's own "Nintendo Switch Pro Controller" profile matches this pad on
# name and on 1406/8201, and still logs "not configured" - with the profile
# present in the driver's directory and its input_driver field matching the
# running driver. Under Wayland the input driver resolves to "x" from the GL
# context regardless of what input_driver is set to, and autoconfig never
# takes. Binding directly sidesteps the whole mechanism.
#
# Indices are the pad's capability bitmap in ascending evdev code order, which
# is also exactly what RetroArch's own profile uses:
#   0 SOUTH  1 EAST  2 NORTH  3 WEST  4 Z(unused)  5 TL  6 TR  7 TL2  8 TR2
#   9 SELECT  10 START  11 MODE  12 THUMBL  13 THUMBR
# and axes 0/1 left stick, 2/3 right stick, hat 0 for the D-pad.
input_player1_b_btn = "0"
input_player1_a_btn = "1"
input_player1_x_btn = "2"
input_player1_y_btn = "3"
input_player1_l_btn = "5"
input_player1_r_btn = "6"
input_player1_l2_btn = "7"
input_player1_r2_btn = "8"
input_player1_select_btn = "9"
input_player1_start_btn = "10"
input_player1_l3_btn = "12"
input_player1_r3_btn = "13"
input_player1_up_btn = "h0up"
input_player1_down_btn = "h0down"
input_player1_left_btn = "h0left"
input_player1_right_btn = "h0right"
input_player1_l_x_plus_axis = "+0"
input_player1_l_x_minus_axis = "-0"
input_player1_l_y_plus_axis = "+1"
input_player1_l_y_minus_axis = "-1"
input_player1_r_x_plus_axis = "+2"
input_player1_r_x_minus_axis = "-2"
input_player1_r_y_plus_axis = "+3"
input_player1_r_y_minus_axis = "-3"

# Render at the panel's native resolution. Without this RetroArch sizes the
# window from video_scale against the core geometry - 879x576 for a 256x192
# Genesis core - and cage scales that down to 640x480, which is what made the
# menu look small and grainy. Not a font or menu_scale_factor problem.
video_fullscreen = "true"
video_windowed_fullscreen = "false"
video_fullscreen_x = "640"
video_fullscreen_y = "480"
video_scale = "1.000000"

# Menu confirm/cancel: swap OFF. With this pad A confirms and B backs out,
# which is what the board's labels and ArchR both do.
#
# Pinned explicitly because RetroArch rewrites retroarch.cfg from memory on
# exit, so a value edited in the file while it is running is silently
# clobbered - the setting has to be changed in RetroArch's own menu, or
# written while it is not running.
menu_swap_ok_cancel = "false"
# The one this RetroArch actually reads. It writes three swap keys -
# menu_swap_ok_cancel, menu_swap_ok_cancel_buttons and
# menu_swap_scroll_buttons - and only the _buttons one drives the
# quick menu's A/B behaviour; setting the legacy name alone does nothing.
menu_swap_ok_cancel_buttons = "false"

# Most 2D cores have no analog input, so the left stick does nothing in them.
# Mode 1 makes it drive the D-pad for those cores while leaving genuinely
# analog cores (N64, PSX, PSP, Dreamcast) using it as a stick.
input_player1_analog_dpad_mode = "1"
input_player2_analog_dpad_mode = "1"

# Menu sizing: ozone at its defaults, exactly as ArchR runs it.
#
# The menu looked small and grainy because RetroArch was rendering at
# 879x576 (video_scale x core geometry) and cage was scaling that down onto
# the 640x480 panel - see the video block below, which pins the native
# resolution. It was never a font problem, and the scale/padding overrides
# that briefly lived here only inflated the UI once the real cause was
# fixed. Values are pinned rather than omitted so an oversized leftover in
# a user's config cannot survive.
# Menu: ozone, with its own font scaling enabled.
#
# ozone ignores menu_scale_factor and dpi_override entirely in this build
# (tested 1.0-5.0, and dpi 150-300, each with a fresh process at native
# resolution). What does work is ozone's own font scaling, added in 1.22 and
# shipped disabled: ozone_font_scale = 1 plus a global factor. Leave
# ozone_padding_factor at 1.0 - shrinking it crams the larger text.
#
# rgui scales correctly but is text-only, no icons. glui scales but looks
# like a phone UI. ozone is the only one with icons, so it stays.
menu_driver = "ozone"
menu_scale_factor = "1.000000"
dpi_override_enable = "false"
ozone_font_scale = "1"
ozone_font_scale_factor_global = "1.500000"
ozone_padding_factor = "1.000000"
menu_widget_scale_auto = "false"
menu_widget_scale_factor = "0.350000"
video_font_size = "32.000000"
menu_throttle_framerate = "true"

# RetroArch rewrites the whole config from memory on exit, which silently
# discards anything set while it is running and reverted several settings
# during bring-up. ArchR keeps this off and manages the config externally;
# do the same, so the values above are authoritative. Trade-off: changes made
# in RetroArch's own UI no longer persist across a restart.
config_save_on_exit = "false"

# Video, from ArchR's tuning for this hardware.
video_driver = "gl"
video_threaded = "true"
video_vsync = "true"
video_swap_interval = "1"
video_max_swapchain_images = "3"
video_smooth = "false"
video_shader_enable = "false"
video_fullscreen = "true"
video_refresh_rate = "60.000000"
video_frame_delay = "0"
video_hard_sync = "false"
video_black_frame_insertion = "0"
aspect_ratio_index = "22"

# Audio. ArchR's values and ArchR's driver. RetroArch has NO pipewire driver -
# its list here is alsa/alsathread/tinyalsa/oss/sdl2/pulse/null - so setting
# one silently falls back to plain alsa, which is what was happening. Note
# SDL_AUDIODRIVER=pipewire below is unrelated: that is EmulationStation's
# audio, not RetroArch's.
audio_driver = "alsathread"
audio_latency = "128"
audio_out_rate = "48000"
audio_sync = "true"
audio_rate_control = "true"
audio_rate_control_delta = "0.004999"
audio_max_timing_skew = "0.049999"
audio_resampler = "sinc"
audio_resampler_quality = "2"
audio_block_frames = "0"

# Latency and throughput.
input_poll_type_behavior = "2"
threaded_data_runloop_enable = "true"
rewind_enable = "false"
run_ahead_enabled = "false"
vrr_runloop_enable = "false"
fastforward_ratio = "0.000000"
fastforward_frameskip = "true"
RACFG

# PortMaster keeps its control scripts in the user's ports directory, which is
# user data rather than package-managed, so refresh the postmarketOS module
# into it whenever PortMaster is present. It is sourced as
# mod_${CFW_NAME}.txt, CFW_NAME coming from NAME= in /etc/os-release, and
# carries the per-port environment PortMaster itself needs (the SDL button
# label hint, Godot options, the platform helper). It ships in
# portmaster-compat.
PM_DIR="$HOME/ROMs/ports/PortMaster"
if [ -d "$PM_DIR" ] && [ -f /usr/share/portmaster/mod_postmarketOS.txt ]; then
	cp -f /usr/share/portmaster/mod_postmarketOS.txt "$PM_DIR/"

	# Replace PortMaster's mapper.txt, which get_controls() runs to build
	# the SDL controller database. The shipped one is written for
	# LibreELEC/JELOS: it sources /etc/profile.d/001-functions and
	# /etc/profile.d/100-gamecontroller-functions for get_setting() and
	# create_controller_db(), neither of which exists here, so it scrubs
	# the database and leaves a 1-byte file. SDL then falls back to its
	# built-in Switch Pro mapping, which is positional and puts A and B
	# the wrong way round on this board.
	#
	# Refreshed every session because PortMaster updates itself in place,
	# and because restoring a ROMs backup puts the JELOS version back.
	[ -f /usr/share/portmaster/mapper.txt ] &&
		cp -f /usr/share/portmaster/mapper.txt "$PM_DIR/mapper.txt"

	# PortMaster reads this to pick a device profile. The R36S matches the
	# rg351mp entry: same SoC family, 640x480, two analog sticks.
	mkdir -p "$HOME/.config"
	[ -f "$HOME/.config/.DEVICE" ] || echo "rg351mp" >"$HOME/.config/.DEVICE"

	# control.txt calls /storage/.config/PortMaster/mapper.txt to build the
	# SDL controller database. With /storage symlinked to the home
	# directory that resolves to ~/.config/PortMaster, which is not where
	# the tree actually lives - point it at the real one.
	[ -e "$HOME/.config/PortMaster" ] || ln -sfn "$PM_DIR" "$HOME/.config/PortMaster"
fi

# SDL's native PipeWire driver, not the pulseaudio one ArchR sets. Both work
# here - pulseaudio reaches PipeWire through the pipewire-pulse compatibility
# server - but going direct drops a protocol shim from the path. Tested equal
# or slightly better on this hardware. Requires an SDL built with PipeWire
# support; if that ever stops being true SDL falls back on its own, and
# pulseaudio remains a working alternative.
export SDL_AUDIODRIVER=pipewire
