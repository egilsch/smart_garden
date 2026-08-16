# Smart Garden — Project Progress

Live tracker for the autonomous irrigation and monitoring system.
Update this file as each step is completed. Use Claude Code in VS Code to help update and suggest next steps.

**Last updated:** 2026-08-09
**Current phase:** Pre-hardware — environment setup complete, awaiting hardware delivery

---

## Overall status

| Phase | Description | Status |
|---|---|---|
| 0 | Environment setup | ✅ Complete |
| 1 | C++ foundations — sensor reading | ⏳ Waiting for hardware |
| 2 | Control loop — PID and actuation | ⬜ Not started |
| 3 | MQTT networking | ⬜ Not started |
| 4 | Edge analytics stack | ⬜ Not started |
| 5 | OPC UA server | ⬜ Not started |
| 6 | Cloud + anomaly detection | ⬜ Not started |
| 7 | Hardening and outdoor deployment | ⬜ Not started |

---

## Phase 0 — Environment setup

**Goal:** Full development environment ready before hardware arrives.

### Workstation (Ubuntu 26.04)

- [x] VS Code installed
- [x] g++ 15.2.0 configured as default C++ compiler
- [x] ARM cross-compiler installed (`gcc-arm-none-eabi`, `libnewlib-arm-none-eabi`)
- [x] Ninja build system installed (`ninja-build`)
- [x] CMake installed
- [x] Conda environment created (`smartgarden`, Python 3.12)
- [x] Python dependencies installed (`paho-mqtt`, `influxdb-client`, `asyncua`, `numpy`, `pandas`, `matplotlib`, `jupyter`)

### VS Code extensions

- [x] Raspberry Pi Pico (official)
- [x] C/C++ (Microsoft)
- [x] CMake Tools
- [x] Cortex-Debug
- [x] Python + Pylance
- [x] Jupyter
- [x] Remote SSH
- [x] GitLens
- [x] Claude Code

### Pico SDK and build pipeline

- [x] Pico SDK 2.3.0 downloaded and configured by VS Code extension
- [x] Project `pico-zone-controller` created targeting `pico2_w` (RP2350)
- [x] Source file converted from `.c` to `.cpp` (C++ project confirmed)
- [x] USB stdio enabled in CMakeLists.txt
- [x] Clean build confirmed from terminal (`[91/91]` steps, no errors)
- [x] Clean build confirmed from VS Code (`Ctrl+Shift+B`)
- [x] `.uf2` and `.elf` output files verified in `build/` folder

### Git and GitHub

- [x] SSH key generated and added to GitHub
- [x] `smart-garden` repository created on GitHub
- [x] SSH authentication verified (`ssh -T git@github.com`)
- [x] Local repo connected to remote (`git remote set-url`)
- [x] First push confirmed working

### Repository structure

- [x] `README.md` — full project plan, ISA-95 architecture, hardware list, build phases
- [x] `PROGRESS.md` — this file
- [x] `hardware/bom.md` — bill of materials with Electrokit links and prices
- [x] `docs/wiring/` — ISA-95 wiring diagram (dark/light mode compatible)
- [x] `firmware/pico-zone-controller/` — Pico 2W C++ project scaffold
- [ ] `docs/commissioning/pi5-setup.md` — Pi 5 headless setup guide (draft when Pi 5 arrives)

### Hardware ordered

- [x] Raspberry Pi 5 4GB — ordered
- [x] Raspberry Pi Pico 2WH × 2 — ordered
- [x] Capacitive soil moisture sensors × 3 (Adafruit STEMMA) — ordered
- [x] BME280 temperature/humidity/pressure — ordered
- [x] DS18B20 waterproof temperature × 2 — ordered
- [x] HX711 + 10kg load cell — ordered
- [x] Solenoid valves 12V × 2 — ordered
- [x] Pump 12V — ordered
- [x] Relay modules × 4 — ordered
- [x] 12V PSU — ordered
- [x] Buck converter (12V → 5V USB-C PD) — ordered
- [x] BH1750 light sensor — to order (Amazon.se)
- [x] YF-S201 flow sensor — to order (Amazon.se)
- [x] InnoMaker LA1010 logic analyser — to order (Amazon.de)
- [x] luxorparts soldering iron
- [x] UT161E multimeter

---

## Phase 1 — C++ foundations

**Goal:** Read all sensors and print values to USB serial. No WiFi yet.
**Status:** ⏳ Waiting for hardware delivery
**Prerequisite:** Hardware arrived and Pi 5 powered on

