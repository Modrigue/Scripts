#!/bin/bash
# Debian update commands
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt purge '~o' -y
sudo apt update && sudo apt full-upgrade -y && sudo flatpak update && sudo apt autoremove -y && sudo apt purge '~o' -y

# update flatpak packages
sudo flatpak update

# update sources and packages
sudo apt update
sudo apt full-upgrade -y
# or via nala
sudo apt install --only-upgrade nala -y
sudo nala full-upgrade -y

sudo apt autoremove -y
sudo apt purge '~o' -y
sudo apt autoclean -y