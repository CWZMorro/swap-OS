#!/bin/bash

APP_NAME="swapos"
INSTALL_DIR="/usr/local/bin"
CONF_FILE="/etc/swapos.conf"

echo "Uninstalling $APP_NAME..."

if [ -f "$CONF_FILE" ]; then
  read -p "Do you want to remove the configuration file at $CONF_FILE? (y/N) " response
  if [[ "$response" =~ ^[yY]$ ]]; then
    sudo rm -f "$CONF_FILE"
    echo "Configuration removed."
  else
    echo "Configuration kept."
  fi
fi

if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
  sudo rm -f "$INSTALL_DIR/$APP_NAME"
  echo "Removed '$APP_NAME'."
else
  echo "'$APP_NAME' not found."
fi
