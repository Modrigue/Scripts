#!/bin/bash
# Debian update commands
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt autoremove -y
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo flatpak update && sudo apt autoremove -y

# update flatpak packages
sudo flatpak update

# update sources and packages
sudo apt update
sudo apt upgrade -y
# or via nala
sudo apt install --only-upgrade nala -y
sudo nala upgrade -y

sudo apt dist-upgrade -y
sudo apt autoremove -y