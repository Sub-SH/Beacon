#!/bin/bash
# Description: Configure a Raspberry Pi hotspot to serve Wiki sites and maps
# Author: SH

USER_NAME=${SUDO_USER:-$USER}

update_system() {
    echo "Updating system..."
    echo "   - This will take several minutes"
    apt-get update -qq && apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' &> /dev/null
}

install_docker() {
    echo "Installing Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &> /dev/null
    usermod -aG docker "$USER_NAME"
}

install_kiwix() {
    echo "Installing Kiwix-serve..."
    mkdir -p /opt/kiwix/data
    chmod -R 700 /opt/kiwix

    cat <<EOF > "/opt/kiwix/docker-compose.yml"
services:
  kiwix-serve:
    image: ghcr.io/kiwix/kiwix-serve:latest
    container_name: kiwix
    volumes:
      - /opt/kiwix/data:/data
    ports:
      - '8080:8080'
    command: '*.zim'
    restart: unless-stopped
EOF
    
    chown -R "$USER_NAME":"$USER_NAME" /opt/kiwix
}

install_tileserver() {
    echo "Installing tileserver-gl..."
    mkdir -p /opt/tileserver/data
    chmod -R 700 /opt/tileserver

    cat <<EOF > "/opt/tileserver/docker-compose.yml"
services:
  tileserver:
    image: maptiler/tileserver-gl-light:latest
    container_name: tileserver
    restart: unless-stopped
    ports:
      - '8081:8080'
    volumes:
      - ./data/map.mbtiles:/data/map.mbtiles
EOF

    chown -R "$USER_NAME":"$USER_NAME" /opt/tileserver
}

configure_hotspot() {
    echo "Configuring wifi hotspot..."

    local hostname="$(hostname)"
    apt-get install -y dnsmasq hostapd &> /dev/null

    cat <<EOF > "/etc/netplan/50-cloud-init.yaml"
network:
    ethernets:
        eth0:
            dhcp4: true
            optional: true
        wlan0:
            dhcp4: false
            addresses:
            - 192.168.2.1/24
    version: 2
EOF

    cat <<EOF > "/etc/hostapd/hostapd.conf"
interface=wlan0
driver=nl80211
ssid=$ssid_name
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$wifi_pass
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    cat <<EOF > "/etc/default/hostapd"
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null
    systemctl start hostapd &> /dev/null

    cat <<EOF > "/etc/dnsmasq.conf"
interface=wlan0
dhcp-range=192.168.2.10,192.168.2.20,255.255.255.0,24h
EOF

    cat <<EOF > "/etc/systemd/resolved.conf"
[Resolve]
DNS=1.1.1.1
FallbackDNS=8.8.8.8
DNSStubListener=no
#ReadEtcHosts=yes
EOF

    echo "127.0.1.1       $hostname" >> /etc/hosts

    systemctl restart systemd-resolved.service &> /dev/null
    systemctl restart dnsmasq.service &> /dev/null

}

get_wifi_info() {

    read -p 'Input a name to be used for the Wifi SSID: ' ssid_name
    echo

    while true; do
        read -s -p 'Input a password to be used for the Wifi: ' wifi_pass
        echo
        read -s -p 'Please re-enter the password: ' wifi_pass1
        echo
        echo

        if [[ "$wifi_pass" == "$wifi_pass1" ]]; then
            break
        else
            echo "Passwords do not match. Please try again." >&2
        fi
    done

}

steez() {
    cat << "EOF"
             ##                                            
           ######                                          
        ###########                                        
      ###############                 -+######++++++                 
      ###############          -+#################+++++          
      # #  #   #  # #       --#######################+#++++    
      # #  #   #  # #            -##################++++++
      # #  #   #  # #                 -############+++++++
      +++++++++++++++                        -#######++++
     #################         ____                                                            
     ###################      / __ )___  ____ __________  ____                          
  #######################    / __  / _ \/ __ `/ ___/ __ \/ __ \                              
    ##               ##     / /_/ /  __/ /_/ / /__/ /_/ / / / /                             
      ###############      /_____/\___/\__,_/\___/\____/_/ /_/ v1.0                               
      ###############                                                                          
      ###############                                     
      ###############                                     
     #################                                                                        
     #################                                     
     #################                                    
    ###################                                                                       
    ###################   

EOF
}

main () {
    if (( EUID != 0 )); then
        echo "This script must be run as root. Re-run the script using 'sudo'. Exiting..." 1>&2
        exit 100
    fi
    steez
    get_wifi_info

    echo "======= Beginning Configuration ======="
    update_system
    install_docker
    install_kiwix
    install_tileserver
    configure_hotspot

    echo
    echo "======= Configuration Complete ======="
    echo 
    cat <<EOF
! A restart is needed. System will automatically restart in 60 seconds.

! Important: Docker services are not yet running. BEFORE bringing them up, you must transfer over wikis and maptiles.
     - Place .zim wiki files in /opt/kiwix/data
     - Place .mbtile map files in /opt/tileserver/data

Once completed, run 'docker compose up -d' from both the /opt/kiwix and /opt/tileserver directories.

See the GitHub for step-by-step instructions.
EOF

    shutdown -r +1

}

main
