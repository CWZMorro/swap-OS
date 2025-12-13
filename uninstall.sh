#!/bin/bash

APP_NAME="swapos"
INSTALL_DIR="/usr/local/bin"

echo "Uninstalling $APP_NAME..."

if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
  sudo rm -f "$INSTALL_DIR/$APP_NAME"
  echo "Removed '$APP_NAME'."
else
  echo "'$APP_NAME' not found."
fi
