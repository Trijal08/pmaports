#!/bin/sh

# On the first pre-enable after cold probe, the DSI2 command interface comes up
# wedged. Every DCS write of the panel init sequence times out, so the panel is
# never initialised. The post_disable path performs a full controller/PHY
# reset, so a second enable works perfectly.
#
# See https://github.com/tdeval/uconsole-radxa-cm5-mainline/tree/master
#

. /init_functions.sh
. /init_functions_2nd.sh

# plymouth needs to let go of control so that display can be properly
# kicked
if [ "$nosplash" != "y" ] && [ "$IN_CI" = "false" ]; then
	splash_hide
fi

t=0
until [ -e /sys/class/graphics/fb0/blank ] || [ "$t" -ge 10 ]; do
	t=$((t + 1))
	sleep 0.5
done
if [ -e /sys/class/graphics/fb0/blank ]; then
	echo "Kicking display"
	echo 1 > /sys/class/graphics/fb0/blank
	sleep 1
	echo 0 > /sys/class/graphics/fb0/blank
fi

# now that display is kicked, start plymouth
if [ "$nosplash" != "y" ] && [ "$IN_CI" = "false" ]; then
	setup_framebuffer
	splash_start
	splash_set_message "Loading"
fi
