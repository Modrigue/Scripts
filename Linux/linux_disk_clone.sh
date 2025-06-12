#!/bin/bash

# clone disk
sudo dd if=/dev/<SOURCE> of=/dev/<DESTINATION> bs=64K conv=noerror,sync status=progress
