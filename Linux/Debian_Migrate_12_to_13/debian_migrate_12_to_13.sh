#!/bin/bash

# update current Debian 12
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt purge '~o' -y

sudo flatpak update

# update sources from Debian 12 to 13

# change "bookworm" to "trixie" in sources list
sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*

# replace version "12" to "13" in microsoft-prod.list if file exists
if [ -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
    sudo sed -i 's/12/13/g' /etc/apt/sources.list.d/microsoft-prod.list
fi

# update to Debian 13
sudo apt update
sudo apt full-upgrade -y

sudo reboot
