#!/bin/sh
# === CONFIGURAZIONE FIRE TV STICK ===

FIRETV_IP="192.168.1.126"   # IP della Fire TV Stick nella tua LAN
IFACE="br-lan"              # Interfaccia LAN (modifica se serve: wlan0, eth0)
IPSET_NAME="firetv_blocklist"
DNSMASQ_CONF="/etc/dnsmasq.d/firetv-block.conf"
LOG_FILE="/tmp/firetv_monitor.log"
TMP_DOMAINS="/tmp/firetv_new_domains.txt"
TMP_IPS="/tmp/firetv_new_ips.txt"

BLOCKED_DOMAINS="
amzdigitaldownloads.edgesuite.net
softwareupdates.amazon.com
updates.amazon.com
firmwareupdates.amazon.com
device-metrics-us.amazon.com
device-metrics-eu.amazon.com
device-metrics.amazon.com
s3.amazonaws.com
"

# === CREA DIRECTORY DNSMASQ ===
mkdir -p /etc/dnsmasq.d

# === CREA IPSET ===
setup_ipset() {
  ipset create $IPSET_NAME hash:ip maxelem 10000 2>/dev/null
}

# === CONFIGURA FIREWALL FW4 ===
setup_firewall() {
  uci -q delete firewall.firetv_ipset
  uci set firewall.firetv_ipset="ipset"
  uci set firewall.firetv_ipset.name="$IPSET_NAME"
  uci set firewall.firetv_ipset.match="dest_ip"
  uci set firewall.firetv_ipset.family="ipv4"

  uci -q delete firewall.firetv_block
  uci set firewall.firetv_block="rule"
  uci set firewall.firetv_block.name="Block Fire TV Stick Updates"
  uci set firewall.firetv_block.src="lan"
  uci set firewall.firetv_block.src_ip="$FIRETV_IP"
  uci set firewall.firetv_block.dest="wan"
  uci set firewall.firetv_block.proto="all"
  uci set firewall.firetv_block.ipset="$IPSET_NAME"
  uci set firewall.firetv_block.target="REJECT"

  uci commit firewall
  /etc/init.d/firewall reload >/dev/null 2>&1
}

# === CONFIGURA DNSMASQ ===
setup_dnsmasq() {
  echo "# Fire TV Stick blocklist" > "$DNSMASQ_CONF"
  for domain in $BLOCKED_DOMAINS; do
    echo "address=/$domain/0.0.0.0" >> "$DNSMASQ_CONF"
    echo "address=/$domain/::" >> "$DNSMASQ_CONF"
  done
  /etc/init.d/dnsmasq restart >/dev/null 2>&1
}

# === MONITORA TRAFFICO FIRE TV ===
monitor_firetv_traffic() {
  /usr/bin/tcpdump -i $IFACE host $FIRETV_IP and port 53 -n -l >> "$LOG_FILE" 2>&1 &
  /usr/bin/tcpdump -i $IFACE host $FIRETV_IP and port 443 -n -l >> "$LOG_FILE" 2>&1 &
}

# === PARSA LOG E AGGIORNA BLACKLIST ===
update_blacklist_from_log() {
  grep "$FIRETV_IP" "$LOG_FILE" | grep -oE '([a-zA-Z0-9.-]+\.(com|net|org|io|app))' | sort -u > "$TMP_DOMAINS"
  grep "$FIRETV_IP" "$LOG_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u > "$TMP_IPS"

  for domain in $(cat "$TMP_DOMAINS"); do
    if ! grep -q "$domain" "$DNSMASQ_CONF"; then
      echo "address=/$domain/0.0.0.0" >> "$DNSMASQ_CONF"
      echo "address=/$domain/::" >> "$DNSMASQ_CONF"
      echo "[+] Nuovo dominio bloccato: $domain" >> "$LOG_FILE"
    fi
  done

  for ip in $(cat "$TMP_IPS"); do
    if ! ipset test $IPSET_NAME $ip 2>/dev/null; then
      ipset add $IPSET_NAME $ip
      echo "[+] Nuovo IP bloccato: $ip" >> "$LOG_FILE"
    fi
  done

  /etc/init.d/dnsmasq restart >/dev/null 2>&1
  /etc/init.d/firewall reload >/dev/null 2>&1
}

# === AVVIO ===
setup_ipset
setup_firewall
setup_dnsmasq
monitor_firetv_traffic
update_blacklist_from_log