### Pico 2W setup

- [x] Flash first `.uf2` to Pico 2W (hold BOOTSEL, connect USB, drag and drop)
- [x] Verify USB serial output in VS Code terminal
- [x] Confirm `Hello World` prints correctly

### Sensor reading in C++

- [ ] Read soil moisture sensor #1 via I2C (GP0/GP1, address 0x36)
- [ ] Read soil moisture sensor #2 via I2C (GP2/GP3, address 0x37)
- [x] Read DS18B20 soil temperature via 1-Wire (GP4, 5.1kΩ pullup)
- [x] Read HX711 load cell (GP6 DOUT, GP7 SCK)
- [ ] Print all sensor readings to USB serial with labels and units

### Logic analyser

- [ ] Connect InnoMaker LA1010 to Ubuntu workstation
- [ ] Install KingstVIS software + Sigrok/PulseView as backup
- [ ] Verify I2C bus signals on soil moisture sensors (scope SDA/SCL)
- [ ] Verify 1-Wire signal on DS18B20
- [ ] Verify HX711 clock and data signals

### Milestone

- [ ] All sensors reading correctly, values printed to serial, waveforms verified on logic analyser

---

## Phase 2 — Control loop

**Goal:** Closed-loop PID irrigation control running on Pico 2W.
**Status:** ⬜ Not started
**Prerequisite:** Phase 1 complete

- [ ] Implement `PIDController` class in C++ (`pid_controller.cpp/.h`)
- [ ] Drive relay from GPIO (GP8 → valve, GP9 → pump)
- [ ] Confirm relay switching physically (LED or multimeter on relay output)
- [ ] Close the loop: moisture reading → PID → valve open/close
- [ ] Implement hardware watchdog (fail-safe valve close on hang)
- [ ] Tune PID gains (Kp, Ki, Kd) on a real pot of soil
- [ ] Test YF-S201 flow sensor with voltage divider (1kΩ + 2kΩ → GP10)

### Milestone

- [ ] Pot of soil autonomously maintained at target moisture setpoint

---

## Phase 3 — MQTT networking

**Goal:** Pico publishes sensor data to Pi 5 via MQTT over WiFi.
**Status:** ⬜ Not started
**Prerequisite:** Phase 2 complete, Pi 5 set up

### Pi 5 setup

- [x] Flash Raspberry Pi OS Lite (64-bit) to microSD
- [ ] Configure headless: hostname, SSH, WiFi via Raspberry Pi Imager
- [ ] First SSH connection from workstation (`ssh pi@smartgarden.local`)
- [ ] Install PREEMPT_RT kernel (`sudo apt install linux-image-rt-arm64`)
- [ ] Install Mosquitto MQTT broker
- [ ] Configure Remote SSH extension in VS Code

### Pico WiFi + MQTT in C++

- [ ] Connect Pico 2W to WiFi using CYW43 driver
- [ ] Implement MQTT publish using lightweight MQTT-C library
- [ ] Publish soil moisture, temperature, weight to MQTT topics
- [ ] Implement heartbeat topic (`garden/zone1/system/heartbeat`)
- [ ] Verify messages arriving at Mosquitto broker on Pi 5

### Milestone

- [ ] Full path confirmed: sensor → Pico C++ → WiFi → MQTT → Pi 5

---

## Phase 4 — Edge analytics stack

**Goal:** Full local monitoring stack running on Pi 5.
**Status:** ⬜ Not started
**Prerequisite:** Phase 3 complete

- [ ] Install InfluxDB v2 on Pi 5
- [ ] Write MQTT → InfluxDB bridge in Python (`mqtt_subscriber.py`)
- [ ] Verify sensor data appearing in InfluxDB
- [ ] Install Grafana on Pi 5
- [ ] Build live dashboard: soil moisture, weight, valve state, flow rate
- [ ] Read BME280 on Pi 5 GPIO (I2C1, GP2/GP3, address 0x77)
- [ ] Read BH1750 on Pi 5 GPIO (I2C0, GP4/GP5, address 0x23)
- [ ] Implement ET evapotranspiration model (`et_model.py`, FAO-56 Penman-Monteith)
- [ ] Push daily ET-based setpoints back to Picos via MQTT

### Milestone

- [ ] Live Grafana dashboard visible from workstation browser at `smartgarden.local:3000`

---

## Phase 5 — OPC UA server

