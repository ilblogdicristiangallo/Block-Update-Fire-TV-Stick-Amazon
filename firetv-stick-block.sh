#!/bin/sh
# firetv-block.sh — Block Fire TV Stick updates via OpenWrt
# Author: Cristian — Stable version with logging and dynamic blacklist update

### CONFIGURATION ###
FIRETV_IP="192.168.1.123"  # ← Replace with the static IP of your Fire TV
LOGFILE="/var/log/firetv_monitor.log"
IPSET_NAME="blocked_firetv_ips"

BLOCKED_DOMAINS="
softwareupdates.amazon.com
firmwareupdates.amazon.com
updates.amazon.com
amzdigitaldownloads.edgesuite.net
a1703.d.akamai.net
a248.e.akamai.net
amzdigital-a.akamaihd.net
device-metrics-us.amazon.com
device-metrics-eu.amazon.com
s3.amazonaws.com
s3-eu-west-1.amazonaws.com
s3.amazonaws.com.edgesuite.net
data.flurry.com
flurry.com
dns.google
cloudflare-dns.com
mozilla.cloudflare-dns.com
dns.quad9.net
"

BLOCKED_IPS="
54.239.25.192
54.239.25.200
54.239.25.208
54.239.25.216
176.32.103.205
176.32.103.206
176.32.103.207
176.32.103.208
176.32.103.209
176.32.103.210
176.32.103.211
176.32.103.212
176.32.103.213
176.32.103.214
176.32.103.215
"

### FUNCTIONS ###

setup_dns_block() {
  echo "[*] Blocking DNS via dnsmasq..."
  for domain in $BLOCKED_DOMAINS; do
    uci add_list dhcp.@dnsmasq[0].address="/$domain/0.0.0.0"
  done
  uci commit dhcp
  /etc/init.d/dnsmasq restart
}

setup_ip_block() {
  echo "[*] Blocking IPs via ipset + firewall..."
  ipset create $IPSET_NAME hash:ip maxelem 10000 2>/dev/null
  for ip in $BLOCKED_IPS; do
    ipset add $IPSET_NAME $ip 2>/dev/null
  done

  uci -q delete firewall.firetv_block
  uci set firewall.firetv_block="rule"
  uci set firewall.firetv_block.name="Block-FireTV-IPs"
  uci set firewall.firetv_block.src="lan"
  uci set firewall.firetv_block.dest="wan"
  uci set firewall.firetv_block.dest_ip="$IPSET_NAME"
  uci set firewall.firetv_block.proto="all"
  uci set firewall.firetv_block.target="REJECT"
  uci commit firewall
  /etc/init.d/firewall restart
}

monitor_firetv_traffic() {
  echo "[*] Starting Fire TV traffic monitoring ($FIRETV_IP)..."
  echo "=== $(date) ===" >> "$LOGFILE"
  if ! pgrep -f "tcpdump.*$FIRETV_IP" > /dev/null; then
    nohup tcpdump -i br-lan host "$FIRETV_IP" and \( port 53 or port 443 \) -nn -tt >> "$LOGFILE" 2>/dev/null &
    echo "[✓] Logging active in background to $LOGFILE"
  else
    echo "[!] Logging already running."
  fi
}

update_blacklist_from_log() {
  echo "[*] Parsing log for new domains/IPs..."

  # New DNS domains
  grep -oE 'A\? ([a-zA-Z0-9.-]+\.)?amazon\.com' "$LOGFILE" | awk '{print $2}' | sort -u | while read domain; do
    if ! grep -q "$domain" /etc/config/dhcp; then
      echo "[+] New domain: $domain"
      uci add_list dhcp.@dnsmasq[0].address="/$domain/0.0.0.0"
    fi
  done

  # New HTTPS IPs
  grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.443' "$LOGFILE" | cut -d. -f1-4 | sort -u | while read ip; do
    if ! ipset test $IPSET_NAME $ip 2>/dev/null; then
      echo "[+] New IP: $ip"
      ipset add $IPSET_NAME $ip
    fi
  done

  uci commit dhcp
  /etc/init.d/dnsmasq restart
  /etc/init.d/firewall reload
}

main() {
  echo "[+] Starting Fire TV Stick update blocking script..."
  setup_dns_block
  setup_ip_block
  monitor_firetv_traffic
  update_blacklist_from_log
  echo "[✓] Blocking complete. Restart Fire TV to apply."
}

main
