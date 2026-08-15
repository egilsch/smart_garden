# Network Architecture & Security

Smart Garden IIoT project — network design, security zones, and packet analysis.
Based on ISA/IEC 62443 Zone and Conduit model.

---

## Network overview

```
Internet
    │
    │  HTTPS/TLS outbound only
    ▼
Cloud (InfluxDB Cloud / AWS IoT Core)
    │
    │  HTTPS/TLS outbound only (Pi 5 initiates, no inbound)
    ▼
Router / Home network (192.168.1.0/24)
    │
    ├── Ubuntu Workstation    192.168.1.x   (main LAN)
    │
    ├── Raspberry Pi 5        192.168.1.100  (main LAN — SSH, OPC UA, Grafana)
    │                         192.168.10.1   (IoT VLAN gateway — MQTT broker)
    │
    └── IoT VLAN (192.168.10.0/24) ← isolated from main LAN
            │
            ├── Pico 2WH Zone 1    192.168.10.11
            └── Pico 2WH Zone 2    192.168.10.12
```

---

## ISA/IEC 62443 Security Zones

### Zone 1 — OT Field Zone (IoT VLAN 192.168.10.0/24)

Isolated VLAN containing field devices only. No device in this zone can initiate connections to the main LAN or internet — they can only publish MQTT to the Pi 5 broker.

| Device | IP | Allowed outbound | Allowed inbound |
|---|---|---|---|
| Pico 2WH Zone 1 | 192.168.10.11 | MQTT TLS → Pi 5:8883 | None |
| Pico 2WH Zone 2 | 192.168.10.12 | MQTT TLS → Pi 5:8883 | None |

**Security controls:**
- WPA3 WiFi (upgrade from WPA2)
- MQTT over TLS 1.3 — port 8883, not plain 1883
- Client certificates on each Pico (unique per device)
- Publish-only ACL — Picos cannot subscribe to arbitrary topics
- No SSH, no open ports, no services

### Zone 2 — DMZ / Edge Zone (Raspberry Pi 5)

The Pi 5 sits between the OT field zone and the IT/cloud zone. It accepts MQTT from field devices and exposes services only to the local LAN — never directly to the internet.

| Service | Port | Bound to | Auth | Access |
|---|---|---|---|---|
| Mosquitto MQTT (TLS) | 8883 | 192.168.10.1 | Client certs + ACL | IoT VLAN only |
| InfluxDB v2 | 8086 | localhost | Scoped API tokens | Localhost only |
| Grafana | 3000 | 0.0.0.0 | Username + strong password | LAN only (UFW) |
| OPC UA server | 4840 | 0.0.0.0 | Certificate auth + SignAndEncrypt | LAN only (UFW) |
| SSH | 22 | 0.0.0.0 | Key-only (no passwords) | LAN only (UFW) |

**UFW firewall rules:**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22    # SSH from LAN only
sudo ufw allow from 192.168.10.0/24 to any port 8883 # MQTT from IoT VLAN only
sudo ufw allow from 192.168.1.0/24 to any port 3000  # Grafana from LAN only
sudo ufw allow from 192.168.1.0/24 to any port 4840  # OPC UA from LAN only
sudo ufw enable
```

**OS hardening checklist:**
- [ ] SSH key-only auth — disable password login (`PasswordAuthentication no`)
- [ ] fail2ban — auto-ban repeated SSH failures
- [ ] unattended-upgrades — automatic security patches
- [ ] Non-root service accounts for Mosquitto, InfluxDB, Grafana
- [ ] Disable unused services (`bluetooth`, `avahi-daemon` if not needed)
- [ ] AppArmor profiles for services
- [ ] Automatic reboot after kernel updates

### Zone 3 — Cloud / IT Zone

Cloud services accessed outbound only from the Pi 5. No inbound ports opened.

| Service | Auth | Security |
|---|---|---|
| InfluxDB Cloud | Scoped write-only token | TLS enforced, MFA on account |
| AWS IoT Core | X.509 device certificate | IoT policy, topic ACLs |

**Conduits (connections between zones):**
- Zone 1 → Zone 2: MQTT over TLS 1.3 port 8883, client certs, Pico-initiated only
- Zone 2 → Zone 3: HTTPS/TLS 1.3 outbound, Pi 5-initiated only, no inbound

---

## MQTT security configuration

### Mosquitto TLS setup (Pi 5)

```bash
# Generate CA and server certificates
mkdir -p ~/certs/mqtt
cd ~/certs/mqtt

# Create Certificate Authority
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=SmartGarden-CA"

# Create server certificate for Pi 5
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/CN=smartgarden.local"
openssl x509 -req -days 3650 -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

# Create client certificate for each Pico
openssl genrsa -out pico1.key 2048
openssl req -new -key pico1.key -out pico1.csr \
  -subj "/CN=pico-zone1"
