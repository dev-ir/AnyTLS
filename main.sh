#!/bin/bash

# AnyTLS-Go Server One-Click Management Script
# Version: v0.0.8 (Based on anytls/anytls-go)

# --- Global Configuration Parameters ---
ANYTLS_VERSION="v0.0.8"
BASE_URL="https://github.com/anytls/anytls-go/releases/download"
INSTALL_DIR_TEMP="/tmp/anytls_install_$$" # Using $$ for randomness
BIN_DIR="/usr/local/bin"
SERVER_BINARY_NAME="anytls-server"
SERVER_BINARY_PATH="${BIN_DIR}/${SERVER_BINARY_NAME}"
SERVICE_FILE_BASENAME="anytls-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_FILE_BASENAME}"

# --- Utility Functions ---

# Check if command exists
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
    echo "Error: Could not determine system package manager. Please manually install: ${packages_to_install[*]}"
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

# URL encode function
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o
    for (( pos=0 ; pos<strlen ; pos++ )); do
       c=${string:$pos:1}
       case "$c" in
          [-_.~a-zA-Z0-9] ) o="${c}" ;;
          * )               printf -v o '%%%02x' "'$c"
       esac
       encoded+="${o}"
    done
    echo "${encoded}"
}

# Get public IP address
get_public_ip() {
  echo "Attempting to get server public IP address..." >&2 # Output to stderr
  local IP_CANDIDATES=()
  IP_CANDIDATES+=("$(curl -s --max-time 8 --ipv4 https://api.ipify.org)")
  IP_CANDIDATES+=("$(curl -s --max-time 8 --ipv4 https://ipinfo.io/ip)")
  IP_CANDIDATES+=("$(curl -s --max-time 8 --ipv4 https://checkip.amazonaws.com)")
  IP_CANDIDATES+=("$(curl -s --max-time 8 --ipv4 https://icanhazip.com)")
  
  local valid_ip=""
  for ip_candidate in "${IP_CANDIDATES[@]}"; do
    if [[ "$ip_candidate" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      if ! [[ "$ip_candidate" =~ ^10\. ]] && \
         ! [[ "$ip_candidate" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && \
         ! [[ "$ip_candidate" =~ ^192\.168\. ]] && \
         ! [[ "$ip_candidate" =~ ^127\. ]]; then
        valid_ip="$ip_candidate"
        break
      fi
    fi
  done

  if [ -n "$valid_ip" ]; then
    echo "$valid_ip"
    return 0
  else
    local local_ips
    local_ips=$(hostname -I 2>/dev/null)
    if [ -n "$local_ips" ]; then
        for ip_candidate in $local_ips; do
             if [[ "$ip_candidate" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                if ! [[ "$ip_candidate" =~ ^10\. ]] && \
                   ! [[ "$ip_candidate" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && \
                   ! [[ "$ip_candidate" =~ ^192\.168\. ]] && \
                   ! [[ "$ip_candidate" =~ ^127\. ]]; then
                    echo "$ip_candidate"
                    echo "Warning: The above IP address was obtained via 'hostname -I', please confirm it's a public IP." >&2
                    return 0
                fi
            fi
        done
    fi
    echo "" # Return empty if no IP found
    return 1
  fi
}

# Cleanup temporary files
cleanup_temp() {
  if [ -d "$INSTALL_DIR_TEMP" ]; then
    echo "Cleaning up temporary installation directory: $INSTALL_DIR_TEMP..." >&2
    rm -rf "$INSTALL_DIR_TEMP"
  fi
}
trap cleanup_temp EXIT SIGINT SIGTERM # Ensure cleanup on exit

# Check root privileges
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This operation '$1' requires root privileges. Please use 'sudo $0 $1' and try again."
        exit 1
    fi
}

# --- Service Management and Installation/Uninstallation Functions ---

do_install() {
    require_root "install"
    echo "Starting AnyTLS-Go server installation/update (Target version: ${ANYTLS_VERSION})..."
    echo "=================================================="

    read -r -p "Enter AnyTLS server listening port (default 8443): " ANYTLS_PORT
    ANYTLS_PORT=${ANYTLS_PORT:-8443}
    if ! [[ "$ANYTLS_PORT" =~ ^[0-9]+$ ]] || [ "$ANYTLS_PORT" -lt 1 ] || [ "$ANYTLS_PORT" -gt 65535 ]; then
        echo "Error: Invalid port number \"$ANYTLS_PORT\"."
        exit 1
    fi

    local ANYTLS_PASSWORD ANYTLS_PASSWORD_CONFIRM
    while true; do
      read -r -s -p "Enter AnyTLS server password (required): " ANYTLS_PASSWORD
      echo
      if [ -z "$ANYTLS_PASSWORD" ]; then echo "Error: Password cannot be empty, please re-enter."; continue; fi
      read -r -s -p "Re-enter password for confirmation: " ANYTLS_PASSWORD_CONFIRM
      echo
      if [ "$ANYTLS_PASSWORD" == "$ANYTLS_PASSWORD_CONFIRM" ]; then break; else echo "Passwords don't match, please re-enter."; fi
    done

    local deps_to_install=()
    if ! check_command wget; then deps_to_install+=("wget"); fi
    if ! check_command unzip; then deps_to_install+=("unzip"); fi
    if ! check_command curl; then deps_to_install+=("curl"); fi
    if ! check_command qrencode; then deps_to_install+=("qrencode"); fi
    if ! install_packages "${deps_to_install[@]}"; then echo "Dependency installation failed, cannot continue."; exit 1; fi

    local ARCH_RAW ANYTLS_ARCH
    ARCH_RAW=$(uname -m)
    case $ARCH_RAW in
      x86_64 | amd64) ANYTLS_ARCH="amd64" ;;
      aarch64 | arm64) ANYTLS_ARCH="arm64" ;;
      *) echo "Error: Unsupported system architecture ($ARCH_RAW)."; exit 1 ;;
    esac
    echo "Detected system architecture: $ANYTLS_ARCH"

    local VERSION_FOR_FILENAME FILENAME DOWNLOAD_URL
    VERSION_FOR_FILENAME=${ANYTLS_VERSION#v}
    FILENAME="anytls_${VERSION_FOR_FILENAME}_linux_${ANYTLS_ARCH}.zip"
    DOWNLOAD_URL="${BASE_URL}/${ANYTLS_VERSION}/${FILENAME}"

    mkdir -p "$INSTALL_DIR_TEMP"
    echo "Downloading AnyTLS-Go from $DOWNLOAD_URL..."
    if ! wget -q -O "${INSTALL_DIR_TEMP}/${FILENAME}" "$DOWNLOAD_URL"; then
      echo "Error: Failed to download AnyTLS-Go."; exit 1
    fi

    echo "Extracting files to $INSTALL_DIR_TEMP ..."
    if ! unzip -q -o "${INSTALL_DIR_TEMP}/${FILENAME}" -d "$INSTALL_DIR_TEMP"; then
      echo "Error: Failed to extract AnyTLS-Go."; exit 1
    fi
    if [ ! -f "${INSTALL_DIR_TEMP}/${SERVER_BINARY_NAME}" ]; then
        echo "Error: Could not find ${SERVER_BINARY_NAME} after extraction."; exit 1
    fi

    echo "Installing server binary to ${SERVER_BINARY_PATH} ..."
    if systemctl is-active --quiet "${SERVICE_FILE_BASENAME}"; then # Stop service before replacing binary
        systemctl stop "${SERVICE_FILE_BASENAME}"
    fi
    if ! mv "${INSTALL_DIR_TEMP}/${SERVER_BINARY_NAME}" "${SERVER_BINARY_PATH}"; then
      echo "Error: Failed to move ${SERVER_BINARY_NAME}."; exit 1
    fi
    chmod +x "${SERVER_BINARY_PATH}"

    echo "Creating/updating systemd service file: ${SERVICE_FILE} ..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AnyTLS Server Service (Version ${ANYTLS_VERSION})
Documentation=https://github.com/anytls/anytls-go
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${SERVER_BINARY_PATH} -l 0.0.0.0:${ANYTLS_PORT} -p "${ANYTLS_PASSWORD}"
Restart=on-failure
RestartSec=10s
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo "Reloading systemd configuration and starting AnyTLS service..."
    systemctl daemon-reload
    if ! systemctl enable "${SERVICE_FILE_BASENAME}"; then echo "Error: Failed to enable auto-start."; exit 1; fi
    if ! systemctl restart "${SERVICE_FILE_BASENAME}"; then # Use restart to ensure it starts fresh
        echo "Error: Failed to start/restart AnyTLS service. Please check logs."; status_service; log_service -n 20; exit 1;
    fi
    
    sleep 2
    if systemctl is-active --quiet "${SERVICE_FILE_BASENAME}"; then
        echo ""
        echo "🎉 AnyTLS service successfully installed/updated and started! 🎉"
        local SERVER_IP
        SERVER_IP=$(get_public_ip)
        generate_and_display_qr_codes "${SERVER_IP}" "${ANYTLS_PORT}" "${ANYTLS_PASSWORD}" "install"
        display_manage_commands
    else
        echo "Error: AnyTLS service failed to start."; status_service; log_service -n 20;
    fi
}

do_uninstall() {
    require_root "uninstall"
    echo "Uninstalling AnyTLS-Go service..."
    if systemctl list-unit-files | grep -q "${SERVICE_FILE_BASENAME}"; then
        systemctl stop "${SERVICE_FILE_BASENAME}"
        systemctl disable "${SERVICE_FILE_BASENAME}"
        rm -f "${SERVICE_FILE}"
        echo "Systemd service file ${SERVICE_FILE} removed."
        systemctl daemon-reload
        systemctl reset-failed # Important for cleaning up failed state
        echo "Systemd configuration reloaded."
    else
        echo "AnyTLS-Go Systemd service not found."
    fi

    if [ -f "${SERVER_BINARY_PATH}" ]; then
        rm -f "${SERVER_BINARY_PATH}"
        echo "Server binary ${SERVER_BINARY_PATH} removed."
    else
        echo "Server binary ${SERVER_BINARY_PATH} not found."
    fi
    # Consider removing /etc/anytls-server if config files were stored there. Not in this script.
    echo "AnyTLS-Go service uninstallation complete."
}

start_service() { require_root "start"; echo "Starting AnyTLS service..."; systemctl start "${SERVICE_FILE_BASENAME}"; sleep 1; status_service; }
stop_service() { require_root "stop"; echo "Stopping AnyTLS service..."; systemctl stop "${SERVICE_FILE_BASENAME}"; sleep 1; status_service; }
restart_service() { require_root "restart"; echo "Restarting AnyTLS service..."; systemctl restart "${SERVICE_FILE_BASENAME}"; sleep 1; status_service; }
status_service() { echo "AnyTLS service status:"; systemctl status "${SERVICE_FILE_BASENAME}" --no-pager; }
log_service() { echo "Showing AnyTLS service logs (Press Ctrl+C to exit):"; journalctl -u "${SERVICE_FILE_BASENAME}" -f "$@"; }

generate_and_display_qr_codes() {
    local server_ip="$1"
    local server_port="$2"
    local server_password="$3"
    local source_action="$4" # "install" or "qr"

    if [ -z "$server_ip" ] || [ "$server_ip" == "YOUR_SERVER_IP" ]; then # YOUR_SERVER_IP is a placeholder
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!! WARNING: Failed to automatically get server public IP.     !!"
        if [ "$source_action" == "install" ]; then
            echo "!! QR codes and share links will have empty IP. Fill manually. !!"
        else # qr action
            echo "!! Please manually obtain public IP for client configuration.!!"
        fi
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        if [ "$source_action" == "qr" ] && [ "$server_ip" == "YOUR_SERVER_IP" ]; then return 1; fi # Abort QR if IP is placeholder from qr action
        server_ip="YOUR_SERVER_IP" # Use placeholder for URI if install
    fi
    
    echo "-----------------------------------------------"
    echo "【Client Configuration】"
    echo "  Server Address : ${server_ip}"
    echo "  Server Port    : ${server_port}"
    echo "  Password       : ${server_password}"
    echo "  Protocol       : AnyTLS"
    echo "  Note           : anytls-go uses self-signed certs, clients must enable 'allow insecure' or 'skip cert verification'."
    echo "-----------------------------------------------"

    if ! check_command qrencode; then
        echo "Warning: qrencode command not found, cannot generate QR codes."
        echo "Try running 'sudo $0 install' (will auto-install qrencode) or install manually (e.g., sudo apt install qrencode)."
        return 1
    fi
    
    local ENCODED_PASSWORD REMARKS NEKOBOX_URI SHADOWROCKET_URI
    ENCODED_PASSWORD=$(urlencode "${server_password}")
    REMARKS=$(urlencode "AnyTLS-${server_port}")

    NEKOBOX_URI="anytls://${ENCODED_PASSWORD}@${server_ip}:${server_port}?allowInsecure=true#${REMARKS}"
    echo ""
    echo "【NekoBox Config URL】:"
    echo "${NEKOBOX_URI}"
    echo "【NekoBox QR Code】 (ensure terminal supports UTF-8 and has enough space):"
    qrencode -t ANSIUTF8 -m 1 "${NEKOBOX_URI}"
    echo "-----------------------------------------------"

    SHADOWROCKET_URI="anytls://${ENCODED_PASSWORD}@${server_ip}:${server_port}#${REMARKS}"
    echo ""
    echo "【Shadowrocket Config URL】:"
    echo "${SHADOWROCKET_URI}"
    echo "【Shadowrocket QR Code】 (ensure terminal supports UTF-8 and has enough space):"
    qrencode -t ANSIUTF8 -m 1 "${SHADOWROCKET_URI}"
    echo "Note: Shadowrocket users must manually enable 'Allow Insecure' in TLS settings after scanning."
    echo "-----------------------------------------------"
    return 0
}

show_qr_codes_interactive() {
    echo "Regenerating configuration QR codes..."
    if [ ! -f "${SERVICE_FILE}" ]; then
        echo "Error: AnyTLS service appears not installed (${SERVICE_FILE} not found)."
        echo "Please run 'sudo $0 install' first."
        exit 1
    fi

    local deps_to_install_qr=()
    if ! check_command qrencode; then deps_to_install_qr+=("qrencode"); fi
    if ! check_command curl; then deps_to_install_qr+=("curl"); fi # For get_public_ip
    if ! install_packages "${deps_to_install_qr[@]}"; then echo "Dependency installation failed, cannot continue."; exit 1; fi

    local SAVED_PORT password_for_qr server_ip_for_qr
    SAVED_PORT=$(grep -Po 'ExecStart=.*-l 0\.0\.0\.0:\K[0-9]+' "${SERVICE_FILE}" 2>/dev/null)
    if [ -z "$SAVED_PORT" ]; then
        echo "Warning: Could not auto-read port from service file."
        read -r -p "Enter AnyTLS server's configured port: " SAVED_PORT
        if ! [[ "$SAVED_PORT" =~ ^[0-9]+$ ]]; then echo "Invalid port."; exit 1; fi
    else
        echo "Read port from service config: ${SAVED_PORT}"
    fi
    
    read -r -s -p "Enter your AnyTLS service password: " password_for_qr; echo
    if [ -z "$password_for_qr" ]; then echo "Password cannot be empty."; exit 1; fi

    server_ip_for_qr=$(get_public_ip)
    # generate_and_display_qr_codes will handle empty IP with a placeholder
    
    generate_and_display_qr_codes "${server_ip_for_qr}" "${SAVED_PORT}" "${password_for_qr}" "qr"
}

display_manage_commands() {
    echo "【Management Commands】"
    echo "  Install/Update: sudo $0 install"
    echo "  Uninstall     : sudo $0 uninstall"
    echo "  Start Service : sudo $0 start"
    echo "  Stop Service  : sudo $0 stop"
    echo "  Restart       : sudo $0 restart"
    echo "  Check Status  : $0 status"
    echo "  View Logs     : $0 log (add params like -n 50)"
    echo "  Show QR Codes: $0 qr"
    echo "  Show Help     : $0 help"
    echo "-----------------------------------------------"
}

show_help_menu() {
    echo "AnyTLS-Go Server Management Script"
    echo "Usage: $0 [command]"
    echo ""
    echo "Available commands:"
    printf "  %-12s %s\n" "install" "Install/update AnyTLS-Go service (requires sudo)"
    printf "  %-12s %s\n" "uninstall" "Uninstall AnyTLS-Go service (requires sudo)"
    printf "  %-12s %s\n" "start" "Start AnyTLS service (requires sudo)"
    printf "  %-12s %s\n" "stop" "Stop AnyTLS service (requires sudo)"
    printf "  %-12s %s\n" "restart" "Restart AnyTLS service (requires sudo)"
    printf "  %-12s %s\n" "status" "Check service status"
    printf "  %-12s %s\n" "log" "View service logs in real-time (e.g., $0 log -n 100)"
    printf "  %-12s %s\n" "qr" "Regenerate and show configuration QR codes (requires password)"
    printf "  %-12s %s\n" "help" "Show this help menu"
    echo ""
    echo "Example: sudo $0 install"
}


# --- Main Program Entry ---
main() {
    ACTION="$1"
    shift # Remove the first argument, so log can take its own args like -n 50

    case "$ACTION" in
        install) do_install ;;
        uninstall) do_uninstall ;;
        start) start_service ;;
        stop) stop_service ;;
        restart) restart_service ;;
        status) status_service ;;
        log) log_service "$@" ;; # Pass remaining arguments to log_service
        qr) show_qr_codes_interactive ;;
        "" | "-h" | "--help" | "help") show_help_menu ;;
        *)
            echo "Error: Invalid command '$ACTION'" >&2
            show_help_menu
            exit 1
            ;;
    esac
}

# Execute main function with all command-line arguments
main "$@"