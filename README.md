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

## Requirements Packages
Make sure the following packages are installed on OpenWrt:

<pre>opkg update
opkg install tcpdump
opkg install ipset
opkg remove dnsmasq
opkg install dnsmasq-full</pre>

# firewall4 Already present in recent versions (OpenWrt ≥ 22). It’s needed to apply UCI rules. If you’re using an older version, the package is firewall (fw3).

# Installation with putty

<pre>vi /etc/firetv-stick-block.sh</pre>
Paste the script content here
<pre>/etc/firetv-stick-block.sh</pre>
Press CTRL + C and write :wq! (Save)
# Cron job
<pre>vi /etc/rc.local</pre>
Paste:
<pre>*/10 * * * * /etc/firetv-stick-block.sh >> /var/log/firetv_cron.log 2>&1</pre>
Save and exit (Press CTRL + C and :wq!
# Restart Cron
<pre>/etc/init.d/cron restart</pre>

# 🔍 How it works
How the script works
Variable definitions
You set the IP address of the device to block.
You specify the network interface (LAN/Wi‑Fi).
Paths for logs and temporary files are created.
A list of known domains to block is defined.
Creating ipset
The script creates an IP set (ipset) that collects addresses to block.
This set is dynamic: it updates as new IPs are found.
Firewall configuration
A rule is added that says: “If traffic comes from this device and the destination is in the ipset → REJECT.”
In practice, every IP added to the set is blocked.
Dnsmasq configuration
A file is generated with rules like address=/domain/0.0.0.0.
This means when the device tries to resolve those domains, it gets 0.0.0.0 as a response and cannot connect.
dnsmasq is restarted to apply the new rules.
Traffic monitoring (tcpdump)
Two tcpdump processes are started:
One captures DNS requests (port 53).
One captures HTTPS traffic (port 443).
Everything is written into a log file.
Log parsing and blacklist update
The script analyzes the log:
Extracts domains → adds them to the dnsmasq file if not already present.
Extracts IPs → adds them to the ipset if not already present.
Each new block is noted in the log with [+] New domain blocked or [+] New IP blocked.
dnsmasq and firewall are restarted to make the new rules effective.
Automation with cron
You can schedule the script or just the parsing function.
This way, every X minutes the log is analyzed and ipset/dnsmasq are updated automatically.
Result: the device can never download updates, because every new server is intercepted and blocked.

# 🔍 In summary
DNS immediately blocks known domains.
tcpdump captures attempts to reach new IPs/domains.
Parsing dynamically updates dnsmasq and ipset.
Firewall rejects connections to blocked IPs.
Cron keeps everything updated without manual intervention.

# Fire TV firmware updates → blocked, Amazon telemetry → blocked, DNS over HTTPS (Google, Cloudflare, Quad9) → blocked, Appstore and streaming (Prime, Netflix, etc.) → still working and Detailed log → available for analysis and to discover new domains/IPs to block

# Visit my blog:
https://www.ilblogdicristiangallo.com