**Goal:** Industrial-standard semantic data layer at the edge.
**Status:** ⬜ Not started
**Prerequisite:** Phase 4 complete

- [ ] Install asyncua on Pi 5 (`pip install asyncua`)
- [ ] Build OPC UA server with full Garden/Zone/Sensor address space hierarchy
- [ ] Bridge MQTT subscriber → OPC UA node updates in Python
- [ ] Connect UaExpert client from workstation — browse and verify address space
- [ ] Add engineering units, valid ranges, and timestamps to all nodes
- [ ] Make control setpoints writable via OPC UA (not just MQTT)
- [ ] Add Historical Data Access (HDA) — expose InfluxDB data via OPC UA history
- [ ] Configure OPC UA security (certificate-based auth, encrypted sessions)
- [ ] Publish to cloud via OPC UA PubSub over MQTT transport
- [ ] Install UaExpert on workstation (unified-automation.com)

### Milestone

- [ ] Full OPC UA address space browsable from UaExpert, HDA working, cloud publishing confirmed

---

## Phase 6 — Cloud + anomaly detection

**Goal:** Long-term storage in cloud, ML-based anomaly detection at edge.
**Status:** ⬜ Not started
**Prerequisite:** Phase 5 complete

- [ ] Set up free-tier InfluxDB Cloud or AWS IoT Core account
- [ ] Implement cloud push agent (`cloud_push.py`)
- [ ] Verify data appearing in cloud dashboard
- [ ] Build autoencoder anomaly detector on soil moisture time-series
- [ ] Train model on baseline sensor data (2+ weeks of normal operation)
- [ ] Deploy inference on Pi 5
- [ ] Set up Grafana alerts (anomaly flag, water delivery vs ET model mismatch)
- [ ] Validate YF-S201 flow measurement against ET model prediction

### Milestone

- [ ] Anomaly detection running live, cloud dashboard accessible remotely

---

## Phase 7 — Hardening and outdoor deployment

**Goal:** Reliable outdoor operation, permanent installation.
**Status:** ⬜ Not started
**Prerequisite:** Phase 6 complete, soldering iron acquired

- [ ] Order and receive Pinecil v2 soldering iron
- [ ] Learn soldering on practice kit before touching project components
- [ ] Design permanent stripboard wiring layout
- [ ] Solder permanent connections (replace breadboard)
- [ ] Install in weatherproof enclosure (IP65+, cable glands)
- [ ] UPS / battery backup for Pi 5
- [ ] Sensor calibration procedures documented (`docs/calibration/`)
- [ ] Verify PREEMPT_RT kernel latency improvement
- [ ] Long-term soak test (2+ weeks continuous operation)

### Milestone

- [ ] System running continuously outdoors, no manual intervention needed

---

## Deferred / future ideas

- Second Pico zone controller (Zone 2) — add once Zone 1 is stable
- Indoor air quality monitoring (SCD40 CO2 sensor)
- Energy monitoring (CT clamp on main panel)
- Home Assistant integration
- Valve monitoring extensions (actuator torque signatures, seat leakage detection)
- Mathematical pump/membrane performance models (transferable to professional work)
- Remote access via Tailscale or WireGuard VPN

---

## Hardware still to order

| Item | Source | Priority |
|---|---|---|
| BH1750 light sensor | Amazon.se | Before Phase 4 |
| YF-S201 flow sensor | Amazon.se | Before Phase 2 |
| InnoMaker LA1010 logic analyser | Amazon.de | Before Phase 1 |
| Voltage divider resistors (1kΩ, 2kΩ, 4.7kΩ) | Electrokit / local | Before Phase 1 |
| Pinecil v2 soldering iron | eleshop.eu | Before Phase 7 |
| UT139S multimeter (upgrade) | Electrokit | When ready |

---

## Tools and references

| Tool | Purpose | Status |
|---|---|---|
| VS Code + Pico extension | C++ firmware development | ✅ Ready |
| arm-none-eabi-g++ 15.2.1 | ARM cross-compiler | ✅ Ready |
| Pico SDK 2.3.0 | Pico 2W libraries | ✅ Ready |
| Conda `smartgarden` env | Python development | ✅ Ready |
| KingstVIS / Sigrok | Logic analyser software | ⬜ Install when LA1010 arrives |
| UaExpert | OPC UA client | ⬜ Install before Phase 5 |
| MQTT Explorer | MQTT debugging | ⬜ Install before Phase 3 |
| Remote SSH (VS Code) | Pi 5 remote development | ⬜ Configure when Pi 5 arrives |
| Mosquitto | MQTT broker on Pi 5 | ⬜ Install in Phase 3 |
| InfluxDB v2 | Time-series database | ⬜ Install in Phase 4 |
| Grafana | Dashboards | ⬜ Install in Phase 4 |
| asyncua | OPC UA server | ⬜ Install in Phase 5 |

