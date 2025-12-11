# Block-Update-Fire-TV-Stick-Amazon
A script for OpenWrt that blocks Fire TV Stick OTA updates and telemetry using dnsmasq and ipset. It prevents system updates, logs attempts with tcpdump, and dynamically updates the blacklist via parser. Compatible with OpenWrt 21.02+.

# firetv-stick-block.sh

A script for OpenWrt that permanently blocks OTA updates and telemetry from the Fire TV Stick.  
It uses **dnsmasq** and **ipset** to filter known domains and IPs, preventing system updates and data collection.  
Includes a logging module with **tcpdump** to record connection attempts and an automatic parser that dynamically updates the blacklist.  
Compatible with OpenWrt 21.02+.

# Features
- Block Fire TV OTA update domains via dnsmasq
- Block known Amazon IPs via ipset + firewall
- Block DNS-over-HTTPS (DoH) resolvers
- Log DNS/HTTPS traffic from Fire TV with tcpdump
- Parse logs to dynamically update blacklist

## Requirements
Make sure the following packages are installed on OpenWrt:

<pre>opkg update
opkg install ipset tcpdump dnsmasq</pre>

# Installation with putty

<pre>vi /etc/firetv-stick-block.sh</pre>
Paste:
<pre>/etc/firetv-stick-block.sh</pre>
Press CTRL + C and write :wq! (Save)
<pre>vi /etc/rc.local</pre>
Paste:
<pre>*/30 * * * * /etc/firetv-block.sh >> /var/log/firetv_cron.log 2>&1</pre>
Save and exit (Press CTRL + C and :wq!

# 🔍 How it works

tcpdump intercepts Fire TV traffic (port 53 for DNS and port 443 for HTTPS).
Each request is written to the log /var/log/firetv_monitor.log.
The function update_blacklist_from_log() analyzes that log:
Extracts DNS domains (e.g., softwareupdates.amazon.com) from captured queries.
Extracts HTTPS IPs (e.g., 54.239.25.192) from attempted connections.
If it finds a domain or IP not yet blocked:
It adds it to dnsmasq (for domains).
It adds it to ipset (for IPs).
Finally, it restarts dnsmasq and reloads the firewall → the block becomes immediately active.

# Fire TV firmware updates → blocked, Amazon telemetry → blocked, DNS over HTTPS (Google, Cloudflare, Quad9) → blocked, Appstore and streaming (Prime, Netflix, etc.) → still working and Detailed log → available for analysis and to discover new domains/IPs to block

# Visit my blog:
https://www.ilblogdicristiangallo.com
