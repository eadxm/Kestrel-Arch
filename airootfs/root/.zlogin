#!/bin/zsh
# Clear the screen and launch the Architect Installer the moment root logs in
clear
if [ -f "/usr/local/bin/auto-install.sh" ]; then
    bash /usr/local/bin/auto-install.sh
else
    echo "[ERROR] Installer script not found at /usr/local/bin/auto-install.sh"
fi