---

## Phase 3b — Network security & packet analysis

**Goal:** Understand and implement OT/IT security — VLAN isolation, MQTT TLS, OS hardening, Wireshark packet analysis.
**Status:** ⬜ Not started
**Prerequisite:** Phase 3 MQTT networking complete
**Reference:** `docs/network/SECURITY_WORKSHEET.md`

### Network isolation
- [ ] Create IoT VLAN (192.168.10.0/24) on router
- [ ] Assign static IPs to both Picos (10.11, 10.12)
- [ ] Verify Picos cannot reach main LAN
- [ ] Verify Pi 5 bridges both VLANs

### MQTT TLS + certificates
- [ ] Generate CA, server, and per-Pico client certificates
- [ ] Configure Mosquitto: TLS only, no plain port 1883
- [ ] Configure Mosquitto ACL: Picos publish-only to their own topics
- [ ] Embed certificates in Pico firmware
- [ ] Test: plain connections refused, wrong-cert connections refused

### Pi 5 hardening
- [ ] UFW firewall — deny all inbound except SSH/MQTT/OPC UA from correct subnets
- [ ] SSH key-only (disable password auth)
- [ ] fail2ban
- [ ] unattended-upgrades
- [ ] Disable unused services

### Wireshark packet analysis (learning exercise)
- [ ] Install Wireshark on Ubuntu workstation
- [ ] Capture Pico → Pi 5 traffic
- [ ] Identify TCP handshake, TLS handshake, encrypted MQTT packets
- [ ] Decrypt MQTT packets using TLS session key
- [ ] Identify CONNECT, CONNACK, PUBLISH, PINGREQ packets
- [ ] Capture OPC UA traffic on port 4840
- [ ] Document findings in `docs/network/wireshark-notes.md`

### Milestone
- [ ] Wireshark capture shows encrypted traffic · nmap scan shows only expected ports · security worksheet Phase 3 section complete

---

## Updated tools list

| Tool | Purpose | Status |
|---|---|---|
| Wireshark | Packet capture and protocol analysis | ⬜ Install before Phase 3b |
| nmap | Network port scanning | ⬜ Install before Phase 3b |
| openssl | Certificate generation | ⬜ Available via apt |
| UFW | Pi 5 firewall | ⬜ Configure in Phase 3b |
| fail2ban | SSH brute force protection | ⬜ Configure in Phase 3b |
| MQTT Explorer | Visual MQTT debugging | ⬜ Install before Phase 3 |
| UaExpert | OPC UA address space browser | ⬜ Install before Phase 5 |

---

## Phase 8 — Asset database and web application

**Goal:** Full PLM/CMMS web app connecting ET asset data with live OT sensor readings.
**Status:** ⬜ Not started
**Prerequisite:** Phase 4 (InfluxDB running), Hetzner VPS provisioned

### Hetzner VPS setup
- [ ] Create Hetzner account (hetzner.com)
- [ ] Provision CX22 server — Ubuntu 24.04, Finnish or German datacenter
- [ ] SSH key added during provisioning
- [ ] SSH access confirmed from workstation
- [ ] Domain name pointed to VPS IP (optional but recommended)
- [ ] UFW firewall configured (allow 22, 80, 443 only)
- [ ] Nginx reverse proxy installed (routes HTTPS to FastAPI)
- [ ] SSL certificate via Let's Encrypt (certbot)

### PostgreSQL asset database
- [ ] Install PostgreSQL on Hetzner VPS
- [ ] Create `smartgarden` database and user
- [ ] Run `docs/database/schema.sql` — creates all tables, views, indexes
- [ ] Verify seed data loaded (all project assets in registry)
- [ ] Add remaining asset documents (datasheets, manuals) to asset_documents table
- [ ] Add wiring connections to asset_connections table
- [ ] Test views: `active_assets_by_zone`, `connection_map`, `maintenance_due`

