#!/bin/bash

# to install whisker menu
sudo apt install -y xfce4-whiskermenu-plugin
# add a shortcut for command xfce4-popup-whiskermenu
#sudo reboot

# to list all XFCE panels and their plugins
for pid in $(xfconf-query -c xfce4-panel -p /panels); do
    echo "Panel $pid:"
    xfconf-query -c xfce4-panel -p /panels/panel-$pid/plugin-ids | while read plugin_id; do
        plugin_type=$(xfconf-query -c xfce4-panel -p /plugins/plugin-$plugin_id)
        echo "  Plugin $plugin_id → $plugin_type"
    done
done

# to move panel X to the top
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=0"

# to move panel X to the bottom
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=100"

# to move panel X to the left
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=0"

# to move panel X to the right
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=100;y=0"

# to make panel X visible
xfconf-query -c xfce4-panel -p /panels/panel-X/visible -t bool -s true

# to make panel X hidden
xfconf-query -c xfce4-panel -p /panels/panel-X/visible -t bool -s false

# to make panel X autohide
xfconf-query -c xfce4-panel -p /panels/panel-X/autohide -t bool -s true

# to make panel X not autohide
xfconf-query -c xfce4-panel -p /panels/panel-X/autohide -t bool -s false

# to make panel X always visible
xfconf-query -c xfce4-panel -p /panels/panel-X/always-visible -t bool -s true

# to make panel X not always visible
xfconf-query -c xfce4-panel -p /panels/panel-X/always-visible -t bool -s false

# to make panel X always on top
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top -t bool -s true

# to make panel X not always on top
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top -t bool -s false

# to make panel X always on bottom
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom -t bool -s true

# to make panel X not always on bottom
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom -t bool -s false

# to make panel X always on left
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left -t bool -s true

# to make panel X not always on left
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left -t bool -s false

# to make panel X always on right
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right -t bool -s true

# to make panel X not always on right
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right -t bool -s false

# to make panel X always on top of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true

# to make panel X not always on top of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s false

# to make panel X always on bottom of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true

# to make panel X not always on bottom of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s false

# to make panel X always on left of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true

# to make panel X not always on left of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s false

# to make panel X always on right of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to make panel X not always on right of other panels:  
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s false

# to make panel X always on top of other panels and always on bottom of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true

# to make panel X always on top of other panels and always on left of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true

# to make panel X always on top of other panels and always on right of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to make panel X always on bottom of other panels and always on left of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true

# to make panel X always on bottom of other panels and always on right of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

4-panel # to make panel X always on top of other panels and always on left of other panels and always on right of other panels
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to make panel X always on bottom of other panels and always on left of other panels and always on right of other panels:
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to make panel X always on top of other panels and always on bottom of other panels and always on left of other panels and always on right of other panels:
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to make panel X always on top of other panels and always on bottom of other panels and always on left of other panels and always on right of other panels and always on top of other panels and always on bottom of other panels and always on left of other panels and always on right of other panels:
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-top-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-bottom-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-left-of-other-panels -t bool -s true
xfconf-query -c xfce4-panel -p /panels/panel-X/always-on-right-of-other-panels -t bool -s true

# to reset XFCE default panels
xfce4-panel --quit
rm -rf ~/.config/xfce4/panel
rm -rf ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
xfce4-panel &
sudo reboot now

# https://www.debugpoint.com/xfce-whisker-menu/
# command: xfce4-popup-whiskermenu