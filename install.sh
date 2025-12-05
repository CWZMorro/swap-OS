#!/bin/bash

APP_NAME="swindows"
SOURCE_FILE="swindows.sh"
INSTALL_DIR="/usr/local/bin"

if [ ! -f "./$SOURCE_FILE" ]; then
  echo "Error: Could not find '$SOURCE_FILE' in current directory."
  exit 1
fi

echo "Installing $APP_NAME..."

chmod +x "$SOURCE_FILE"

# Create symbolic link
echo "Creating link: $INSTALL_DIR/$APP_NAME -> $(pwd)/$SOURCE_FILE"
sudo ln -sf "$(pwd)/$SOURCE_FILE" "$INSTALL_DIR/$APP_NAME"

if [ -L "$INSTALL_DIR/$APP_NAME" ]; then
  echo "Installation Complete! Run with: sudo $APP_NAME"
else
  echo "Installation failed."
  exit 1
fi
