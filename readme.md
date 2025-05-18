# AnyTLS-Go Server Management Script (v0.0.8)

A one-click shell script to install, update, manage, and uninstall the [anytls-go](https://github.com/anytls/anytls-go) server on Linux.

## ✅ Features

* **One-click install/update** of AnyTLS-Go server (version `v0.0.8`)
* **Automatic dependency handling** for tools like `wget`, `unzip`, `curl`, `qrencode`
* **Systemd service integration**

  * Enable auto-start on boot
  * Control start/stop/restart via `systemctl`
  * View status and logs easily
* **Interactive setup**: Guided configuration for port and password
* **QR code generation**: Auto-create AnyTLS config QR codes for **NekoBox** and **Shadowrocket**
* **Safe uninstall**: Removes the binary and systemd service file
* **Architecture detection**: Supports `amd64` (x86\_64) and `arm64` (aarch64)

## 📋 Requirements

* A Linux VPS (recommended: Debian, Ubuntu, CentOS, etc.)
* `sudo` or `root` privileges
* Internet connection for downloading dependencies and binaries

## 🚀 Usage

### 1. Download the script

```bash
wget -O anytls_manager.sh https://raw.githubusercontent.com/tianrking/AnyTLS-Go/refs/heads/main/anytls_manager.sh
```

Or with curl:

```bash
curl -o anytls_manager.sh -L https://raw.githubusercontent.com/tianrking/AnyTLS-Go/refs/heads/main/anytls_manager.sh
```

### 2. Make it executable

```bash
chmod +x anytls_manager.sh
```

### 3. Run the script

#### Show help:

```bash
./anytls_manager.sh help
```

#### Install or update AnyTLS-Go:

```bash
sudo ./anytls_manager.sh install
```

You’ll be prompted to set a port and password.

#### Uninstall AnyTLS-Go:

```bash
sudo ./anytls_manager.sh uninstall
```

#### Start/Stop/Restart the service:

```bash
sudo ./anytls_manager.sh start
sudo ./anytls_manager.sh stop
sudo ./anytls_manager.sh restart
```

#### Check status:

```bash
./anytls_manager.sh status
```

#### View logs:

```bash
./anytls_manager.sh log
# View the last 100 lines:
./anytls_manager.sh log -n 100
```

#### Regenerate QR code:

```bash
./anytls_manager.sh qr
```

You’ll be asked for the previously set password.

## 📱 Supported Clients

The following clients are known to support the AnyTLS protocol and can be used with this script:

* **Shadowrocket (iOS)**
  Version 2.2.65 or newer
  QR code supported
* **NekoBox for Android**
  Version 1.3.8 or newer
  QR code supported
* **sing-box (multi-platform)**
  Can be manually configured
  → GitHub: [SagerNet/sing-box](https://github.com/SagerNet/sing-box)
* **mihomo (Clash Meta core, multi-platform)**
  Manual configuration supported
  → GitHub: [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)

> ⚠️ Since AnyTLS-Go uses a self-signed certificate, most clients will require enabling “Allow Insecure” or “Skip Certificate Verification”.