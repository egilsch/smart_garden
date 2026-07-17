# 🌱 Smart Garden — Autonomous Precision Irrigation & Monitoring System

A full-stack IIoT project built as a deliberate learning platform for industrial automation, embedded C++, edge computing, and data-driven control. Every phase is built and understood before moving to the next.

> **Status:** Hardware procurement in progress — Phase 1 not started

---

## What this is

An autonomous garden irrigation system that uses closed-loop soil moisture control, a physics-based evapotranspiration (ET) model for feedforward prediction, and a full edge-to-cloud data stack. Built on the same architectural principles as industrial IIoT systems: field devices talk MQTT, an edge node aggregates and analyses, and cloud handles long-term storage and remote access.

---

## System layers

```
FIELD LAYER (OT)
  Pico 2W × 2 — bare-metal C++, real-time PID control
  Sensors: soil moisture, temperature, load cell, flow, light
  Actuators: solenoid valves, pump (via relay, 12V)

      ↕ WiFi / MQTT

EDGE LAYER (IT + OT)
  Raspberry Pi 5 4GB — headless Linux, PREEMPT_RT kernel
  Mosquitto (MQTT broker) · InfluxDB (time-series) · Grafana (dashboards)
  Python: ET model, anomaly detection, cloud push agent

      ↕ HTTPS

CLOUD LAYER (IT)
  InfluxDB Cloud / AWS IoT Core
  Long-term storage · remote dashboard · alerts
```

---

## Hardware

### Compute

| Component | Role |
|---|---|
| Raspberry Pi 5 4GB | Edge gateway, all server-side software |
| Raspberry Pi Pico 2WH × 2 | Field controllers (C++ bare-metal, WiFi) |

### Sensors

| Sensor | Qty | Measures | Interface | Note |
|---|---|---|---|---|
| Capacitive soil moisture (Adafruit STEMMA) | 4 | Soil water content % | I2C 3.3V | Address 0x36 / 0x37 |
| BME280 (Adafruit) | 1 | Air temp, humidity, pressure | I2C 3.3V | On Pi 5, address 0x77 |
| DS18B20 waterproof | 2 | Soil temperature | 1-Wire 3.3V | 4.7kΩ pullup to 3V3 |
| HX711 + 10kg load cell | 1 | Pot weight (soil water proxy) | GPIO 2-wire | Strain gauge bridge |
| BH1750 | 1 | Light intensity (lux) | I2C 3.3V | On Pi 5, address 0x23 |
| YF-S201 flow sensor | 1 | Water volume delivered | GPIO pulse | ⚠️ 5V signal → needs voltage divider |

### Actuation

| Component | Qty | Role | Switched by |
|---|---|---|---|
| Solenoid valve 12V ½" 8bar (NC) | 2 | Zone on/off | Relay module |
| Fluid pump 12V | 1 | Move water from tank | Relay module |
| Relay module 5V | 4 | Switch 12V loads from 3.3V GPIO | Pico GPIO |

---

## Power architecture

Single mains socket → one 12V PSU → everything:

```
230V (1 socket)
      ↓
12V 5–8A PSU
      ├── 12V rail → valves, pump (via relay)
      └── Buck converter (12V → 5V USB-C PD) → Pi 5, Pico ×2, sensors
```

**Pi 5 note:** requires a buck converter with USB-C PD trigger chip, or wire 5.1V directly to GPIO pins 2/4 and set `usb_max_current_enable=1` in Pi config.

---

## Wiring — key connections

### Pico 2W GPIO

| GPIO | Connected to | Protocol |
|---|---|---|
| GP0/GP1 | Soil moisture sensor #1 (SDA/SCL) | I2C bus 0 |
| GP2/GP3 | Soil moisture sensor #2 (SDA/SCL) | I2C bus 1 |
| GP4 | DS18B20 soil temp (+ 4.7kΩ to 3V3) | 1-Wire |
| GP6 | HX711 DOUT (load cell data) | GPIO |
| GP7 | HX711 SCK (load cell clock) | GPIO |
| GP8 | Relay IN1 → solenoid valve | GPIO |
| GP9 | Relay IN2 → pump | GPIO |
| GP10 | YF-S201 signal (via voltage divider) | GPIO pulse |

### Raspberry Pi 5 GPIO

| GPIO | Connected to | Protocol |
|---|---|---|
| GP2/GP3 | BME280 (SDA/SCL) | I2C bus 1 |
| GP4/GP5 | BH1750 (SDA/SCL) | I2C bus 0 |

### Voltage divider — YF-S201 (5V → 3.3V)

YF-S201 outputs 5V pulses; Pico GPIO is 3.3V max. Solution:

```
YF-S201 signal (5V)
      |
    [1kΩ]
      |
      ├──► Pico GP10
      |
    [2kΩ]
      |
     GND

Output = 5V × (2k / 3k) = 3.33V ✅
```

---

## Control model

### Evapotranspiration (ET) — feedforward

A simplified FAO-56 Penman-Monteith model runs daily on the Pi 5. It pulls weather data from the free Open-Meteo API (no key needed) and predicts how much water each zone will need based on temperature, humidity, solar radiation, and wind speed. Each zone has a configurable crop coefficient (Kc) that scales the demand to the specific plant type.

```
Zone 1 (Tomatoes): Kc = 1.15
Zone 2 (Herbs):    Kc = 0.70
```

