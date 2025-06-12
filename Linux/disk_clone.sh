#!/bin/bash

# clone disk (replace <SOURCE> and <DESTINATION> with your disk/partition paths)
sudo dd if=/dev/<SOURCE> of=/dev/<DESTINATION> bs=64K conv=noerror,sync status=progress
