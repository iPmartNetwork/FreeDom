#!/bin/bash

# Freedom v1.0.1 Beta
# -----------------------------------------------------------------------------
# Description: This script automates the setup and configuration of various
#              utilities and services on a Linux server for a secure and
#              optimized environment, with a focus on enhancing internet
#              freedom and privacy in Iran.
#
#
# Disclaimer: This script is provided for educational and informational
#             purposes only. Use it responsibly and in compliance with all
#             applicable laws and regulations.
#
# Note: Make sure to review and understand each section of the script before
#       running it on your system. Some configurations may require manual
#       adjustments based on your specific needs and server setup.
# -----------------------------------------------------------------------------

# Check for sudo privileges
if [[ $EUID -ne 0 ]]; then
  if [[ $(sudo -n true 2>/dev/null) ]]; then
    echo "This script will be run with sudo privileges."
  else
    echo "This script must be run with sudo privileges."
    exit 1
  fi
fi

# 1. Function to perform system updates and cleanup
system_update() {
  dialog --title "System Update and Cleanup" --yesno "This operation will update your system and remove unnecessary packages. Do you want to proceed?" 10 60
  response=$?
  
  if [ $response -eq 0 ]; then
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean -y
    sudo apt clean -y

    dialog --msgbox "System updates and cleanup completed." 10 60
  else
    dialog --msgbox "System updates and cleanup operation canceled." 10 60
  fi
}

# 2. Function to install essential packages
install_essential_packages() {
  dialog --title "Install Essential Packages" --yesno "This operation will install essential packages like certbot,net-tools,zip and xclip. Do you want to proceed?" 10 60
  response=$?

  if [ $response -eq 0 ]; then
    packages=("curl" "nano" "certbot" "cron" "ufw" "htop" "net-tools" "zip" "unzip" "xclip")

    package_installed() {
      dpkg -l | grep -q "^ii  $1"
    }

    for pkg in "${packages[@]}"; do
      if ! package_installed "$pkg"; then
        sudo apt install -y "$pkg"
      fi
    done

    dialog --msgbox "Essential packages have been installed." 10 60
  else
    dialog --msgbox "Installation of essential packages canceled." 10 60
  fi
}

# 3. Function to install Speedtest
install_speedtest() {
  dialog --title "Install Speedtest" --yesno "Do you want to install Speedtest?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    dialog --infobox "Installing Speedtest. Please wait..." 10 60
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    sudo apt-get -y install speedtest
    dialog --msgbox "Speedtest has been installed successfully. You can now run it by entering 'speedtest' in the terminal." 10 60
  else
    dialog --msgbox "Skipping installation of Speedtest." 10 60
  fi
}

# 4. Function to create a SWAP file
create_swap_file() {
  dialog --title "Create SWAP File" --yesno "Do you want to create a SWAP file?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    if [ -f /swapfile ]; then
      dialog --title "Swap File" --msgbox "A SWAP file already exists. Skipping swap file creation." 10 60
    else
      dialog --title "Swap File" --inputbox "Enter the size of the SWAP file (e.g., 2G for 2 gigabytes):" 10 60 2> swap_size.txt
      swap_size=$(cat swap_size.txt)

      if [[ "$swap_size" =~ ^[0-9]+[GgMm]$ ]]; then
        dialog --infobox "Creating SWAP file. Please wait..." 10 60
        sudo fallocate -l "$swap_size" /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
        echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
        dialog --msgbox "SWAP file created successfully with a size of $swap_size." 10 60
      else
        dialog --msgbox "Invalid SWAP file size. Please provide a valid size (e.g., 2G for 2 gigabytes)." 10 60
      fi
    fi
  else
    dialog --msgbox "Skipping SWAP file creation." 10 60
  fi
}

# 5. Function to enable BBR
enable_bbr() {
  dialog --title "Enable BBR" --yesno "Do you want to enable BBR congestion control?\n\nEnabling BBR while Hybla is enabled can lead to conflicts. Are you sure you want to proceed?" 12 60
  response=$?
  if [ $response -eq 0 ]; then
    # Add BBR settings to sysctl.conf
    echo "net.core.default_qdisc = fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" | sudo tee -a /etc/sysctl.conf
    
    # Apply the new settings
    sudo sysctl -p

    dialog --msgbox "BBR congestion control has been enabled successfully." 10 60
  else
    dialog --msgbox "BBR configuration skipped." 10 60
  fi
}

