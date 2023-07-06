#!/bin/bash
# My Debian update script

# update flatpak packages
sudo flatpak update

# update sources and packages
sudo nala update
sudo nala dist-upgrade
