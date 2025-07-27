#!/bin/bash

# Exit on any error
set -e

# Ensure script is run with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)." >&2
    exit 1
fi

# Log file for tracking updates
LOG_FILE="/var/log/system-update-$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Redirect all output to log file and stdout
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Check if apt is available
if ! command -v apt-get >/dev/null 2>&1; then
    log_message "Error: apt-get is not available. This script requires a Debian/Ubuntu-based system."
    exit 1
fi

# Check if pip is available
if ! command -v pip3 >/dev/null 2>&1; then
    log_message "Warning: pip3 is not installed. Skipping Python package updates."
    PIP_AVAILABLE=false
else
    PIP_AVAILABLE=true
fi

log_message "Starting system and package update process..."

# Update package lists
log_message "Updating package lists..."
if ! apt-get update; then
    log_message "Error: Failed to update package lists."
    exit 1
fi

# Upgrade installed packages
log_message "Upgrading installed packages..."
if ! apt-get upgrade -y; then
    log_message "Error: Failed to upgrade packages."
    exit 1
fi

# Perform full upgrade (including kernel and distro upgrades)
log_message "Performing full system upgrade..."
if ! apt-get dist-upgrade -y; then
    log_message "Error: Failed to perform full upgrade."
    exit 1
fi

# Update Python packages if pip is available
if [ "$PIP_AVAILABLE" = true ]; then
    log_message "Checking for outdated Python packages..."
    # Get outdated packages, excluding header lines, and update them
    outdated_packages=$(pip3 list --outdated --format=freeze 2>/dev/null | awk -F'==' '{print $1}' | grep -v '^$')
    
    if [ -n "$outdated_packages" ]; then
        log_message "Updating Python packages: $outdated_packages"
        # Update each package individually to handle failures gracefully
        while IFS= read -r package; do
            log_message "Updating Python package: $package..."
            if ! pip3 install --upgrade "$package"; then
                log_message "Warning: Failed to update Python package: $package"
            fi
        done <<< "$outdated_packages"
    else
        log_message "No outdated Python packages found."
    fi
else
    log_message "Skipping Python package updates (pip3 not available)."
fi

# Remove unneeded packages
log_message "Removing unneeded packages..."
if ! apt-get autoremove -y; then
    log_message "Warning: Failed to remove unneeded packages."
fi

# Clean package cache
log_message "Cleaning package cache..."
if ! apt-get clean; then
    log_message "Warning: Failed to clean package cache."
fi

log_message "System update process completed successfully!"
log_message "Log file saved at: $LOG_FILE"

exit 0
