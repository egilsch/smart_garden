# 🌱 Smart Garden — Autonomous Precision Irrigation & Monitoring System

A full-stack IIoT project built as a deliberate learning platform for industrial automation, embedded C++, edge computing, OPC UA, and data-driven control. Every phase is built and understood before moving to the next.

> **Status:** Hardware procurement in progress — Phase 1 not started

---

## What this is

An autonomous garden irrigation system that uses closed-loop soil moisture control, a physics-based evapotranspiration (ET) model for feedforward prediction, and a full edge-to-cloud data stack. Built on the same architectural principles as industrial IIoT systems: field devices talk MQTT at the OT layer, an OPC UA server at the edge structures and exposes data to the IT layer, and cloud handles long-term storage and remote access.

---

## System layers (ISA-95)

```
ISA-95 Level 0 — Physical process
  The garden itself: soil, plants, water, sunlight

ISA-95 Level 1 — Basic control (field devices)
  Sensors: soil moisture, temperature, load cell, flow, light, pressure
  Actuators: solenoid valves, pump (12V via relay)

      ↕ GPIO / I2C / 1-Wire

ISA-95 Level 2 — Supervisory control (Pico 2W × 2)
  Bare-metal C++, real-time PID control loops
  Hardware watchdog — valves fail safe on timeout

      ↕ WiFi / MQTT (lightweight OT transport)

ISA-95 Level 3 — Operations / MES (Raspberry Pi 5)
  Mosquitto MQTT broker · InfluxDB · Grafana
  OPC UA server (asyncua) — structured address space
  ET evapotranspiration model · anomaly detection

      ↕ OPC UA over MQTT (PubSub) / OPC UA TCP → cloud gateway

ISA-95 Level 4 — Enterprise / cloud
  InfluxDB Cloud / AWS IoT Core
  Long-term storage · remote dashboards · alerts
```

---

## Protocol architecture — why MQTT and OPC UA together

These two protocols are complementary, not competing. They operate at different layers and serve different purposes:

| | MQTT | OPC UA |
|---|---|---|
| **Role** | Transport — moves raw data efficiently | Semantic layer — defines what the data means |
| **Used by** | Pico 2W field devices | Pi 5 edge server |
| **Strength** | Lightweight, low-power, fire-and-forget | Structured, typed, secure, interoperable |
| **Data model** | Topics and payloads (no inherent meaning) | Nodes, variables, namespaces, engineering units |
| **Security** | Basic (TLS optional) | Certificate-based auth + encrypted sessions built in |
| **Industrial role** | Field bus / sensor-to-edge | Edge-to-SCADA / edge-to-cloud standard |

**Flow:** Pico → MQTT → Pi 5 (MQTT broker) → OPC UA server → cloud

The OPC UA server on the Pi 5 subscribes to MQTT topics from the Picos, maps the raw values into a structured OPC UA address space, and exposes them to any OPC UA client — a laptop running UaExpert, a cloud gateway, or a SCADA system — without any bespoke integration work.

---

## OPC UA address space

The OPC UA server organises all garden data into a typed, browsable hierarchy:

```
Garden/
├── Zone1/
│   ├── SoilMoisture/
│   │   ├── Sensor1   [Float, %, 0–100, updated from MQTT]
│   │   └── Sensor2   [Float, %, 0–100]
│   ├── SoilTemperature   [Float, °C]
│   ├── Weight/
│   │   ├── Raw       [Float, kg]
│   │   └── Delta     [Float, kg — change since last reading]
│   ├── FlowRate      [Float, L/min]
│   ├── Valve/
│   │   └── State     [Boolean — open/closed]
│   └── Control/
│       ├── Setpoint  [Float, % — writable by OPC UA clients]
│       └── Mode      [String — auto/manual/off]
├── Zone2/
│   └── [same structure minus load cell]
└── Environment/
    ├── Air/
    │   ├── Temperature   [Float, °C]
    │   ├── Humidity      [Float, %]
    │   └── Pressure      [Float, hPa]
    ├── Light/
    │   └── Lux           [Float, lx]
    └── ET/
        └── DailyDemand   [Float, mm/day]
```

Each node carries metadata: datatype, engineering units, valid range, timestamp, and source (sensor or calculated). This is what OPC UA adds over raw MQTT topics — meaning, not just values.

---

## Hardware

### Compute