# 6. Function to enable Hybla
enable_hybla() {
  dialog --title "Enable Hybla" --yesno "Do you want to enable Hybla congestion control?\n\nEnabling Hybla while BBR is enabled can lead to conflicts. Are you sure you want to proceed?" 12 60
  response=$?
  if [ $response -eq 0 ]; then
    # Add lines to /etc/security/limits.conf
    echo "* soft nofile 51200" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 51200" | sudo tee -a /etc/security/limits.conf

    # Run ulimit command
    ulimit -n 51200

    # Add lines to /etc/ufw/sysctl.conf
    sysctl_settings=(
      "fs.file-max = 51200"
      "net.core.rmem_max = 67108864"
      "net.core.wmem_max = 67108864"
      "net.core.netdev_max_backlog = 250000"
      "net.core.somaxconn = 4096"
      "net.ipv4.tcp_syncookies = 1"
      "net.ipv4.tcp_tw_reuse = 1"
      "net.ipv4.tcp_tw_recycle = 0"
      "net.ipv4.tcp_fin_timeout = 30"
      "net.ipv4.tcp_keepalive_time = 1200"
      "net.ipv4.ip_local_port_range = 10000 65000"
      "net.ipv4.tcp_max_syn_backlog = 8192"
      "net.ipv4.tcp_max_tw_buckets = 5000"
      "net.ipv4.tcp_fastopen = 3"
      "net.ipv4.tcp_mem = 25600 51200 102400"
      "net.ipv4.tcp_rmem = 4096 87380 67108864"
      "net.ipv4.tcp_wmem = 4096 65536 67108864"
      "net.ipv4.tcp_mtu_probing = 1"
      "net.ipv4.tcp_congestion_control = hybla"
    )

    for setting in "${sysctl_settings[@]}"; do
      echo "$setting" | sudo tee -a /etc/ufw/sysctl.conf
    done

    dialog --msgbox "Hybla congestion control has been enabled successfully." 10 60
  else
    dialog --msgbox "Hybla configuration skipped." 10 60
  fi
}

# 7. Function to enable and configure Cron
enable_and_configure_cron() {
  # Prompt for automatic updates
  dialog --title "Enable Automatic Updates" --yesno "Would you like to enable automatic updates? This will schedule system updates every night at 00:30 +3:30 GMT." 10 60
  update_response=$?

  # Prompt for scheduling system restarts
  dialog --title "Schedule System Restarts" --yesno "Would you like to schedule system restarts? This will schedule system restarts every night at 01:30 +3:30 GMT." 10 60
  restart_response=$?

  if [ $update_response -eq 0 ]; then
    # Configure automatic updates using Cron
    echo "00 22 * * * /usr/bin/apt-get update && /usr/bin/apt-get upgrade -y && /usr/bin/apt-get autoremove -y && /usr/bin/apt-get autoclean -y && /usr/bin/apt-get clean -y" | sudo tee -a /etc/crontab
    updates_message="Automatic updates have been enabled and scheduled."

    if [ $restart_response -eq 0 ]; then
      # Schedule system restarts using Cron
      echo "30 22 * * * /sbin/shutdown -r" | sudo tee -a /etc/crontab
      restarts_message="System restarts have been scheduled."
    else
      restarts_message="System restart scheduling skipped."
    fi

    # Display appropriate messages based on user choices
    dialog --msgbox "$updates_message\n$restarts_message" 10 60
  else
    if [ $restart_response -eq 0 ]; then
      # Schedule system restarts without automatic updates
      echo "30 22 * * * /sbin/shutdown -r" | sudo tee -a /etc/crontab
      dialog --msgbox "System restarts have been scheduled without automatic updates." 10 60
    else
      dialog --msgbox "Cron configuration skipped." 10 60
    fi
  fi
}

