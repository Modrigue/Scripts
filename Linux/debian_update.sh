#!/bin/bash
# My Debian update script

# update flatpak packages
sudo flatpak update

# update sources and packages
sudo apt update
sudo apt dist-upgrade -y
# or via nala
sudo apt install --only-upgrade nala -y
sudo nala upgrade -y