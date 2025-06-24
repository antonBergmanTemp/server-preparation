#!/bin/bash

# Preliminary server setup script for Ubuntu 24.04
# Configures SSH with RSA-ED key, user-selected or random SSH port, UFW, Fail2ban, and disables IPv6

echo "Starting preliminary server setup for Ubuntu 24.04..."

# Step 0: Update and install essential packages
apt update && apt upgrade -y
apt install -y curl wget nano

# Step 1: Menu for setup confirmation
echo "=== Server Setup Menu ==="
echo "This script will configure SSH, UFW, Fail2ban, and disable IPv6."
read -p "Proceed with setup? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Setup aborted."
    exit 1
fi

# Step 2: Choose SSH port or generate random
while true; do
    read -p "Enter SSH port (1024-65535, press Enter for random): " ssh_port
    if [[ -z "$ssh_port" ]]; then
        # Generate random port between 1024 and 65535
        ssh_port=$((RANDOM % (65535 - 1024 + 1) + 1024))
        echo "No port provided. Generated random SSH port: $ssh_port"
        break
    elif [[ "$ssh_port" =~ ^[0-9]+$ && "$ssh_port" -ge 1024 && "$ssh_port" -le 65535 ]]; then
        break
    else
        echo "Invalid port. Please enter a number between 1024 and 65535."
    fi
done

# Step 3: Input RSA-ED public key and disable password authentication
read -p "Paste your RSA-ED (Ed25519) public key: " ssh_key
if [[ -z "$ssh_key" ]]; then
    echo "Error: No public key provided. Exiting."
    exit 1
fi

# Create .ssh directory and authorized_keys file
mkdir -p /root/.ssh
echo "$ssh_key" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh

# Update SSH configuration to replace default port (22)
sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
sed -i "s/Port 22/Port $ssh_port/" /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH configured with port $ssh_port and public key authentication."

# Step 4: Install and configure UFW
apt install -y ufw
ufw allow "$ssh_port"/tcp
ufw --force enable
echo "UFW enabled with SSH port $ssh_port allowed."

# Step 5: Install and configure Fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Create Fail2ban SSH jail configuration
cat << EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = $ssh_port
maxretry = 3
findtime = 600
bantime = 3600
EOF

systemctl restart fail2ban
echo "Fail2ban configured for SSH on port $ssh_port."

# Step 6: Disable IPv6
cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl -p
echo "IPv6 disabled."

# Step 7: Completion prompt
echo "=== Setup Complete ==="
echo "Server is now configured with:"
echo "- Updated packages"
echo "- SSH on port $ssh_port with RSA-ED key authentication"
echo "- UFW enabled"
echo "- Fail2ban protecting SSH"
echo "- IPv6 disabled"
echo "You can now proceed with Zapret and Marzban installation."