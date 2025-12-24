#!/bin/bash

APP_NAME="swapos"
SOURCE_FILE="swapos.sh"
INSTALL_DIR="/usr/local/bin"
CONF_NAME="swapos.conf"
CONF_FILE="/etc/swapos.conf"

if [ ! -f "./$SOURCE_FILE" ]; then
  echo "Error: Could not find '$SOURCE_FILE' in current directory."
  exit 1
fi

echo "Installing $APP_NAME..."

chmod +x "$SOURCE_FILE"

# Create symbolic link
echo "Creating link: $INSTALL_DIR/$APP_NAME -> $(pwd)/$SOURCE_FILE"
sudo ln -sf "$(pwd)/$SOURCE_FILE" "$INSTALL_DIR/$APP_NAME"

echo "Installing configuration..."

if [ -f "./$CONF_NAME" ]; then
  if [ ! -f "$CONF_FILE" ]; then
    echo "Copying config to $CONF_FILE..."
    sudo cp "./$CONF_NAME" "$CONF_FILE"
    sudo chmod 644 "$CONF_FILE" # Readable by all, writable by root
  else
    echo "Config file already exists at $CONF_FILE. Skipping to preserve settings."
  fi
else
  echo "Warning: $CONF_NAME not found in current directory. Using default settings."
fi

if [ -L "$INSTALL_DIR/$APP_NAME" ]; then
  echo "Installation Complete! Run with: sudo $APP_NAME"
else
  echo "Installation failed."
  exit 1
fi
