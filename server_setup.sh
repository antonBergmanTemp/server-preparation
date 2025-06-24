#!/bin/bash

# Preliminary server setup script for Ubuntu 24.04
# Configures SSH with RSA-ED key, user-selected or random SSH port, UFW, Fail2ban, and disables IPv6

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display progress bar
show_progress() {
    local msg=$1
    local duration=$2
    echo -n "$msg ["
    for ((i=0; i<10; i++)); do
        echo -n "="
        sleep "$duration"
    done
    echo "] Done"
}

clear
echo "============================================================="
echo "          🚀 Server Setup Wizard for Ubuntu 24.04 🚀          "
echo "============================================================="
echo "This script will configure:"
echo "  - System updates"
echo "  - SSH with custom/random port and RSA-ED key"
echo "  - UFW firewall"
echo "  - Fail2ban for SSH protection"
echo "  - Disable IPv6"
echo "============================================================="

# Step 1: Menu for setup confirmation
read -p "Proceed with setup? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Setup aborted."
    exit 1
fi

# Step 2: Update and install essential packages
echo "Updating system packages..."
show_progress "Installing updates" 0.3
apt update &>/dev/null && apt upgrade -y &>/dev/null
apt install -y curl wget nano &>/dev/null

# Step 3: Choose SSH port or generate random
while true; do
    echo "============================================================="
    echo "Enter SSH port (1024-65535, press Enter for random)"
    read -p "Port: " ssh_port
    if [[ -z "$ssh_port" ]]; then
        # Generate random port between 1024 and 65535
        ssh_port=$((RANDOM % (65535 - 1024 + 1) + 1024))
        echo "Generated random SSH port: $ssh_port"
        break
    elif [[ "$ssh_port" =~ ^[0-9]+$ && "$ssh_port" -ge 1024 && "$ssh_port" -le 65535 ]]; then
        break
    else
        echo "Invalid port. Please enter a number between 1024 and 65535."
    fi
done

# Step 4: Input RSA-ED public key and disable password authentication
echo "============================================================="
read -p "Paste your RSA-ED (Ed25519) public key: " ssh_key
if [[ -z "$ssh_key" ]]; then
    echo "Error: No public key provided. Exiting."
    exit 1
fi

echo "Configuring SSH..."
show_progress "Setting up SSH" 0.2
mkdir -p /root/.ssh &>/dev/null
echo "$ssh_key" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys &>/dev/null
chmod 700 /root/.ssh &>/dev/null

# Update SSH configuration to replace default port (22)
sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config &>/dev/null
sed -i "s/Port 22/Port $ssh_port/" /etc/ssh/sshd_config &>/dev/null
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config &>/dev/null
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config &>/dev/null
systemctl daemon-reload &>/dev/null
systemctl restart ssh.socket &>/dev/null

# Step 5: Install and configure UFW
echo "Configuring UFW firewall..."
show_progress "Setting up UFW" 0.2
apt install -y ufw &>/dev/null
ufw allow "$ssh_port"/tcp &>/dev/null
ufw --force enable &>/dev/null

# Step 6: Install and configure Fail2ban
echo "Configuring Fail2ban..."
show_progress "Setting up Fail2ban" 0.2
apt install -y fail2ban &>/dev/null
systemctl enable fail2ban &>/dev/null
systemctl start fail2ban &>/dev/null

# Create Fail2ban SSH jail configuration
cat << EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = $ssh_port
maxretry = 3
findtime = 600
bantime = 3600
EOF
systemctl restart fail2ban &>/dev/null

# Step 7: Disable IPv6
echo "Disabling IPv6..."
show_progress "Disabling IPv6" 0.2
cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p &>/dev/null

# Step 8: Completion prompt
clear
echo -e "${GREEN}=============================================================${NC}"
echo -e "${GREEN}                🎉 Setup Complete 🎉${NC}"
echo -e "${GREEN}=============================================================${NC}"
echo -e "${GREEN}Server is now configured with:${NC}"
echo -e "${GREEN}- Updated packages${NC}"
echo -e "${GREEN}- SSH on port $ssh_port with RSA-ED key authentication${NC}"
echo -e "${GREEN}- UFW enabled${NC}"
echo -e "${GREEN}- Fail2ban protecting SSH${NC}"
echo -e "${GREEN}- IPv6 disabled${NC}"
echo -e "${GREEN}You can now proceed with Zapret and Marzban installation.${NC}"
echo -e "${GREEN}=============================================================${NC}"