openssl x509 -req -days 3650 -in pico1.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out pico1.crt
```

**Mosquitto config (`/etc/mosquitto/mosquitto.conf`):**
```
# Disable plain text port entirely
# (do NOT add listener 1883)

# TLS only
listener 8883
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key
require_certificate true
use_identity_as_username true

# ACL file
acl_file /etc/mosquitto/acl

# Logging
log_type all
log_dest file /var/log/mosquitto/mosquitto.log
```

**Mosquitto ACL (`/etc/mosquitto/acl`):**
```
# Pico Zone 1 — publish sensor data, subscribe to control topics only
user pico-zone1
topic write garden/zone1/#
topic read garden/zone1/control/#

# Pico Zone 2
user pico-zone2
topic write garden/zone2/#
topic read garden/zone2/control/#

# Pi 5 bridge — full access
user pi5-bridge
topic #
```

---

## Packet analysis with Wireshark

### What you will see between Pico and Pi 5

Install Wireshark on Ubuntu:
```bash
sudo apt install wireshark
sudo usermod -aG wireshark $USER
# Log out and back in, then launch Wireshark
```

Capture on your WiFi interface and filter for the Pico IP:
```
ip.addr == 192.168.10.11
```

#### 1 — TCP three-way handshake
```
192.168.10.11 → 192.168.10.1:8883   [SYN]         Pico initiates connection
192.168.10.1  → 192.168.10.11       [SYN, ACK]    Pi 5 accepts
192.168.10.11 → 192.168.10.1        [ACK]          Connection established
```

#### 2 — TLS 1.3 handshake
```
192.168.10.11 → 192.168.10.1   Client Hello    cipher suites, client cert
192.168.10.1  → 192.168.10.11  Server Hello    chosen cipher, server cert
192.168.10.11 → 192.168.10.1   Finished        session keys exchanged
```
After this all packets show as `[Application Data]` — encrypted, unreadable without the key.

#### 3 — Decrypting MQTT packets in Wireshark (learning exercise)
Add your TLS session key to Wireshark to decrypt and inspect MQTT:
```
Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename
```
Point it at a key log file generated during development.

Once decrypted you will see raw MQTT packets:
```
CONNECT    clientId=pico-zone1  keepAlive=60s
CONNACK    returnCode=0 (Connection Accepted)
PUBLISH    topic=garden/zone1/soil/moisture1  payload=67.3  QoS=0  retain=0
PUBLISH    topic=garden/zone1/system/heartbeat  payload=1720000000
PINGREQ    (keepalive every 60s)
PINGRESP   (Pi 5 acknowledges)
```

#### 4 — OPC UA packets (port 4840)
```
HEL  → Hello message (client introduces itself)
ACK  ← Acknowledge
OPN  → OpenSecureChannel request (certificate exchange)
OPN  ← OpenSecureChannel response
MSG  → CreateSession, ActivateSession, Browse, Read, Subscribe
MSG  ← Responses (node values, timestamps, engineering units)
```

---

## IP addressing plan

| Device | Interface | IP | Subnet | Purpose |
|---|---|---|---|---|
| Router | — | 192.168.1.1 | /24 | Default gateway |
| Raspberry Pi 5 | eth0/wlan0 | 192.168.1.100 | /24 | Main LAN (SSH, OPC UA, Grafana) |
| Raspberry Pi 5 | VLAN10 | 192.168.10.1 | /24 | IoT VLAN gateway (MQTT broker) |
| Pico 2WH Zone 1 | WiFi | 192.168.10.11 | /24 | Field device (static DHCP lease) |
| Pico 2WH Zone 2 | WiFi | 192.168.10.12 | /24 | Field device (static DHCP lease) |
| Ubuntu workstation | eth0/wlan0 | 192.168.1.x | /24 | Development machine |

---

## Threat model

| Threat | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Pico compromised via WiFi | Low | Medium | WPA3, client certs, publish-only ACL, no inbound ports |
| MQTT interception | Low | Medium | TLS 1.3, certificate pinning on Picos |
| Pi 5 SSH brute force | Medium | High | Key-only auth, fail2ban, non-standard port option |
| InfluxDB exposed to internet | Low | High | Localhost bind only, UFW deny all inbound |
| Cloud token leaked | Low | Medium | Scoped write-only token, rotation policy |
| Physical access to Pi 5 | Low | High | SD card encryption (LUKS) optional for Phase 7 |
| Rogue device on IoT VLAN | Low | Medium | VLAN isolation, MAC filtering, certificate auth |

---

## Learning resources

| Topic | Resource |
|---|---|
| IEC 62443 overview | isa.org/iec-62443 |
| MQTT security | hivemq.com/blog/mqtt-security-fundamentals |
| Wireshark tutorials | wireshark.org/docs/wsug_html |
| TLS fundamentals | cloudflare.com/learning/ssl/what-is-tls |
| OPC UA security | opcfoundation.org/developer-tools/specifications-unified-architecture |
| Network scanning (learn how attackers see your network) | nmap.org |
