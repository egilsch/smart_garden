# System Architecture

Full stack architecture for the Smart Garden IIoT platform.
Built to mirror real industrial systems across OT, IT, and ET domains.

---

## Design philosophy

This project deliberately mirrors the architecture of real industrial IIoT systems:

- **OT layer** — field devices, sensors, actuators, real-time control
- **ET layer** — engineering data, asset registry, documentation, PLM
- **IT layer** — databases, APIs, web applications, cloud services

The goal is not just to monitor a garden — it is to build a system that demonstrates
the full OT/IT/ET integration stack that industrial companies are actively building
and struggling to find engineers who understand end to end.

---

## Full stack overview

```
┌─────────────────────────────────────────────────────────────┐
│  OT LAYER — Field devices                                   │
│                                                             │
│  Pico 2WH Zone 1          Pico 2WH Zone 2                  │
│  192.168.10.11             192.168.10.12                    │
│  Bare-metal C++            Bare-metal C++                   │
│  PID control loop          PID control loop                 │
│  MQTT over TLS 1.3         MQTT over TLS 1.3                │
└──────────────────┬──────────────────────┬───────────────────┘
                   │  WiFi / MQTT TLS     │
                   │  port 8883           │
┌──────────────────▼──────────────────────▼───────────────────┐
│  EDGE LAYER — Raspberry Pi 5 (192.168.1.100)                │
│                                                             │
│  Mosquitto MQTT broker (port 8883, TLS only)                │
│  InfluxDB v2 (port 8086, localhost only)                    │
│  OPC UA server / asyncua (port 4840)                        │
│  MQTT→InfluxDB bridge (Python)                              │
│  MQTT→OPC UA bridge (Python)                                │
│  ET model / anomaly detection (Python)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │  HTTPS / OPC UA PubSub
                           │  outbound only
┌──────────────────────────▼──────────────────────────────────┐
│  IT LAYER — Hetzner VPS CX22 (public IP)                    │
│                                                             │
│  PostgreSQL — asset database (ET layer)                     │
│  FastAPI — REST API + web server                            │
│  Jinja2 + HTMX — server-rendered reactive UI               │
│  Plotly — interactive engineering charts                     │
│                                                             │
│  Web app routes:                                            │
│  /             — live dashboard (sensor readings)           │
│  /assets       — asset registry (PLM/material master)       │
│  /analytics    — time-series charts, ET model, anomaly      │
│  /maintenance  — maintenance log and schedule               │
│  /network      — system health, device status               │
└─────────────────────────────────────────────────────────────┘
```

---

## Protocol map

| From | To | Protocol | Port | Auth | Direction |
|---|---|---|---|---|---|
| Pico 2W | Pi 5 Mosquitto | MQTT over TLS 1.3 | 8883 | Client cert + ACL | Pico → Pi 5 only |
| Pi 5 | InfluxDB | HTTP (localhost) | 8086 | Scoped API token | Internal only |
| Pi 5 | OPC UA clients | OPC UA TCP | 4840 | Certificate + SignAndEncrypt | LAN only |
| Pi 5 | Hetzner VPS | HTTPS | 443 | API token | Pi 5 → VPS only |
| Browser | Hetzner VPS | HTTPS | 443 | Session auth | Public (HTTPS) |
| VS Code | Pi 5 | SSH | 22 | Key only | LAN only |

---

## Why HTMX over React

The frontend uses **FastAPI + Jinja2 + HTMX** rather than React for these reasons:

- Entire stack stays in Python — no JavaScript build toolchain
- HTMX enables live-updating UI with zero JavaScript (server sends HTML fragments)
- FastAPI backend stays identical if React is added later — clean separation
- Faster to build, easier to maintain, appropriate for an engineering tool
- HTMX is actively gaining adoption in industrial/engineering web tooling

React remains an option later — same FastAPI backend, swap the templates.

---

## Why Hetzner over AWS

- **Cost:** CX22 at €4.51/month vs unpredictable AWS bills
- **Simplicity:** Ubuntu 24.04, same commands as Pi 5 and workstation
- **Control:** you configure everything yourself — more learning, more credibility
- **European datacenter:** GDPR compliant, low latency from Norway
- **Vendor independence:** skills transfer to any VPS provider

---

## OPC UA information model

The OPC UA server on the Pi 5 structures all data into a typed, browsable hierarchy.
This is the ET/OT bridge — engineering asset data combined with live operational data.

