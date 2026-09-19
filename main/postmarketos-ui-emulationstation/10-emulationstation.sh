#!/bin/sh
# Sourced by /usr/share/cage-ui/cage-ui-session.sh before it execs
# $CAGE_UI_COMMAND, so this runs inside the Wayland session.

# Exported first, deliberately. This file is SOURCED by cage-ui-session.sh,
# so a failure anywhere below aborts the sourcing shell; if that happened
# before this line the session would exec nothing, cage would exit and tinydm
# would loop back to a login prompt with no UI. Setting it up front means the
# worst a broken tweak below can do is leave a setting unapplied.
export CAGE_UI_COMMAND="emulationstation --no-splash"

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
mkdir -p "$RA_DIR"
[ -f "$RA_CFG" ] || : > "$RA_CFG"

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

# Menu confirm/cancel. Left OFF: with this pad's layout RetroArch already
# confirms with A, and enabling the swap inverts it. Set explicitly rather
# than omitted, so the value is pinned either way.
menu_swap_ok_cancel = "false"

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
