# Security Implementation Worksheet

Track progress on all security controls. Work through these in order — each phase builds on the previous.

---

## Phase 3 — Basic MQTT security (implement alongside MQTT networking)

### Network setup
- [ ] Create IoT VLAN on router (192.168.10.0/24)
- [ ] Assign static DHCP leases for both Picos (10.11 and 10.12)
- [ ] Verify Picos cannot reach main LAN (192.168.1.0/24) — ping test
- [ ] Verify Pi 5 can bridge both VLANs
- [ ] Connect workstation to main LAN only — verify it can SSH to Pi 5

### Mosquitto TLS setup
- [ ] Generate CA certificate and key (`ca.crt`, `ca.key`)
- [ ] Generate Pi 5 server certificate signed by CA (`server.crt`)
- [ ] Generate Pico client certificates — one per device (`pico1.crt`, `pico2.crt`)
- [ ] Configure Mosquitto: TLS only on port 8883, no plain port 1883
- [ ] Configure Mosquitto: require client certificates
- [ ] Configure ACL: Pico 1 publish only to `garden/zone1/#`
- [ ] Configure ACL: Pico 2 publish only to `garden/zone2/#`
- [ ] Test: verify plain MQTT connection on 1883 is refused
- [ ] Test: verify TLS connection without cert is refused
- [ ] Test: verify Pico 1 cannot publish to `garden/zone2/#`
- [ ] Embed CA cert and client cert in Pico C++ firmware

### Pi 5 firewall
- [ ] Install and enable UFW
- [ ] Default deny all inbound
- [ ] Allow SSH from LAN only (port 22, 192.168.1.0/24)
- [ ] Allow MQTT from IoT VLAN only (port 8883, 192.168.10.0/24)
- [ ] Verify rules with `sudo ufw status verbose`
- [ ] Test: verify port 8883 is not reachable from main LAN

### Packet analysis exercise (Wireshark)
- [ ] Install Wireshark on Ubuntu workstation
- [ ] Capture WiFi traffic during Pico startup
- [ ] Identify TCP three-way handshake in capture
- [ ] Identify TLS ClientHello and ServerHello packets
- [ ] Confirm MQTT payload is encrypted (`[Application Data]` only)
- [ ] Add TLS session key and decrypt MQTT packets
- [ ] Identify CONNECT, CONNACK, PUBLISH packets in decrypted view
- [ ] Document findings in `docs/network/wireshark-notes.md`

---

## Phase 4 — OS hardening (implement alongside edge analytics)

### SSH hardening
- [ ] Confirm SSH key-only login works from workstation
- [ ] Disable SSH password auth (`PasswordAuthentication no` in sshd_config)
- [ ] Restart SSH service and verify password login refused
- [ ] Change default `pi` username or lock it if not needed

### Service hardening
- [ ] Install fail2ban — auto-ban SSH brute force
- [ ] Configure fail2ban: 3 failures → 1 hour ban
- [ ] Enable unattended-upgrades for automatic security patches
- [ ] List all running services: `systemctl list-units --type=service --state=running`
- [ ] Disable unused services (bluetooth, avahi if not needed)
- [ ] Verify InfluxDB binds to localhost only (`netstat -tlnp | grep 8086`)
- [ ] Set strong Grafana admin password (not default admin/admin)
- [ ] Restrict Grafana to read-only for non-admin users

### User and permissions
- [ ] Create non-root service user for Mosquitto: `mosquitto` (usually auto-created)
- [ ] Verify InfluxDB runs as `influxdb` user (not root)
- [ ] Verify Grafana runs as `grafana` user (not root)
- [ ] Review file permissions on certificate files (`chmod 600 *.key`)

### Scanning exercise (learn how attackers see your Pi 5)
- [ ] Install nmap on Ubuntu workstation: `sudo apt install nmap`
- [ ] Scan Pi 5 from workstation: `nmap -sV 192.168.1.100`
- [ ] Verify only expected ports are open (22, 3000, 4840, 8883)
- [ ] Scan from IoT VLAN perspective (connect a device to VLAN, scan again)
- [ ] Document open ports and confirm each is intentional

