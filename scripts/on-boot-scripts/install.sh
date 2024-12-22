#!/usr/bin/env sh

##
# This script installs an on-boot mechanism for the UniFi Dream Machine Pro Max ONLY.
# It creates a systemd unit ("udm-boot.service") that runs any files in ${DATA_DIR}/on_boot.d
# at every system boot. No CNI plugins or bridging scripts are installed.
##

# --- Determine persistent storage directory based on firmware ---
DATA_DIR="/data"
case "$(ubnt-device-info firmware || true)" in
1*)
    DATA_DIR="/mnt/data"
    ;;
2* | 3* | 4*)
    DATA_DIR="/data"
    ;;
*)
    echo "ERROR: No persistent storage found." 1>&2
    exit 1
    ;;
esac

SYSTEMCTL_PATH="/etc/systemd/system/udm-boot.service"
SYMLINK_SYSTEMCTL="/etc/systemd/system/multi-user.target.wants/udm-boot.service"

# ------------------------------
#   Helper Functions
# ------------------------------

header() {
    cat <<EOF
  _   _ ___  __  __   ___           _
 | | | |   \\|  \\/  | | _ ) ___  ___| |_
 | |_| | |) | |\\/| | | _ \\/ _ \\/ _ \\  _|
  \\___/|___/|_|  |_| |___/\\___/\\___/\\__|

UDM Pro Max ONLY On-Boot Installation

EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

depends_on() {
    ! command_exists "$1" && {
        echo "Missing required command: $1" 1>&2
        exit 1
    }
}

check_udm_pro_max() {
    local model
    model="$(ubnt-device-info model || true)"
    if [ "$model" != "UniFi Dream Machine Pro Max" ]; then
        echo "Unsupported device: '$model'. This script ONLY supports UniFi Dream Machine Pro Max." 1>&2
        exit 1
    fi
}

# Generate the systemd unit file
on_boot_systemd_service() {
    cat <<EOF
[Unit]
Description=Run On Startup UDM Pro Max
Wants=network-online.target
After=network-online.target

[Service]
Type=forking
ExecStart=/bin/sh -c 'mkdir -p ${DATA_DIR}/on_boot.d && \
  find -L ${DATA_DIR}/on_boot.d -mindepth 1 -maxdepth 1 -type f -print0 | sort -z | \
  xargs -0 -r -n 1 -- /bin/sh -c "\
    if [ -x \"\\\$0\" ]; then \
      echo \"%n: running \\\$0\"; \
      \"\\\$0\"; \
    else \
      case \"\\\$0\" in \
        *.sh) \
          echo \"%n: sourcing \\\$0\"; \
          . \"\\\$0\"; \
          ;; \
        *) \
          echo \"%n: ignoring \\\$0\"; \
          ;; \
      esac; \
    fi"'

[Install]
WantedBy=multi-user.target
EOF
}

# Install systemd service on the host
install_on_boot_service() {
    echo "Disabling any existing udm-boot service (if present)..."
    systemctl disable udm-boot >/dev/null 2>&1 || true
    systemctl daemon-reload

    echo "Removing old symlink if present..."
    rm -f "$SYMLINK_SYSTEMCTL"

    echo "Creating new systemd service file..."
    on_boot_systemd_service >"$SYSTEMCTL_PATH" || return 1

    echo "Enabling and starting udm-boot..."
    systemctl daemon-reload
    systemctl enable udm-boot
    systemctl start udm-boot
}

# ------------------------------
#        Main Script
# ------------------------------

header

# Require certain commands to exist
depends_on ubnt-device-info
depends_on systemctl

# Check that we're on the UDM Pro Max
check_udm_pro_max

# Install the on-boot systemd service
if install_on_boot_service; then
    echo
    echo "UDM Pro Max on-boot service installed successfully."
    echo "Place your scripts in \"${DATA_DIR}/on_boot.d\" and they will run at boot."
    echo
else
    echo "Failed to install on-boot script service." 1>&2
    exit 1
fi