This becomes the **feedforward** component — the system anticipates water demand rather than purely reacting to dry soil.

### PID — feedback correction

A PID controller runs on each Pico 2W at a fixed cycle time (default 60s). It reads soil moisture, computes the error from the setpoint, and drives the valve open for a calculated number of seconds. This corrects for everything the ET model doesn't capture: soil type variation, root depth, microclimatic differences.

```
Error  = target_moisture − measured_moisture
Output = Kp×error + Ki×∫error + Kd×d(error)/dt
       → valve_open_time (seconds)
```

### Watchdog

The Pico 2W includes a hardware watchdog that closes valves and shuts off the pump if it stops receiving heartbeats from the Pi 5. Valves fail to their safe state (normally closed) without any software intervention. This mirrors real industrial practice.

---

## MQTT topic structure

All field data flows through Mosquitto on the Pi 5:

```
garden/zone1/soil/moisture1     → float (%)
garden/zone1/soil/temperature   → float (°C)
garden/zone1/weight/raw         → float (kg)
garden/zone1/valve/state        → "open" / "closed"
garden/zone1/system/heartbeat   → unix timestamp
garden/zone2/flow/rate          → float (L/min)
garden/environment/air/temp     → float (°C)
garden/environment/light/lux    → float (lx)
garden/environment/et/daily_demand → float (mm/day)

Pi 5 → Pico:
garden/zone1/control/setpoint   → float (target moisture %)
garden/zone1/control/mode       → "auto" / "manual" / "off"
```

---

## Build phases

### Phase 1 — Foundations (weeks 1–4)
Learn the Pico SDK and C++ on hardware. No WiFi yet.
- [ ] Toolchain setup (cmake, arm-none-eabi-gcc)
- [ ] Blink an LED in C++
- [ ] Read soil moisture sensor via I2C
- [ ] Read DS18B20 via 1-Wire
- [ ] Read HX711 load cell
- [ ] Print all sensor values to USB serial

### Phase 2 — Control loop (weeks 4–8)
Build and tune the core control logic.
- [ ] Implement PID controller class in C++
- [ ] Drive relay from GPIO (valve open/close)
- [ ] Close the loop: sensor → PID → valve
- [ ] Implement hardware watchdog (fail-safe close)
- [ ] Tune PID gains on a real pot of soil

### Phase 3 — Networking (weeks 8–12)
Connect field devices to the edge.
- [ ] Connect Pico 2W to WiFi in C++
- [ ] Publish sensor data via MQTT
- [ ] Pi 5 headless setup + Mosquitto install
- [ ] Verify full path: sensor → MQTT → Pi 5

### Phase 4 — Edge analytics (weeks 12–16)
Full local monitoring stack.
- [ ] InfluxDB install + MQTT→InfluxDB bridge in Python
- [ ] Grafana dashboard (live soil moisture, weight, valve state)
- [ ] Read BME280 + BH1750 on Pi 5 GPIO
- [ ] ET model running daily, setpoints pushed to Picos via MQTT

### Phase 5 — Cloud + anomaly detection (weeks 16–24)
Extend to cloud, add ML layer.
- [ ] Cloud push agent (InfluxDB Cloud or AWS IoT free tier)
- [ ] Autoencoder anomaly detector on sensor time-series
- [ ] Grafana alerts (anomaly flag, water delivery mismatch)
- [ ] Validate YF-S201 flow measurement against ET model prediction

### Phase 6 — Hardening (ongoing)
Make it robust enough to leave running.
- [ ] PREEMPT_RT kernel on Pi 5
- [ ] Weatherproof enclosure (IP65+, cable glands)
- [ ] Permanent stripboard wiring (replace breadboard)
- [ ] Sensor calibration documentation
- [ ] UPS / battery backup for Pi 5

---

## Repository structure

```
smart-garden/
├── README.md
├── docs/
│   ├── wiring/          Detailed wiring diagrams
│   ├── calibration/     Sensor calibration procedures
│   ├── commissioning/   Pi 5 and Pico toolchain setup guides
│   └── build-log.md     Running notes as the project develops
├── hardware/
│   └── bom.md           Full bill of materials with links and prices
├── firmware/
│   └── pico_zone_controller/   C++ firmware (built phase by phase)
├── edge/
│   └── scripts/         Python: ET model, MQTT bridge, anomaly detection
├── analytics/
│   └── notebooks/       Jupyter notebooks for exploration
└── cloud/               Cloud configuration
```

---

## What this teaches

| Skill | How |
|---|---|
| C++ on embedded hardware | Pico SDK, bare-metal, no OS, real memory management |
| Real-time control | PID loop on RP2350, deterministic timing, hardware watchdog |
| Industrial comms | MQTT field→edge, I2C, 1-Wire, GPIO pulse |
| Physics-based modelling | ET model with parameterisable Kc — same pattern as pump/membrane modelling |
| Edge-to-cloud architecture | OT (Pico) → IT (Pi 5) → Cloud — mirrors industrial IIoT stack |
| Time-series analytics | InfluxDB, Grafana, anomaly detection on live sensor data |
| MLOps at edge | Autoencoder trained on sensor streams, inference on Pi 5 |
| Agile delivery | Phased build — each phase is a working, testable system |

---

## Hardware bill of materials

See [`hardware/bom.md`](hardware/bom.md) for full component list with Electrokit links and prices.

---

*Built in Norway. Future deployment target: Geelong, Victoria, Australia.*
