#!/bin/bash
# My Debian post-installation script, to be copy-pasted step-by-step and/or adapted given your needs and preferences.
# Warning: some installations may require a reboot.

# update sources and packages
sudo apt update
sudo apt dist-upgrade

# for Virtual Box
sudo sh /mnt/$USER/VGA_VERSION/VBoxLinuxAdditions.run
# from https://unix.stackexchange.com/questions/52667/file-permission-issues-with-shared-folders-under-virtual-box-ubuntu-guest-wind
sudo usermod -G vboxsf -a $USER # to give access to shared folder if existing

# nala for Debian >=12 / Ubuntu >=22
sudo apt update
sudo apt install nala

# nala for Debian <12 / Ubuntu <22
sudo su
wget -qO- https://deb.volian.org/volian/scar.key | gpg --dearmor | dd of=/usr/share/keyrings/volian-archive-scar.gpg
echo "deb [signed-by=/usr/share/keyrings/volian-archive-scar.gpg arch=amd64] https://deb.volian.org/volian/ scar main" > /etc/apt/sources.list.d/volian-archive-scar.list
exit
sudo apt update
sudo apt install nala

# check and update fastest mirrors
sudo nala fetch
sudo nala update

# misc cli tools
sudo nala install curl wget vim neofetch htop btop duf preload httpie

# XFCE: whisker menu
sudo nala install xfce4-whiskermenu-plugin
# add a shortcut for command xfce4-popup-whiskermenu
#sudo reboot

# flatpak
sudo nala install flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#sudo reboot

# browsers: remove preinstalled Firefox ESR
sudo nala remove firefox-esr
sudo flatpak install firefox brave mullvad

# LibreOffice: remove obsolete preinstalled version and install flatpak version
sudo nala remove libreoffice-common libreoffice-core libreoffice-gnome libreoffice-gtk3 libreoffice-help-common libreoffice-help-en-us libreoffice-help-fr libreoffice-help-es libreoffice-style-colibre libreoffice-style-elementary
sudo flatpak install libreoffice

# misc tools
sudo nala install gparted libavcodec-extra
sudo flatpak install thunderbird gimp vlc inkscape filezilla keepassxc jitsi drawio

# VS code
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft-archive-keyring.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo nala install apt-transport-https
sudo nala update
sudo nala install code

# other development tools
sudo nala install cmake
sudo nala install python3-venv python3-pip
sudo nala install nodejs npm
sudo npm install -g typescript
sudo flatpak install intellij pycharm postman dbeaver
#sudo flatpak install gitkraken # icon bug
wget https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.deb
sudo dpkg -i gitkraken-amd64.deb


# .NET tools
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo nala install -y dotnet-sdk-8.0
sudo dotnet workload update
dotnet new install Avalonia.Templates

# music
sudo flatpak install musescore audacity

# broadcom wifi card driver
sudo nala install broadcom-sta-dkms

# nvidia driver
sudo nala install nvidia-detect
nvidia-detect
sudo nala install nvidia-driver # if needed

# additional gnome / kde tools
sudo nala install gnome-system-tools
sudo nala install gnome-software gnome-software-plugin-flatpak
# or
sudo nala install kuser
sudo nala install plasma-discover plasma-discover-backend-flatpak

# to make XFCE remember the login at startup:
# https://libtechnophile.blogspot.com/2024/12/auto-fill-username-in-debian-xfce-login.html

# to configure XFCE whisker menu:
# https://www.debugpoint.com/xfce-whisker-menu/
