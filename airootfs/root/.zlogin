#!/bin/zsh
# Clear the screen and launch the Architect Installer the moment root logs in
clear
if [ -x "/usr/local/bin/auto-install.sh" ]; then
    /usr/local/bin/auto-install.sh
else
    echo "[ERROR] Installer script not found or missing execute permissions!"
fi
