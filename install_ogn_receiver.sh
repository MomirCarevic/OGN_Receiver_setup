#!/bin/bash

# OGN Receiver Installation Script for Raspberry Pi
# This script automates the installation and configuration of an OGN receiver

set -e  # Exit on error

echo "================================"
echo "OGN Receiver Installation Script"
echo "================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root (without sudo). It will request sudo when needed."
    exit 1
fi

# Step 1: Expand filesystem (requires manual intervention via raspi-config)
print_info "Step 1: Filesystem Expansion"
print_warning "You need to manually expand the filesystem using: sudo raspi-config"
print_warning "Navigate to: 7 Advanced Options -> A1 Expand Filesystem"
print_warning "After expanding, the system will reboot."
read -p "Press Enter if you have already expanded the filesystem, or Ctrl+C to exit and do it now..."

# Step 2: Check network connectivity
print_info "Step 2: Checking network connectivity..."
if ping -c 3 8.8.8.8 &> /dev/null; then
    print_info "Network connectivity confirmed"
else
    print_error "No network connectivity. Please check your internet connection."
    exit 1
fi

# Step 3: Update system
print_info "Step 3: Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Step 4: Install RTL-SDR
print_info "Step 4: Installing RTL-SDR..."
sudo apt-get install -y rtl-sdr

# Step 5: Install required packages
print_info "Step 5: Installing required packages..."
sudo apt-get install -y libfftw3-dev lynx openntpd ntpsec-ntpdate
sudo apt-get install -y libconfig-dev
sudo apt-get install -y libconfig11 libconfig++11 libjpeg-dev ntpsec-ntpdate

# Step 6: Install JPEG library
print_info "Step 6: Installing JPEG library from source..."
cd /tmp
wget -qO- http://www.ijg.org/files/jpegsrc.v8d.tar.gz | tar -xz
cd jpeg-8d/
./configure --libdir=/usr/lib/ --build=aarch64-unknown-linux-gnu
make && sudo make install
cd ..
rm -fr jpeg-8d/

# Step 7: Download OGN software
print_info "Step 7: Downloading OGN receiver software..."
cd ~

if wget http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz; then
    tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz
    rm rtlsdr-ogn-bin-RPI-GPU-latest.tgz
    echo -e "\nDownalod of binary for RPi successful!\n"
fi

# Step 8: Configure OGN software
print_info "Step 8: Configuring OGN receiver..."
cd rtlsdr-ogn
mkfifo ogn-rf.fifo 2>/dev/null || print_warning "FIFO already exists"
sudo chown root gsm_scan
sudo chmod a+s gsm_scan
sudo chown root ogn-rf
sudo chmod a+s ogn-rf

# Step 9: Run GSM scan for frequency calibration
print_info "Step 9: Running GSM scan for frequency calibration..."
print_warning "This will scan for GSM signals to calibrate the receiver."
print_warning "The scan will run for a short time. Press Ctrl+C when you see stable results."
read -p "Press Enter to start GSM scan..."
./gsm_scan --ppm 50 --gain 20 || true

# Step 10: Configuration file setup
print_info "Step 10: Setting up configuration file..."
cd ~/rtlsdr-ogn
./autoMakeMyPlace.sh

# Source the autoMakeMyPlace script to create config and export the filename
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#source "$SCRIPT_DIR/autoMakeMyPlace.sh"

# Step 11: Install procserv and telnet
print_info "Step 11: Installing procserv and telnet..."
sudo apt-get install -y procserv telnet

# Step 12: Install OGN service
print_info "Step 12: Installing OGN system service..."
sudo wget -q http://download.glidernet.org/common/service/rtlsdr-ogn -O /etc/init.d/rtlsdr-ogn
sudo wget -q http://download.glidernet.org/common/service/rtlsdr-ogn.conf -O /etc/rtlsdr-ogn.conf
sudo chmod +x /etc/init.d/rtlsdr-ogn
sudo update-rc.d rtlsdr-ogn defaults

# Step 13: Configure service
# Get current directory and username
OGN_DIR=$(pwd)
CURRENT_USER=$(whoami)

print_info "Current directory: $OGN_DIR"
print_info "Current user: $CURRENT_USER"

# Check if config file exists
if [ ! -f "/etc/rtlsdr-ogn.conf" ]; then
    print_error "/etc/rtlsdr-ogn.conf not found!"
    exit 1
fi

# Backup the original config file
print_info "Creating backup of /etc/rtlsdr-ogn.conf..."
sudo cp /etc/rtlsdr-ogn.conf /etc/rtlsdr-ogn.conf.backup.$(date +%Y%m%d_%H%M%S)

# Replace PWD and username in the config file
print_info "Updating configuration file..."

cat > /etc/rtlsdr-ogn.conf << EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  $USER /home/$USER/rtlsdr-ogn    ./ogn-rf     ${OGN_CONFIG_FILE.conf}
50001  $USER /home/$USER/rtlsdr-ogn    ./ogn-decode ${OGN_CONFIG_FILE.conf}
EOF

echo "Configuration updated successfully for user: $USER"

# Verify the changes
print_info "Configuration updated successfully!"

# Ask if user wants to manually review/edit
read -p "Configuration has been updated. Edit manually? (y/n): " manual_edit
if [[ "$manual_edit" =~ ^[Yy]$ ]]; then
    sudo vim /etc/rtlsdr-ogn.conf
fi

# Step 14: Start service
print_info "Step 14: Starting OGN receiver service..."
read -p "Do you want to start the OGN service now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo service rtlsdr-ogn start
    print_info "OGN service started!"
    sleep 2
    print_info "Checking service status..."
    sudo service rtlsdr-ogn status || true
else
    print_warning "Service not started. Start it manually with: sudo service rtlsdr-ogn start"
fi

echo ""
print_info "================================"
print_info "Installation Complete!"
print_info "================================"
print_info "Next steps:"
print_info "1. Verify your configuration in: ~/rtlsdr-ogn/${OGN_CONFIG_FILE.conf}"
print_info "2. Verify service configuration in: /etc/rtlsdr-ogn.conf"
print_info "3. Start the service with: sudo service rtlsdr-ogn start"
print_info "4. Check logs with: sudo service rtlsdr-ogn status"
print_info "5. Connect via telnet: telnet localhost 50000"
print_info ""
print_info "Your OGN receiver installation directory: $OGN_DIR"