# 8. Function to Install Multiprotocol VPN Panel
install_vpn_panel() {
  dialog --title "Install Multiprotocol VPN Panel" --menu "Select a VPN Panel to Install:" 15 60 8 \
    "1" "X-UI | Alireza" \
    "2" "X-UI | MHSanaei" \
    "3" "X-UI | vaxilu" \
    "4" "X-UI | FranzKafkaYu" \
    "5" "X-UI En | FranzKafkaYu" \
    "6" "reality-ezpz | aleskxyz" \
    "7" "Hiddify" \
    "8" "Marzban | Gozargah" 2> vpn_choice.txt
     
  vpn_choice=$(cat vpn_choice.txt)

  case $vpn_choice in
    "1")
      bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
      ;;
    "2")
      bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
      ;;
    "3")
      bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
      ;;
    "4")
      bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
      ;;
    "5")
      bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install_en.sh)
      ;;
    "6")
      bash <(curl -sL https://raw.githubusercontent.com/aleskxyz/reality-ezpz/master/reality-ezpz.sh)
      ;;
    "7")
      bash -c "$(curl -Lfo- https://raw.githubusercontent.com/hiddify/hiddify-config/main/common/download_install.sh)"
      ;;
    "8")
      sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
      marzban cli admin create --sudo
      ;;
    *)
      dialog --msgbox "Invalid choice. No VPN Panel installed." 10 40
      return
      ;;
  esac

  # Wait for the user to press Enter
  read -p "Please press Enter to continue."

  # Return to the menu
}

# 9. Function to obtain SSL certificates
obtain_ssl_certificates() {
  apt install -y certbot
  dialog --title "Obtain SSL Certificates" --yesno "Do you want to Get SSL Certificates?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    dialog --title "SSL Certificate Information" --inputbox "Enter your email:" 10 60 2> email.txt
    email=$(cat email.txt)
    dialog --title "SSL Certificate Information" --inputbox "Enter your domain (e.g., sub.domain.com):" 10 60 2> domain.txt
    domain=$(cat domain.txt)

    if [ -n "$email" ] && [ -n "$domain" ]; then
      sudo certbot certonly --standalone --preferred-challenges http --agree-tos --email "$email" -d "$domain"

      # Wait for the user to press Enter
      read -p "Please Press Enter to continue"

      dialog --msgbox "SSL certificates obtained successfully for $domain in /etc/letsencrypt/live." 10 60
    else
      dialog --msgbox "Both email and domain are required to obtain SSL certificates." 10 60
    fi
  else
    dialog --msgbox "Skipping SSL certificate acquisition." 10 40
  fi

  # Return to the menu
}

# 10. Function to set up Pi-Hole
setup_pi_hole() {
  # Provide information about Pi-Hole and its benefits
  dialog --title "Install Pi-Hole" --yesno "Pi-Hole is a network-wide ad blocker that can improve your online experience by blocking ads at the network level. Do you want to install Pi-Hole?" 12 60
  response=$?

  if [ $response -eq 0 ]; then
    # Install Pi-Hole
    curl -sSL https://install.pi-hole.net | bash

    # Ask if the user wants to change the Pi-Hole web interface password
    dialog --title "Change Pi-Hole Web Interface Password" --yesno "Do you want to change the Pi-Hole web interface password?" 10 60
    response=$?
    if [ $response -eq 0 ]; then
      pihole -a -p
      dialog --msgbox "Pi-Hole web interface password changed successfully." 10 60
    else
      dialog --msgbox "Skipping Pi-Hole web interface password change." 10 40
    fi

    # Ask if the user wants to configure Pi-Hole as a DHCP server
    dialog --title "Configure Pi-Hole as a DHCP Server" --yesno "Do you want to configure Pi-Hole as a DHCP server? This can help manage your local network's IP addresses and improve ad blocking. Note: Ensure that your router's DHCP server is disabled." 12 60
    response=$?
    if [ $response -eq 0 ]; then
      # Provide DHCP configuration instructions here
      dialog --title "Pi-Hole DHCP Configuration" --msgbox "To configure Pi-Hole as a DHCP server, go to the Pi-Hole web interface (http://pi.hole/admin) and navigate to 'Settings' > 'DHCP.' Follow the instructions to enable DHCP and specify the IP range for your local network." 12 80
    else
      dialog --msgbox "Skipping Pi-Hole DHCP server configuration." 10 40
    fi

    # Ask if the user wants to change the Lighttpd port
    if [ -f /etc/lighttpd/lighttpd.conf ]; then
      dialog --title "Change Lighttpd Port" --yesno "If you have installed Pi-Hole, then Lighttpd is listening on port 80 by default. Do you want to change the Lighttpd port?" 10 60
      response=$?
      if [ $response -eq 0 ]; then
        sudo nano /etc/lighttpd/lighttpd.conf
        dialog --msgbox "Lighttpd port changed." 10 60
      else
        dialog --msgbox "Skipping Lighttpd port change." 10 40
      fi
    fi
  else
    dialog --msgbox "Skipping Pi-Hole installation." 10 40
  fi
}

