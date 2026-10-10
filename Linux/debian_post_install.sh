#!/bin/bash
# My Debian post-installation script, to be copy-pasted step-by-step and/or adapted given your needs and preferences.
# Warning: some installations may require a reboot.

# update sources and packages
sudo apt update
sudo apt dist-upgrade -y

# for Virtual Box
sudo sh /media/$USER/VGA_VERSION/VBoxLinuxAdditions.run
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
sudo apt install -y nala

# check and update fastest mirrors
sudo apt fetch
sudo apt update

# misc cli tools
sudo apt install -y curl wget vim neofetch htop btop duf preload httpie hardinfo

# flatpak
sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#sudo reboot

# browsers: remove preinstalled Firefox ESR
sudo apt remove firefox-esr
sudo flatpak install firefox brave mullvad

# browser set Flatpak Brave as default browser
xdg-settings set default-web-browser com.brave.Browser.desktop

# misc tools
sudo apt install -y gparted libavcodec-extra tlp
sudo flatpak install thunderbird gimp vlc inkscape filezilla keepassxc jitsi drawio

# VS code
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft-archive-keyring.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo apt install -y apt-transport-https
sudo apt update
sudo apt install -y code

# other development tools
sudo apt install -y build-essential cmake
sudo apt install -y python3-venv python3-pip
sudo apt install -y nodejs npm
sudo npm install -g typescript
sudo flatpak install intellij pycharm postman dbeaver
#sudo flatpak install gitkraken # icon bug
wget https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.deb
sudo dpkg -i gitkraken-amd64.deb

# .NET tools
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install -y dotnet-sdk-8.0
sudo dotnet workload update
dotnet new install Avalonia.Templates

# music
sudo flatpak install musescore audacity

# LibreOffice: remove obsolete preinstalled version and install flatpak version
sudo apt remove libreoffice-common libreoffice-core libreoffice-gnome libreoffice-gtk3 libreoffice-help-common libreoffice-help-en-us libreoffice-help-fr libreoffice-help-es libreoffice-style-colibre libreoffice-style-elementary
sudo flatpak install libreoffice

# remove LibreOffice
sudo apt purge "libreoffice*"
sudo apt autoremove --purge
# check
dpkg -l | grep libreoffice

# OnlyOffice


# broadcom wifi card driver
sudo apt install broadcom-sta-dkms

# nvidia driver
sudo apt install nvidia-detect
nvidia-detect
sudo apt install nvidia-driver # if needed

# additional gnome tools
sudo apt install -y gnome-system-tools
sudo apt install -y gnome-software gnome-software-plugin-flatpak

# additional kde tools
sudo apt install -y kuser
sudo apt install -y plasma-discover plasma-discover-backend-flatpak