---

## Phase 5 — OPC UA security (implement alongside OPC UA server)

### Certificate infrastructure
- [ ] Generate OPC UA application certificate for the server
- [ ] Generate OPC UA client certificate for UaExpert on workstation
- [ ] Configure asyncua server: `SecurityPolicyUri = Basic256Sha256`
- [ ] Configure asyncua server: `MessageSecurityMode = SignAndEncrypt`
- [ ] Add workstation UaExpert certificate to Pi 5 trusted list
- [ ] Test: verify unsigned/unencrypted OPC UA connections are rejected
- [ ] Test: verify UaExpert can browse address space with cert auth

### OPC UA packet analysis
- [ ] Capture OPC UA traffic on port 4840 with Wireshark
- [ ] Identify HEL/ACK handshake packets
- [ ] Identify OpenSecureChannel request/response
- [ ] Identify Browse and Read service calls
- [ ] Confirm encrypted session — payload not readable without cert

---

## Phase 6 — Cloud security (implement alongside cloud push)

### InfluxDB Cloud
- [ ] Enable MFA on InfluxDB Cloud account
- [ ] Create write-only scoped token (no read, no admin)
- [ ] Store token in environment variable — never hardcode in scripts
- [ ] Create `.env` file on Pi 5 for tokens (not committed to git — in .gitignore)
- [ ] Test: verify token cannot read data (write-only)
- [ ] Set data retention policy — delete data older than 1 year

### API token management
- [ ] Never commit tokens to git — verify `.gitignore` includes `.env`
- [ ] Use `python-dotenv` to load tokens in Python scripts
- [ ] Rotate tokens every 6 months (calendar reminder)

---

## Security knowledge checklist — concepts to understand

Work through these as you implement each phase. You don't need to memorise them — just understand what they mean and why they matter.

### Networking
- [ ] What is a VLAN and why does it improve security?
- [ ] What is the difference between a firewall rule and a VLAN?
- [ ] What is NAT and how does your router use it?
- [ ] What does a port scan actually do?
- [ ] What is the difference between TCP and UDP?
- [ ] What is a subnet mask and what does /24 mean?

### Cryptography
- [ ] What is the difference between symmetric and asymmetric encryption?
- [ ] What is a certificate and what does it prove?
- [ ] What is a Certificate Authority (CA)?
- [ ] What is the difference between signing and encrypting?
- [ ] What is TLS and what problem does it solve?
- [ ] What is a private key and why must it never leave the device?

### MQTT security
- [ ] What is the difference between port 1883 and 8883?
- [ ] What is an ACL and how does Mosquitto use it?
- [ ] What does "client certificate" mean in MQTT context?
- [ ] What could an attacker do if MQTT had no authentication?

### OPC UA security
- [ ] What is SignAndEncrypt mode vs Sign-only vs None?
- [ ] What is an OPC UA application certificate?
- [ ] What is the OPC UA trust store?
- [ ] Why is OPC UA security built in rather than bolted on?

### IEC 62443
- [ ] What is a Security Level (SL) in IEC 62443?
- [ ] What is the difference between a Zone and a Conduit?
- [ ] What Security Level does this project approximately achieve?
- [ ] How would you increase the Security Level for a real industrial deployment?

---

## Tools used in this security track

| Tool | Purpose | Install |
|---|---|---|
| Wireshark | Packet capture and protocol analysis | `sudo apt install wireshark` |
| nmap | Network scanning — see open ports | `sudo apt install nmap` |
| openssl | Certificate generation | `sudo apt install openssl` |
| UFW | Ubuntu firewall management | Pre-installed on Ubuntu |
| fail2ban | SSH brute force protection | `sudo apt install fail2ban` |
| MQTT Explorer | Visual MQTT debugging | mqttexplorer.com |
| UaExpert | OPC UA client for browsing | unified-automation.com |
