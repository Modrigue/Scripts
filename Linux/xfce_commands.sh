#!/bin/bash

# to list all XFCE panels and their plugins:
for pid in $(xfconf-query -c xfce4-panel -p /panels); do
    echo "Panel $pid:"
    xfconf-query -c xfce4-panel -p /panels/panel-$pid/plugin-ids | while read plugin_id; do
        plugin_type=$(xfconf-query -c xfce4-panel -p /plugins/plugin-$plugin_id)
        echo "  Plugin $plugin_id → $plugin_type"
    done
done

# to move panel X to the top:
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=0"

# to move panel X to the bottom:
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=100"

# to move panel X to the left:
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=0;y=0"

# to move panel X to the right:
xfconf-query -c xfce4-panel -p /panels/panel-X/position -t string -s "p=10;x=100;y=0"


# to make XFCE remember the login at startup:
# https://libtechnophile.blogspot.com/2024/12/auto-fill-username-in-debian-xfce-login.html

# to configure XFCE whisker menu:
# https://www.debugpoint.com/xfce-whisker-menu/
# command: xfce4-popup-whiskermenu