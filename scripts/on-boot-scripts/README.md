# UDM Boot Script

## Features

Allows you to run a shell script at anytime your UDM starts / reboots

## Install

1. Run the `./install.sh` script on your UDM.

   This is a force to install script so will uninstall any previous version and install on_boot keeping your on boot files.

2. Copy any shell scripts you want to run to /data/on_boot.d on your UDM and make sure they are executable and have the correct shebang (#!/bin/bash). Additionally, scripts need to have a `.sh` extention in their filename.