# 11. Function to change SSH port
change_ssh_port() {
  # Provide information about changing SSH port
  dialog --title "Change SSH Port" --msgbox "Changing the SSH port can enhance security by reducing automated SSH login attempts. However, it's essential to choose a port that is not already in use and to update your SSH client configuration accordingly.\n\nPlease consider the following:\n- Choose a port number between 1025 and 49151 (unprivileged ports).\n- Avoid well-known ports (e.g., 22, 80, 443).\n- Ensure that the new port is open in your firewall rules.\n- Update your SSH client configuration to use the new port." 14 80

  # Prompt the user for the new SSH port
  dialog --title "Enter New SSH Port" --inputbox "Enter the new SSH port:" 10 60 2> ssh_port.txt
  new_ssh_port=$(cat ssh_port.txt)

  # Verify that a valid port number is provided
  if [[ $new_ssh_port =~ ^[0-9]+$ ]]; then
    # Remove the '#' comment from the 'Port' line in sshd_config (if present)
    sudo sed -i "/^#*Port/s/^#*Port/Port/" /etc/ssh/sshd_config

    # Update SSH port in sshd_config
    sudo sed -i "s/^Port .*/Port $new_ssh_port/" /etc/ssh/sshd_config

    # Reload SSH service to apply changes
    sudo systemctl reload sshd

    dialog --msgbox "SSH port changed to $new_ssh_port. Ensure that you apply related firewall rules and update your SSH client configuration accordingly." 12 60
  else
    dialog --msgbox "Invalid port number. Please provide a valid port." 10 60
  fi
}

# 12. Function to enable UFW
enable_ufw() {
  # Set UFW defaults
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # Prompt the user for the SSH port to allow
  dialog --title "Enable UFW - SSH Port" --inputbox "Enter the SSH port to allow (default is 22):" 10 60 2> ssh_port.txt
  ssh_port=$(cat ssh_port.txt)

  # Check if the SSH port is empty and set it to default (22) if not provided
  if [ -z "$ssh_port" ]; then
    ssh_port=22
  fi

  # Allow SSH port
  sudo ufw allow "$ssh_port/tcp"

  # Prompt the user for additional ports to open
  dialog --title "Enable UFW - Additional Ports" --inputbox "Enter additional ports to open (comma-separated, e.g., 80,443):" 10 60 2> ufw_ports.txt
  ufw_ports=$(cat ufw_ports.txt)

  # Allow additional ports specified by the user
  if [ -n "$ufw_ports" ]; then
    IFS=',' read -ra ports_array <<< "$ufw_ports"
    for port in "${ports_array[@]}"; do
      sudo ufw allow "$port/tcp"
    done
  fi

  # Enable UFW to start at boot
  sudo ufw enable
  sudo systemctl enable ufw

  # Display completion message
  dialog --msgbox "UFW enabled and configured successfully.\nSSH port $ssh_port and additional ports allowed." 12 60
}

# 13. Function to install and configure WARP Proxy
install_configure_warp_proxy() {
  dialog --title "Install & Configure WARP Proxy" --yesno "Do you want to install and configure WARP Proxy?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    bash <(curl -fsSL git.io/warp.sh) proxy
    
    # Wait for the user to press Enter
    read -p "Please Press Enter to continue"
    
    dialog --msgbox "WARP Proxy installed and configured successfully." 10 60
  else
    dialog --msgbox "Skipping installation and configuration of WARP Proxy." 10 60
  fi
}

