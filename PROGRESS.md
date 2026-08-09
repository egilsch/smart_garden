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
- [ ] Pinecil v2 soldering iron — deferred to Phase 6
- [ ] UT139S multimeter — deferred (using existing basic multimeter for now)

---

## Phase 1 — C++ foundations

**Goal:** Read all sensors and print values to USB serial. No WiFi yet.
**Status:** ⏳ Waiting for hardware delivery
**Prerequisite:** Hardware arrived and Pi 5 powered on

### Pico 2W setup

- [ ] Flash first `.uf2` to Pico 2W (hold BOOTSEL, connect USB, drag and drop)
- [ ] Verify USB serial output in VS Code terminal
- [ ] Confirm `Hello World` prints correctly

### Sensor reading in C++

- [ ] Read soil moisture sensor #1 via I2C (GP0/GP1, address 0x36)
- [ ] Read soil moisture sensor #2 via I2C (GP2/GP3, address 0x37)
- [ ] Read DS18B20 soil temperature via 1-Wire (GP4, 4.7kΩ pullup)
- [ ] Read HX711 load cell (GP6 DOUT, GP7 SCK)
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

- [ ] Flash Raspberry Pi OS Lite (64-bit) to microSD
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
