# IPFS Manager CLI (kubo)

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://raw.githubusercontent.com/AndyDevla/ipfs-auto-installer/main/ipfs-auto-installer.sh)

**IPFS Manager CLI** is a modular ecosystem of scripts designed to automate the full lifecycle of an IPFS (Kubo) node. It transforms a simple binary installation into a solid-grade suite capable of managing SSL Gateways, remote RPC access, and repository maintenance through an intuitive command-line interface.

## 📂 Project Structure

The suite is organized into functional modules to ensure a clean and scalable architecture:

```text
ipfs-manager
├── cli
│   └── ipfs-cli.sh            # Management console (MFS, Swarm, CLI)
├── gateway
│   ├── caddy-installer.sh     # Caddy Server setup
│   ├── disable.sh             # Revert Gateway/RPC to factory defaults
│   ├── path+RPC.sh            # Combined SSL Gateway & API setup
│   ├── path.sh                # Path-based Gateway SSL setup
│   └── RPC.sh                 # Remote API & WebUI SSL setup
├── installer
│   └── ipfs-installer.sh      # Binary installation & architecture detection
├── main.sh                    # Main entry point & menu system
├── node
│   └── daemon.sh              # Daemon configuration & systemd service setup
├── repo
│   └── init.sh                # Repository initialization and tuning
├── status
│   └── services.sh            # Service monitoring and status overview
└── uninstaller
    ├── uninstaller-caddy.sh   # Caddy removal tool
    └── uninstaller-ipfs.sh    # IPFS/Kubo removal tool
```

## ✨ Key Features

  - **Path Gateway:** Configure a gateway path to serve IPFS content over a secure HTTPS connection. The suite automates the reverse proxy setup via Caddy, ensuring your content is accessible through a standard web browser with  SSL encryption.
  - **Hybrid Connection Management:** Switch between direct local connections, localhost RPC, or remote RPC(**https://webui.ipfs.io**) via custom domains with ease.
  - **Automated SSL/TLS:** Full integration with **Caddy Server** for automatic HTTPS certificates on your Gateway and API endpoints.
  - **Smart Maintenance:** Includes a Garbage Collector (GC) toggle to prevent disk storage from reaching its limit.
  - **Fail-Safe Reversion:** The "Disable" sub-option allows you to reset `.config` and `Caddyfile` network settings to their original state in one click.
  - **Best-Effort Multi-Init Support:** While primarily designed to work with **systemd**, the suite includes logic to detect and support other init systems.

## 🚀 Installation & Usage

### One-Liner Shell Command

Download the repository and automatically run ```main.sh```

```bash
curl -sSL https://github.com/AndyDevla/ipfs-manager-cli/archive/refs/heads/main.tar.gz | tar xz && cd ipfs-manager-cli-main && chmod +x main.sh && ./main.sh
```

### Online Execution (Alpha)

Run an **standalone** version of **ipfs-manager-cli** directly from GitHub without manual cloning:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/AndyDevla/ipfs-manager-cli/refs/heads/main/main.sh)
```
#### or try
```bash
bash <(curl -sSL https://raw.githubusercontent.com/AndyDevla/ipfs-manager-cli/refs/heads/main/main.sh)
```

### Local Setup

Clone the repository for persistent access and development:

```bash
git clone https://github.com/AndyDevla/ipfs-manager-cli.git
cd ipfs-manager-cli
chmod +x main.sh
./main.sh
```

## 🛠 Requirements

  - **OS:** Linux (Debian/Ubuntu highly recommended).
  - **Dependencies:** `curl`, `jq`.
  - **Privileges:** The script will prompt for `sudo` only when executing system-level changes (service management or binary installations).

## 📋 Suggested Workflow
0.  **Connection:** To interact with the IPFS node choose between a local installation(1), remote RPC(3) or local RPC(2) methods.
1.  **Setup:** Use option 1 and 2 to install the binary and initialize your repository.
2.  **Launch:** Use option 3 to configure the daemon (enable GC and systemd autostart).
3.  **Expose:** Use option 4 to link your domain and enable SSL via Caddy.
4.  **Manage:** Use option 6 to interact with the MFS (Mutable File System) or check network peers.

## ⚖️ License

This project is licensed under the **GNU General Public License v3.0**. You are free to copy, modify, and distribute this software as long as the same license is maintained.

-----

Developed by [AndyDevla](https://github.com/AndyDevla) 🚀