# 14 Function to set up MTProto Proxy submenu
setup_mtproto_proxy_submenu() {
  local mtproto_choice
  dialog --title "Setup MTProto Proxy" --menu "Choose an MTProto Proxy option:" 15 60 6 \
    1 "Setup Erlang MTProto (recommended) | Sergey Prokhorov" \
    2 "Setup/Manage Python MTProto | HirbodBehnam" \
    3 "Setup/Manage Official MTProto | HirbodBehnam" \
    4 "Setup/Manage Golang MTProto | HirbodBehnam" 2> mtproto_choice.txt

  mtproto_choice=$(cat mtproto_choice.txt)

  case $mtproto_choice in
    "1")
      # Setup Erlang MTProto
      curl -L -o mtp_install.sh https://git.io/fj5ru && bash mtp_install.sh
      ;;
    "2")
      # Setup/Manage Python MTProto
      curl -o MTProtoProxyInstall.sh -L https://git.io/fjo34 && bash MTProtoProxyInstall.sh
      ;;
    "3")
      # Setup/Manage Official MTProto
      curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh
      ;;
    "4")
      # Setup/Manage Golang MTProto
      curl -o MTGInstall.sh -L https://git.io/mtg_installer && bash MTGInstall.sh
      ;;
    *)
      dialog --msgbox "Invalid choice. No MTProto Proxy setup performed." 10 40
      return
      ;;
  esac

  # Wait for the user to press Enter
  read -p "Please press Enter to continue."
}

# Function to set up MTProto Proxy
setup_mtproto_proxy() {
  dialog --title "Setup MTProto Proxy" --yesno "Do you want to set up an MTProto Proxy? It is recommended to install only one of these options, Installing multiple options may lead to conflicts." 10 60
  response=$?
  if [ $response -eq 0 ]; then
    setup_mtproto_proxy_submenu
  else
    dialog --msgbox "Skipping MTProto Proxy setup." 10 40
  fi
}

# 15. Function to setup Hysteria II
setup_hysteria_ii() {
  bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/Hysteria-Installer/main/hysteria.sh)

  # Wait for the user to press Enter
  read -p "Please Press Enter to continue"
}

# 16. Function to setup TUIC v5
setup_tuic_v5() {
  bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/tuic-v5-installer/main/tuic-installer.sh)

  # Wait for the user to press Enter
  read -p "Please Press Enter to continue"
}

# 17. Function to setup Juicity
setup_juicity() {
  dialog --title "Setup Juicity" --yesno "Do you want to setup Juicity?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/Juicity-Installer/main/juicity-installer.sh)
    read -p "Juicity setup completed. Please Press Enter to continue."
  else
    dialog --msgbox "Skipping Juicity setup." 10 40
  fi

  # Return to the menu
}

# 18. Function to set up WireGuard
setup_wireguard_angristan() {
  dialog --title "Setup WireGuard | angristan" --yesno "Do you want to set up WireGuard using angristan's script?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    # Download and execute the WireGuard installation script
    curl -O https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
    chmod +x wireguard-install.sh
    ./wireguard-install.sh

    # Wait for the user to press Enter
    read -p "Please press Enter to continue."
  else
    dialog --msgbox "Skipping WireGuard installation." 10 40
  fi
}

# 19. Function to set up OpenVPN
setup_openvpn_angristan() {
  dialog --title "Setup OpenVPN | angristan" --yesno "Do you want to set up OpenVPN using angristan's script?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    # Download and execute the OpenVPN installation script
    curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x openvpn-install.sh
    ./openvpn-install.sh

    # Wait for the user to press Enter
    read -p "Please press Enter to continue."
  else
    dialog --msgbox "Skipping OpenVPN installation." 10 40
  fi
}

# 20. Function to set up IKEv2/IPsec
setup_ikev2_ipsec() {
  dialog --title "Setup IKEv2/IPsec" --yesno "Do you want to set up IKEv2/IPsec?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    # Download and execute the IKEv2/IPsec installation script
    curl -fsSL https://get.vpnsetup.net -o vpn.sh && sudo sh vpn.sh

    # Wait for the user to press Enter
    read -p "Please press Enter to continue."
  else
    dialog --msgbox "Skipping IKEv2/IPsec setup." 10 40
  fi
}

# 21. Function to setup Reverse Tls Tunnel
setup_reverse_tls_tunnel() {
  # Ask the user if they want to install Reverse Tls Tunnel
  dialog --title "Setup Reverse Tls Tunnel" --yesno "Do you want to install Reverse Tls Tunnel developed by radkesvat?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    # Download the script and make it executable
    wget "https://raw.githubusercontent.com/radkesvat/ReverseTlsTunnel/master/install.sh" -O install.sh && chmod +x install.sh && bash install.sh

    # Display instructions in the terminal
    echo "ReverseTlsTunnel has been downloaded. Please run it in an Iran server with this command:"
    echo "nohup ./RTT --iran --lport:443 --sni:splus.ir --password:123"
    echo
    echo "And run it in an Abroad server with:"
    echo "nohup ./RTT --kharej --iran-ip:5.4.3.2 --iran-port:443 --toip:127.0.0.1 --toport:2083 --password:123 --sni:splus.ir"

    # Wait for the user to press Enter
    read -p "Please Press Enter to continue"
  else
    dialog --msgbox "Skipping installation of Reverse Tls Tunnel." 10 60
  fi
}