### FastAPI backend
- [ ] Create `webapp/` folder in repo
- [ ] Set up FastAPI project with Jinja2 templates
- [ ] Install dependencies: `pip install fastapi uvicorn jinja2 asyncpg plotly python-dotenv`
- [ ] Database connection via asyncpg (async PostgreSQL driver)
- [ ] InfluxDB connection for time-series queries
- [ ] REST API endpoints:
  - [ ] `GET /api/assets` — all assets
  - [ ] `GET /api/assets/{tag}` — single asset with documents and connections
  - [ ] `GET /api/sensor/{zone}/{measurement}` — latest reading from InfluxDB
  - [ ] `GET /api/sensor/{zone}/{measurement}/history` — time-series from InfluxDB
  - [ ] `POST /api/maintenance` — log a maintenance event
  - [ ] `GET /api/alerts` — active unresolved alerts

### HTMX frontend
- [ ] Base template with navigation (`base.html`)
- [ ] Dashboard page — live sensor cards updating every 5s via HTMX
- [ ] Asset registry page — table of all assets, filterable by zone/type
- [ ] Asset detail page — specs, documents, connection map, live reading, maintenance history
- [ ] Analytics page — Plotly time-series charts for all sensor streams
- [ ] Maintenance log page — form to log events, upcoming schedule

### Integration — OT/IT/ET link
- [ ] Each asset record linked to OPC UA node ID
- [ ] Each asset record linked to InfluxDB measurement tag
- [ ] Asset detail page shows live reading pulled from InfluxDB via API
- [ ] Anomaly alerts from ML model written to asset_alerts table
- [ ] Alert badge shown on asset in registry when active alert exists

### Milestone
- [ ] Web app publicly accessible via HTTPS on Hetzner VPS
- [ ] All project assets in database with datasheets linked
- [ ] Live sensor dashboard updating without page reload
- [ ] At least one maintenance event logged per asset

---

## Phase 9 — Portfolio Website & Access Control

**Goal:** Build a personal portfolio website that showcases this project and others. The smart garden web app sits under it as a live demo. Private by default, shareable via time-limited links for recruitment and client demos.
**Status:** ⬜ Not started
**Prerequisite:** Phase 8 (web app running on Hetzner VPS)

### Default — private
- [ ] Enable nginx HTTP Basic Auth on all routes
- [ ] Generate strong password: `htpasswd -c /etc/nginx/.htpasswd yourname`
- [ ] Verify app is inaccessible without credentials
- [ ] Document credentials securely (password manager)

### Time-limited token access
- [ ] Add `access_tokens` table to PostgreSQL (already in schema.sql)
- [ ] FastAPI middleware that checks token query parameter on every request
- [ ] Token bypasses Basic Auth — direct link works without password
- [ ] Expired or revoked tokens redirect to a clean "link expired" page
- [ ] `accessed_count` and `last_accessed` updated on every token request

### Token management CLI
- [ ] Simple Python script to generate a token:
      `python manage.py create-token --label "ABB interview" --days 14`
- [ ] Script to list all active tokens with expiry and access count
- [ ] Script to revoke a token immediately:
      `python manage.py revoke-token --label "ABB interview"`

### Subdomain / domain integration
- [ ] Decide: subdirectory (`yourname.com/projects/smart-garden`) or subdomain (`smartgarden.yourname.com`)
- [ ] Configure nginx reverse proxy or DNS CNAME accordingly
- [ ] Update FastAPI `root_path` if using subdirectory
- [ ] SSL certificate covers the new subdomain/path (Let's Encrypt)
- [ ] Test: public URL resolves correctly, Basic Auth prompts

### Milestone
- [ ] App private by default — returns 401 without credentials
- [ ] Generate a 7-day token and verify it works as a direct link
- [ ] Token expires and shows "link expired" page
- [ ] Access log shows count and timestamp of recruiter visits

### Personal portfolio website
- [ ] Design site structure:
      `yourname.com` — landing page, about, skills, CV
      `yourname.com/projects` — projects overview
      `yourname.com/projects/smart-garden` — this project (live demo)
- [ ] Choose stack: FastAPI + Jinja2 (same as web app, one codebase) or static site generator (Hugo, Astro)
- [ ] Write content: about, skills summary, project descriptions
- [ ] Link CV PDF for download
- [ ] Link GitHub repos
- [ ] Deploy on same Hetzner VPS alongside the smart garden app
- [ ] Custom domain pointing to Hetzner VPS
- [ ] SSL certificate covers all subdomains/paths
