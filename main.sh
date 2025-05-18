#!/bin/bash

# One-click management script for AnyTLS-Go server
# Version: v0.0.8 (based on anytls/anytls-go)

# --- Global Configuration Parameters ---
ANYTLS_VERSION="v0.0.8"
BASE_URL="https://github.com/anytls/anytls-go/releases/download"
INSTALL_DIR_TEMP="/tmp/anytls_install_$$" # Use $$ to add randomness
BIN_DIR="/usr/local/bin"
SERVER_BINARY_NAME="anytls-server"
SERVER_BINARY_PATH="${BIN_DIR}/${SERVER_BINARY_NAME}"
SERVICE_FILE_BASENAME="anytls-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_FILE_BASENAME}"

# --- Utility Functions ---

# Check if a command exists
check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Install required packages
install_packages() {
  local packages_to_install=("$@")
  if [ ${#packages_to_install[@]} -eq 0 ]; then
    return 0
  fi
  echo "Attempting to install required packages: ${packages_to_install[*]}"
  if check_command apt-get; then
    apt-get update -qq && apt-get install -y -qq "${packages_to_install[@]}"
  elif check_command yum; then
    yum install -y -q "${packages_to_install[@]}"
  elif check_command dnf; then
    dnf install -y -q "${packages_to_install[@]}"
  else
    echo "Error: Could not determine package manager. Please install manually: ${packages_to_install[*]}"
    return 1
  fi
  for pkg in "${packages_to_install[@]}"; do
    if ! check_command "$pkg"; then
      echo "Error: Package $pkg installation failed."
      return 1
    fi
  done
  echo "Packages ${packages_to_install[*]} installed successfully."
  return 0
}

# URL encoding function
urlencode() { ... }  # (left unchanged, as it's already language-agnostic)

# Get public IP address
get_public_ip() {
  echo "Trying to obtain server's public IP address..." >&2
  ...
  echo "Warning: The above IP was obtained via 'hostname -I'. Please verify it's public." >&2
  ...
}

# Clean up temporary files
cleanup_temp() {
  if [ -d "$INSTALL_DIR_TEMP" ]; then
    echo "Cleaning up temporary install directory: $INSTALL_DIR_TEMP..." >&2
    rm -rf "$INSTALL_DIR_TEMP"
  fi
}
trap cleanup_temp EXIT SIGINT SIGTERM

# Require root permission
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This operation '$1' requires root privileges. Please try again using 'sudo $0 $1'."
        exit 1
    fi
}

# --- Install / Uninstall / Manage Functions ---

do_install() {
    require_root "install"
    echo "Starting installation/update of AnyTLS-Go service (Target version: ${ANYTLS_VERSION})..."
    echo "=================================================="

    read -r -p "Enter AnyTLS server listening port (default 8443): " ANYTLS_PORT
    ...

    while true; do
      read -r -s -p "Enter AnyTLS server password (required): " ANYTLS_PASSWORD
      ...
    done

    echo "Detected system architecture: $ANYTLS_ARCH"
    ...

    echo "Installing server binary to ${SERVER_BINARY_PATH} ..."
    ...

    echo "Creating/updating systemd service file: ${SERVICE_FILE} ..."
    ...

    echo "Reloading systemd and starting AnyTLS service..."
    ...
    
    if systemctl is-active --quiet "${SERVICE_FILE_BASENAME}"; then
        echo ""
        echo "🎉 AnyTLS service successfully installed/updated and started! 🎉"
        ...
    else
        echo "Error: AnyTLS service failed to start successfully."
    fi
}

do_uninstall() {
    require_root "uninstall"
    echo "Uninstalling AnyTLS-Go service..."
    ...
    echo "AnyTLS-Go service uninstallation complete."
}

start_service() { ... }
stop_service() { ... }
restart_service() { ... }
status_service() { ... }
log_service() { ... }

generate_and_display_qr_codes() {
    ...
    echo "-----------------------------------------------"
    echo "[Client Configuration Information]"
    echo "  Server Address : ${server_ip}"
    echo "  Server Port    : ${server_port}"
    echo "  Password       : ${server_password}"
    echo "  Protocol       : AnyTLS"
    echo "  Note           : anytls-go uses a self-signed cert. Client must enable 'Allow Insecure' or 'Skip Cert Verify'."
    echo "-----------------------------------------------"
    ...
    echo "[NekoBox Config Link]:"
    ...
    echo "[Shadowrocket Config Link]:"
    ...
    echo "Reminder: After scanning in Shadowrocket, manually enable “Allow Insecure” in TLS settings."
}

show_qr_codes_interactive() {
    echo "Regenerating configuration QR code..."
    ...
    echo "From service config, detected port: ${SAVED_PORT}"
    ...
}

display_manage_commands() {
    echo "[Common Management Commands]"
    echo "  Install/Update : sudo $0 install"
    echo "  Uninstall      : sudo $0 uninstall"
    echo "  Start Service  : sudo $0 start"
    echo "  Stop Service   : sudo $0 stop"
    echo "  Restart Service: sudo $0 restart"
    echo "  Status         : $0 status"
    echo "  Logs           : $0 log (e.g. -n 50)"
    echo "  Show QR Code   : $0 qr"
    echo "  Help           : $0 help"
    echo "-----------------------------------------------"
}

show_help_menu() {
    echo "AnyTLS-Go Server Management Script"
    echo "Usage: $0 [command]"
    echo ""
    echo "Available commands:"
    printf "  %-12s %s\n" "install" "Install or update AnyTLS-Go server (requires sudo)"
    printf "  %-12s %s\n" "uninstall" "Uninstall AnyTLS-Go server (requires sudo)"
    ...
    echo "Example: sudo $0 install"
}

# --- Entry Point ---
main() {
    ...
}

main "$@"