# 22. Function to create a non-root SSH user
create_ssh_user() {
  # Ask the user for the username
  dialog --title "Create SSH User" --inputbox "Enter the username for the new SSH user:" 10 60 2> username.txt
  username=$(cat username.txt)

  # Check if the username is empty
  if [ -z "$username" ]; then
    dialog --msgbox "Username cannot be empty. SSH user creation aborted." 10 60
    return
  fi

  # Ask the user for a secure password
  dialog --title "Create SSH User" --passwordbox "Enter a strong password for the new SSH user:" 10 60 2> password.txt
  password=$(cat password.txt)

  # Check if the password is empty
  if [ -z "$password" ]; then
    dialog --msgbox "Password cannot be empty. SSH user creation aborted." 10 60
    return
  fi

  # Create the user with the specified username
  sudo useradd -m -s /bin/bash "$username"

  # Set the user's password securely
  echo "$username:$password" | sudo chpasswd

  # Display the created username and password to the user
  dialog --title "SSH User Created" --msgbox "SSH user '$username' has been created successfully.\n\nUsername: $username\nPassword: $password" 12 60
}

# 23. Function to reboot the system
reboot_system() {
  dialog --title "Reboot System" --yesno "Do you want to reboot the system?" 10 60
  response=$?
  if [ $response -eq 0 ]; then
    dialog --infobox "Rebooting the system..." 5 30
    sleep 2  # Display the message for 2 seconds before rebooting
    sudo reboot
  else
    dialog --msgbox "System reboot canceled." 10 40
  fi
}

# 24. Function to exit the script
exit_script() {
  clear  # Clear the terminal screen for a clean exit
  echo "Exiting the script. Goodbye!"
  exit 0  # Exit with a status code of 0 (indicating successful termination)
}

# Main menu options using dialog
while true; do
  choice=$(dialog --clear --backtitle "Freedom v.1.0.1 - Main Menu" --title "Main Menu" --menu "Choose an option:" 18 60 15 \
    1 "System Update and Cleanup" \
    2 "Install Essential Packages" \
    3 "Install Speedtest" \
    4 "Create Swap File" \
    5 "Enable BBR" \
    6 "Enable Hybla" \
    7 "Schedule Automatic Updates & ReStarts" \
    8 "Install Multiprotocol VPN Panels" \
    9 "Obtain SSL Certificates" \
    10 "Setup Pi-Hole" \
    11 "Change SSH Port" \
    12 "Enable UFW" \
    13 "Install & Configure WARP Proxy" \
    14 "Setup MTProto Proxy" \
    15 "Setup/Manage Hysteria II" \
    16 "Setup/Manage TUIC v5" \
    17 "Setup/Manage Juicity" \
    18 "Setup/Manage WireGuard" \
    19 "Setup/Manage OpenVPN" \
    20 "Setup IKEv2/IPsec" \
    21 "Setup Reverse TLS Tunnel" \
    22 "Create SSH User" \
    23 "Reboot System" \
    24 "Exit Script" 3>&1 1>&2 2>&3)

  case $choice in
    1) system_update ;;
    2) install_essential_packages ;;
    3) install_speedtest ;;
    4) create_swap_file ;;
    5) enable_bbr ;;
    6) enable_hybla ;;
    7) enable_and_configure_cron ;;
    8) install_vpn_panel ;;
    9) obtain_ssl_certificates ;;
    10) setup_pi_hole ;;
    11) change_ssh_port ;;
    12) enable_ufw ;;
    13) install_configure_warp_proxy ;;
    14) setup_mtproto_proxy ;;
    15) setup_hysteria_ii ;;
    16) setup_tuic_v5 ;;
    17) setup_juicity ;;
    18) setup_wireguard_angristan ;;
    19) setup_openvpn_angristan ;;
    20) setup_ikev2_ipsec ;;
    21) setup_reverse_tls_tunnel ;;
    22) create_ssh_user ;;
    23) reboot_system ;;
    24) exit_script ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done