```
SmartGarden/  (namespace: urn:smartgarden:opcua)
│
├── Site/
│   ├── Location        [String] "Geelong, VIC, Australia"
│   └── Description     [String] "Smart Garden IIoT Platform"
│
├── Zone1/
│   ├── AssetId         [String] "SG-ZONE-001"
│   ├── Description     [String] "Tomato bed — Zone 1"
│   ├── CropType        [String] "Tomatoes"
│   ├── CropCoefficient [Float]  1.15
│   │
│   ├── SoilMoisture/
│   │   ├── Sensor1     [Float, %, 0-100] live from MQTT
│   │   └── Sensor2     [Float, %, 0-100] live from MQTT
│   │
│   ├── SoilTemperature [Float, °C] live from MQTT
│   ├── Weight/
│   │   ├── Raw         [Float, kg]
│   │   └── Delta       [Float, kg/hr]
│   ├── FlowRate        [Float, L/min]
│   │
│   ├── Valve/
│   │   ├── State       [Boolean] open/closed
│   │   └── AssetId     [String] "SG-VALVE-001"
│   │
│   └── Control/
│       ├── Setpoint    [Float, %] writable by OPC UA clients
│       ├── Mode        [String]   auto/manual/off
│       └── ETDemand    [Float, mm/day] from ET model
│
├── Zone2/              (same structure, minus load cell)
│
├── Environment/
│   ├── Air/
│   │   ├── Temperature [Float, °C]
│   │   ├── Humidity    [Float, %]
│   │   └── Pressure    [Float, hPa]
│   └── Light/
│       └── Lux         [Float, lx]
│
└── System/
    ├── Pi5/
    │   ├── Uptime      [UInt32, s]
    │   ├── CPUTemp     [Float, °C]
    │   └── MemFree     [UInt32, MB]
    ├── Zone1Controller/
    │   ├── AssetId     [String] "SG-PICO-001"
    │   ├── Firmware    [String] version
    │   └── Heartbeat   [DateTime]
    └── Zone2Controller/
        ├── AssetId     [String] "SG-PICO-002"
        ├── Firmware    [String] version
        └── Heartbeat   [DateTime]
```

---

## Asset tagging convention

All physical assets get a unique tag following this structure:

```
SG-{TYPE}-{NUMBER}

SG = Smart Garden (project prefix)
TYPE = component type code (see below)
NUMBER = zero-padded 3-digit sequence
```

| Type code | Component type | Example |
|---|---|---|
| PICO | Pico 2WH microcontroller | SG-PICO-001 |
| PI | Raspberry Pi | SG-PI-001 |
| SENSOR-SOIL | Soil moisture sensor | SG-SENSOR-SOIL-001 |
| SENSOR-TEMP | Temperature sensor | SG-SENSOR-TEMP-001 |
| SENSOR-LIGHT | Light sensor | SG-SENSOR-LIGHT-001 |
| SENSOR-PRES | Pressure sensor | SG-SENSOR-PRES-001 |
| SENSOR-FLOW | Flow sensor | SG-SENSOR-FLOW-001 |
| SENSOR-WEIGHT | Load cell / weight | SG-SENSOR-WEIGHT-001 |
| VALVE | Solenoid valve | SG-VALVE-001 |
| PUMP | Water pump | SG-PUMP-001 |
| RELAY | Relay module | SG-RELAY-001 |
| PSU | Power supply unit | SG-PSU-001 |
| BUCK | Buck converter | SG-BUCK-001 |
| CABLE | Cable assembly | SG-CABLE-001 |

---

## Data flow — end to end

```
Physical sensor (Level 0)
    │ electrical signal
    ▼
Pico 2W GPIO (Level 1)
    │ I2C / 1-Wire / GPIO read in C++
    │ PID compute → relay switch
    ▼
MQTT publish over TLS (Level 2→3)
    topic: garden/zone1/soil/moisture1
    payload: 67.3
    ▼
Mosquitto broker on Pi 5 (Level 3)
    │
    ├── MQTT→InfluxDB bridge
    │       stores: measurement=soil, tag=zone1, field=moisture1, value=67.3
    │
    └── MQTT→OPC UA bridge
            updates: SmartGarden/Zone1/SoilMoisture/Sensor1 = 67.3
                     with timestamp, engineering units, quality flag
    ▼
FastAPI on Hetzner VPS
    GET /api/sensor/zone1/moisture
    → queries InfluxDB via HTTPS
    → returns JSON time-series
    ▼
HTMX in browser
    polls /api/sensor/zone1/moisture every 5s
    → Plotly renders live chart
    → no page reload needed
```

---

## Technology decisions log

| Decision | Rationale |
|---|---|
| MQTT not HTTP for field devices | Lightweight, fire-and-forget, perfect for constrained MCUs |
| OPC UA at edge not cloud | Semantic model belongs at the data source, not in the cloud |
| InfluxDB not PostgreSQL for time-series | Optimised for time-series — compression, retention, fast queries |
| PostgreSQL not InfluxDB for assets | Relational data with foreign keys — wrong fit for time-series DB |
| FastAPI not Flask | Async, automatic API docs, type hints — better for API-first design |
| HTMX not React | Stays in Python, reactive without JS build toolchain, same backend if React added later |
| Plotly not Recharts | Python-native, excellent engineering chart types, no JS required |
| Hetzner not AWS | Cost, control, learning value, European datacenter |
| Pi 5 not cloud for edge | Low latency, data sovereignty, no cloud dependency for core function |
