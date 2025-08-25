#!/bin/bash

cat /etc/debian_version

# update sources format
sudo apt modernize-sources -y

# clean packages
sudo apt purge '~o' -y
sudo apt autoclean -y

# install fastfetch
sudo apt install -y fastfetch