| Component | Role |
|---|---|
| Raspberry Pi 5 4GB | Edge gateway, MQTT broker, OPC UA server, analytics |
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

A simplified FAO-56 Penman-Monteith model runs daily on the Pi 5, pulling weather data from the free Open-Meteo API. Each zone has a configurable crop coefficient (Kc):

```
Zone 1 (Tomatoes): Kc = 1.15
Zone 2 (Herbs):    Kc = 0.70
```

### PID — feedback correction

A PID controller on each Pico 2W corrects for model error at a fixed cycle time (default 60s):

```
Error  = target_moisture − measured_moisture
Output = Kp×error + Ki×∫error + Kd×d(error)/dt
       → valve_open_time (seconds)
```

### Watchdog

Hardware watchdog on each Pico 2W closes valves and stops the pump if the Pi 5 heartbeat is lost. Valves fail to normally-closed (safe state) without software intervention.

---

## MQTT topic structure

```
garden/zone1/soil/moisture1        → float (%)
garden/zone1/soil/temperature      → float (°C)
garden/zone1/weight/raw            → float (kg)
garden/zone1/valve/state           → "open" / "closed"
garden/zone1/flow/rate             → float (L/min)
garden/zone1/system/heartbeat      → unix timestamp
garden/zone2/soil/moisture1        → float (%)
garden/environment/air/temp        → float (°C)
garden/environment/light/lux       → float (lx)
garden/environment/et/daily_demand → float (mm/day)

Pi 5 → Pico (control):
garden/zone1/control/setpoint      → float (target moisture %)
garden/zone1/control/mode          → "auto" / "manual" / "off"
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

### Phase 3 — MQTT networking (weeks 8–12)
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

### Phase 5 — OPC UA server (weeks 16–22)
Add industrial-standard data layer at the edge.
- [ ] Install asyncua library on Pi 5 (`pip install asyncua`)
- [ ] Build OPC UA server with structured address space (Garden/Zone1/... hierarchy)
- [ ] Bridge MQTT subscriber → OPC UA node updates in Python
- [ ] Connect UaExpert client from laptop — browse and verify address space
- [ ] Add engineering units, valid ranges, and timestamps to all nodes
- [ ] Make control setpoints writable via OPC UA (not just MQTT)
- [ ] Add Historical Data Access (HDA) — expose InfluxDB data via OPC UA history
- [ ] Configure OPC UA security — certificate-based auth and encrypted sessions
- [ ] Publish to cloud via OPC UA PubSub over MQTT transport

### Phase 6 — Cloud + anomaly detection (weeks 22–28)
Extend to cloud, add ML layer.
- [ ] Cloud push agent (InfluxDB Cloud or AWS IoT free tier)
- [ ] Autoencoder anomaly detector on sensor time-series
- [ ] Grafana alerts (anomaly flag, water delivery mismatch)
- [ ] Validate YF-S201 flow measurement against ET model prediction

### Phase 7 — Hardening (ongoing)
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
│   ├── wiring/          Wiring diagrams (ISA-95 architecture)
│   ├── calibration/     Sensor calibration procedures
│   ├── commissioning/   Pi 5 and Pico toolchain setup guides
│   └── build-log.md     Running notes as the project develops
├── hardware/
│   └── bom.md           Full bill of materials with links and prices
├── firmware/
│   └── pico_zone_controller/   C++ firmware (built phase by phase)
├── edge/
│   └── scripts/         Python: ET model, MQTT bridge, OPC UA server, anomaly detection
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
| Industrial field protocols | MQTT, I2C, 1-Wire, GPIO pulse — OT layer communication |
| OPC UA | Server setup, address space design, security, HDA, PubSub — IT/OT bridge standard |
| Physics-based modelling | ET model with parameterisable Kc — same pattern as pump/membrane modelling |
| Edge-to-cloud architecture | OT (Pico/MQTT) → OPC UA (Pi 5) → Cloud — real industrial IIoT stack |
| Time-series analytics | InfluxDB, Grafana, anomaly detection on live sensor data |
| MLOps at edge | Autoencoder trained on sensor streams, inference on Pi 5 |
| Agile delivery | Phased build — each phase is a working, testable system |

---

## Hardware bill of materials

See [`hardware/bom.md`](hardware/bom.md) for full component list with Electrokit links and prices.

---

*Built in Norway. Future deployment target: Geelong, Victoria, Australia.*
