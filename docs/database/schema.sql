-- ============================================================
-- Smart Garden — Asset Database Schema
-- PostgreSQL on Hetzner VPS
--
-- This is the ET (Engineering Technology) layer:
-- structured asset data, documentation links, maintenance
-- history, and connections to live OT data via asset tags
-- that map to OPC UA nodes and InfluxDB measurements.
-- ============================================================

-- ============================================================
-- ASSET TYPES — reference table
-- ============================================================
CREATE TABLE asset_types (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(30) UNIQUE NOT NULL,  -- e.g. PICO, SENSOR-SOIL
    name            VARCHAR(100) NOT NULL,         -- e.g. Microcontroller
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO asset_types (code, name, description) VALUES
    ('PICO',          'Pico 2WH Microcontroller',  'RP2350 bare-metal C++ field controller'),
    ('PI',            'Raspberry Pi',               'Edge gateway and server'),
    ('SENSOR-SOIL',   'Soil Moisture Sensor',       'Capacitive I2C soil moisture'),
    ('SENSOR-TEMP',   'Temperature Sensor',         'DS18B20 waterproof 1-Wire'),
    ('SENSOR-LIGHT',  'Light Sensor',               'BH1750 I2C lux measurement'),
    ('SENSOR-PRES',   'Pressure/Humidity Sensor',   'BME280 I2C environment'),
    ('SENSOR-FLOW',   'Flow Sensor',                'YF-S201 hall effect pulse'),
    ('SENSOR-WEIGHT', 'Load Cell / Weight',         'HX711 + 10kg strain gauge'),
    ('VALVE',         'Solenoid Valve',             '12V NC solenoid valve'),
    ('PUMP',          'Water Pump',                 '12V submersible pump'),
    ('RELAY',         'Relay Module',               '5V relay module'),
    ('PSU',           'Power Supply Unit',          'DC power supply'),
    ('BUCK',          'Buck Converter',             'DC-DC step-down converter');

-- ============================================================
-- ASSETS — core asset registry (the material master)
-- ============================================================
CREATE TABLE assets (
    id                  SERIAL PRIMARY KEY,
    asset_tag           VARCHAR(50) UNIQUE NOT NULL,  -- e.g. SG-PICO-001
    asset_type_code     VARCHAR(30) REFERENCES asset_types(code),
    name                VARCHAR(200) NOT NULL,
    description         TEXT,

    -- Physical identification
    manufacturer        VARCHAR(100),
    model               VARCHAR(100),
    part_number         VARCHAR(100),
    serial_number       VARCHAR(100),

    -- Procurement
    supplier            VARCHAR(100),
    supplier_url        TEXT,
    purchase_date       DATE,
    purchase_price_nok  NUMERIC(10,2),
    currency            VARCHAR(3) DEFAULT 'NOK',

    -- Location and status
    location            VARCHAR(200),   -- e.g. Zone 1, Pi 5 enclosure
    zone                VARCHAR(50),    -- zone1, zone2, edge, cloud
    status              VARCHAR(20) DEFAULT 'active'
                        CHECK (status IN ('active','spare','failed','retired','ordered')),

    -- Installation
    installed_date      DATE,
    commissioned_date   DATE,

    -- Firmware / software (for programmable devices)
    firmware_version    VARCHAR(50),
    software_version    VARCHAR(50),

    -- OT/IT integration links
    -- These link the ET asset record to live operational data
    opcua_node_id       TEXT,     -- e.g. ns=2;s=SmartGarden/Zone1/SoilMoisture/Sensor1
    influxdb_tag        TEXT,     -- e.g. zone1_soil_moisture_1
    mqtt_topic          TEXT,     -- e.g. garden/zone1/soil/moisture1

    -- Reliability
    expected_lifetime_hours  INTEGER,
    maintenance_interval_days INTEGER,

    -- Metadata
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DOCUMENTS — datasheets, manuals, schematics per asset
-- ============================================================
CREATE TABLE asset_documents (
    id          SERIAL PRIMARY KEY,
    asset_id    INTEGER REFERENCES assets(id) ON DELETE CASCADE,
    doc_type    VARCHAR(50) NOT NULL
                CHECK (doc_type IN (
                    'datasheet','schematic','user_manual',
                    'supplier_page','application_note',
                    'photo','wiring_diagram','other'
                )),
    title       VARCHAR(200) NOT NULL,
    url         TEXT NOT NULL,
    notes       TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CONNECTIONS — how assets connect to each other
-- ============================================================
CREATE TABLE asset_connections (
    id                  SERIAL PRIMARY KEY,
    from_asset_id       INTEGER REFERENCES assets(id) ON DELETE CASCADE,
    to_asset_id         INTEGER REFERENCES assets(id) ON DELETE CASCADE,
    interface           VARCHAR(50) NOT NULL,  -- I2C, 1-Wire, GPIO, MQTT, USB, 12V
    from_pin            VARCHAR(50),            -- e.g. GP0 (SDA)
    to_pin              VARCHAR(50),            -- e.g. SDA
    signal_description  TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(from_asset_id, to_asset_id, interface, from_pin)
);

-- ============================================================
-- MAINTENANCE LOG — all maintenance events per asset
-- ============================================================
CREATE TABLE maintenance_log (
    id              SERIAL PRIMARY KEY,
    asset_id        INTEGER REFERENCES assets(id) ON DELETE CASCADE,
    event_date      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type      VARCHAR(50) NOT NULL
                    CHECK (event_type IN (
                        'inspection','replacement','repair',
                        'firmware_update','calibration',
                        'cleaning','commissioning','decommissioning',
                        'failure','other'
                    )),
    performed_by    VARCHAR(100),
    description     TEXT NOT NULL,
    findings        TEXT,
    next_due_date   DATE,
    labour_hours    NUMERIC(5,2),
    parts_cost_nok  NUMERIC(10,2),
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ALERTS — anomaly and condition alerts linked to assets
-- ============================================================
CREATE TABLE asset_alerts (
    id              SERIAL PRIMARY KEY,
    asset_id        INTEGER REFERENCES assets(id) ON DELETE CASCADE,
    alert_type      VARCHAR(50) NOT NULL
                    CHECK (alert_type IN (
                        'anomaly','threshold_high','threshold_low',
                        'communication_loss','rul_warning','maintenance_due',
                        'calibration_due','other'
                    )),
    severity        VARCHAR(20) DEFAULT 'warning'
                    CHECK (severity IN ('info','warning','critical')),
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    value           NUMERIC,        -- the value that triggered the alert
    threshold       NUMERIC,        -- the threshold that was breached
    triggered_at    TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(100),
    resolved_at     TIMESTAMPTZ,
    notes           TEXT
);

-- ============================================================
-- ZONES — physical zones in the system
-- ============================================================
CREATE TABLE zones (
    id              SERIAL PRIMARY KEY,
    zone_id         VARCHAR(20) UNIQUE NOT NULL,  -- zone1, zone2, edge
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    crop_type       VARCHAR(100),
    crop_coefficient NUMERIC(4,2),
    area_m2         NUMERIC(6,2),
    location        TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO zones (zone_id, name, description, crop_type, crop_coefficient, area_m2) VALUES
    ('zone1', 'Zone 1 — Tomatoes',  'Main tomato bed, south-facing', 'Tomatoes', 1.15, 0.25),
    ('zone2', 'Zone 2 — Herbs',     'Mixed herb bed',                'Herbs',    0.70, 0.15),
    ('edge',  'Edge — Pi 5',        'Raspberry Pi 5 enclosure',      NULL,       NULL, NULL);

-- ============================================================
-- SEED DATA — initial asset registry for the smart garden
-- ============================================================
INSERT INTO assets (
    asset_tag, asset_type_code, name, manufacturer, model,
    part_number, supplier, supplier_url,
    location, zone, status, installed_date,
    opcua_node_id, influxdb_tag, mqtt_topic, notes
) VALUES
(
    'SG-PI-001', 'PI',
    'Raspberry Pi 5 4GB — Edge Gateway',
    'Raspberry Pi Foundation', 'Raspberry Pi 5 4GB', 'SC1112',
    'Electrokit', 'https://www.electrokit.com/en/raspberry-pi-5-/4gb',
    'Edge enclosure', 'edge', 'active', NULL,
    'ns=2;s=SmartGarden/System/Pi5', NULL, NULL,
    'Headless Ubuntu 24.04 LTS. Runs Mosquitto, InfluxDB, OPC UA server, FastAPI.'
),
(
    'SG-PICO-001', 'PICO',
    'Pico 2WH — Zone 1 Controller',
    'Raspberry Pi Foundation', 'Raspberry Pi Pico 2W', 'SC1632',
    'Electrokit', 'https://www.electrokit.com/en/raspberry-pi-pico-2-wh',
    'Zone 1 enclosure', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/System/Zone1Controller', NULL, 'garden/zone1/system/heartbeat',
    'Bare-metal C++, PID zone 1 control, hardware watchdog.'
),
(
    'SG-PICO-002', 'PICO',
    'Pico 2WH — Zone 2 Controller',
    'Raspberry Pi Foundation', 'Raspberry Pi Pico 2W', 'SC1632',
    'Electrokit', 'https://www.electrokit.com/en/raspberry-pi-pico-2-wh',
    'Zone 2 enclosure', 'zone2', 'active', NULL,
    'ns=2;s=SmartGarden/System/Zone2Controller', NULL, 'garden/zone2/system/heartbeat',
    'Bare-metal C++, PID zone 2 control, hardware watchdog.'
),
(
    'SG-SENSOR-SOIL-001', 'SENSOR-SOIL',
    'Soil Moisture Sensor — Zone 1 Position 1',
    'Adafruit', 'STEMMA Soil Sensor', '4026',
    'Electrokit', 'https://www.electrokit.com/en/product/jordfuktighetssensor-kapacitiv-i2c/',
    'Zone 1 — pot 1', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/SoilMoisture/Sensor1',
    'zone1_soil_moisture_1', 'garden/zone1/soil/moisture1',
    'I2C address 0x36. Connected to SG-PICO-001 GP0/GP1.'
),
(
    'SG-SENSOR-SOIL-002', 'SENSOR-SOIL',
    'Soil Moisture Sensor — Zone 1 Position 2',
    'Adafruit', 'STEMMA Soil Sensor', '4026',
    'Electrokit', 'https://www.electrokit.com/en/product/jordfuktighetssensor-kapacitiv-i2c/',
    'Zone 1 — pot 2', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/SoilMoisture/Sensor2',
    'zone1_soil_moisture_2', 'garden/zone1/soil/moisture2',
    'I2C address 0x37. Connected to SG-PICO-001 GP2/GP3.'
),
(
    'SG-SENSOR-SOIL-003', 'SENSOR-SOIL',
    'Soil Moisture Sensor — Zone 2 Position 1',
    'Adafruit', 'STEMMA Soil Sensor', '4026',
    'Electrokit', 'https://www.electrokit.com/en/product/jordfuktighetssensor-kapacitiv-i2c/',
    'Zone 2 — pot 1', 'zone2', 'active', NULL,
    'ns=2;s=SmartGarden/Zone2/SoilMoisture/Sensor1',
    'zone2_soil_moisture_1', 'garden/zone2/soil/moisture1',
    'I2C address 0x36. Connected to SG-PICO-002 GP0/GP1.'
),
(
    'SG-SENSOR-TEMP-001', 'SENSOR-TEMP',
    'DS18B20 Waterproof Soil Temperature — Zone 1',
    'Dallas Semiconductor', 'DS18B20', 'DS18B20',
    'Electrokit', 'https://www.electrokit.com/en/temperatursensor-vattentat-ds18b20',
    'Zone 1 soil', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/SoilTemperature',
    'zone1_soil_temp', 'garden/zone1/soil/temperature',
    '1-Wire protocol. GP4 on SG-PICO-001. 5.1kΩ pullup to 3V3.'
),
(
    'SG-SENSOR-TEMP-002', 'SENSOR-TEMP',
    'DS18B20 Waterproof Soil Temperature — Zone 2',
    'Dallas Semiconductor', 'DS18B20', 'DS18B20',
    'Electrokit', 'https://www.electrokit.com/en/temperatursensor-vattentat-ds18b20',
    'Zone 2 soil', 'zone2', 'active', NULL,
    'ns=2;s=SmartGarden/Zone2/SoilTemperature',
    'zone2_soil_temp', 'garden/zone2/soil/temperature',
    '1-Wire protocol. GP4 on SG-PICO-002. 5.1kΩ pullup to 3V3.'
),
(
    'SG-SENSOR-LIGHT-001', 'SENSOR-LIGHT',
    'BH1750 Light Sensor',
    'Rohm', 'BH1750', 'BH1750FVI',
    'Amazon.se', NULL,
    'Edge enclosure — outdoor facing', 'edge', 'active', NULL,
    'ns=2;s=SmartGarden/Environment/Light/Lux',
    'environment_light_lux', 'garden/environment/light/lux',
    'I2C address 0x23. Connected to SG-PI-001 GP4/GP5 (I2C bus 0).'
),
(
    'SG-SENSOR-PRES-001', 'SENSOR-PRES',
    'BME280 Temperature / Humidity / Pressure',
    'Adafruit / Bosch', 'BME280', '2652',
    'Electrokit', 'https://www.electrokit.com/en/bme280-temperature-humidity-pressure-sensor-i2c-or-spi',
    'Edge enclosure — outdoor facing', 'edge', 'active', NULL,
    'ns=2;s=SmartGarden/Environment/Air',
    'environment_air', 'garden/environment/air',
    'STEMMA QT (JST SH 1mm). I2C address 0x77. SG-PI-001 GP2/GP3 (I2C bus 1).'
),
(
    'SG-SENSOR-FLOW-001', 'SENSOR-FLOW',
    'YF-S201 Water Flow Sensor — Zone 1',
    'Generic', 'YF-S201', 'YF-S201',
    'Amazon.se', NULL,
    'Zone 1 water supply line', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/FlowRate',
    'zone1_flow_rate', 'garden/zone1/flow/rate',
    '5V pulse signal. Voltage divider (1kΩ+2kΩ) → 3.3V → GP10 SG-PICO-001.'
),
(
    'SG-SENSOR-WEIGHT-001', 'SENSOR-WEIGHT',
    'HX711 + 10kg Load Cell — Zone 1',
    'Generic', 'HX711 + load cell 10kg', NULL,
    'Electrokit', 'https://www.electrokit.com/en/load-cell-10kg-with-hx711-amplifier-module',
    'Zone 1 — under main pot', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/Weight/Raw',
    'zone1_weight_kg', 'garden/zone1/weight/raw',
    'HX711 DOUT→GP6, SCK→GP7 on SG-PICO-001. Measures pot weight as soil water proxy.'
),
(
    'SG-VALVE-001', 'VALVE',
    'Solenoid Valve 12V ½" — Zone 1',
    'Generic', '12V NC Solenoid Valve ½"', NULL,
    'Electrokit', 'https://www.electrokit.com/en/magnetventil-12v-1/2',
    'Zone 1 water supply', 'zone1', 'active', NULL,
    'ns=2;s=SmartGarden/Zone1/Valve/State',
    NULL, 'garden/zone1/valve/state',
    'Normally closed. Switched via SG-RELAY-001. GP8 on SG-PICO-001.'
),
(
    'SG-VALVE-002', 'VALVE',
    'Solenoid Valve 12V ½" — Zone 2',
    'Generic', '12V NC Solenoid Valve ½"', NULL,
    'Electrokit', 'https://www.electrokit.com/en/magnetventil-12v-1/2',
    'Zone 2 water supply', 'zone2', 'active', NULL,
    'ns=2;s=SmartGarden/Zone2/Valve/State',
    NULL, 'garden/zone2/valve/state',
    'Normally closed. Switched via SG-RELAY-003. GP8 on SG-PICO-002.'
),
(
    'SG-PUMP-001', 'PUMP',
    '12V Water Pump',
    'Generic', '12V 1300L/h submersible pump', NULL,
    'Electrokit', 'https://www.electrokit.com/en/vatskepump-12v-1300l/h',
    'Water tank', 'zone1', 'active', NULL,
    NULL, NULL, 'garden/zone1/pump/state',
    'Switched via SG-RELAY-002. GP9 on SG-PICO-001. Zone 1 only.'
),
(
    'SG-PSU-001', 'PSU',
    '12V 5-8A DC Power Supply',
    'Generic', '12V 5-8A PSU', NULL,
    'Biltema / Kjell', NULL,
    'Main enclosure', 'edge', 'active', NULL,
    NULL, NULL, NULL,
    'Feeds 12V rail (valves, pump) and buck converter (5V for compute/sensors).'
),
(
    'SG-BUCK-001', 'BUCK',
    'Buck Converter 12V → 5V USB-C PD',
    'Generic', '12V to 5V USB-C PD Buck Converter', NULL,
    'Amazon.se', NULL,
    'Main enclosure', 'edge', 'active', NULL,
    NULL, NULL, NULL,
    'USB-C PD trigger chip required for Pi 5. Powers Pi 5, Pico ×2, all sensors.'
);

-- ============================================================
-- SEED DOCUMENTS — datasheets for key assets
-- ============================================================
INSERT INTO asset_documents (asset_id, doc_type, title, url) VALUES
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-SOIL-001'),
    'datasheet', 'Adafruit STEMMA Soil Sensor Product Page',
    'https://www.adafruit.com/product/4026'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-SOIL-001'),
    'user_manual', 'Adafruit STEMMA Soil Sensor Guide',
    'https://learn.adafruit.com/adafruit-stemma-soil-sensor-ltr390-uv-light-sensor'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-PRES-001'),
    'datasheet', 'BME280 Product Page',
    'https://www.adafruit.com/product/2652'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    'user_manual', 'Raspberry Pi Pico 2W Datasheet',
    'https://datasheets.raspberrypi.com/pico/pico-2-w-datasheet.pdf'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PI-001'),
    'user_manual', 'Raspberry Pi 5 Product Brief',
    'https://datasheets.raspberrypi.com/rpi5/raspberry-pi-5-product-brief.pdf'
);

-- ============================================================
-- SEED CONNECTIONS — key wiring relationships
-- ============================================================
INSERT INTO asset_connections (from_asset_id, to_asset_id, interface, from_pin, to_pin, signal_description) VALUES
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-SOIL-001'),
    'I2C', 'GP0 (SDA) / GP1 (SCL)', 'SDA / SCL', 'I2C bus 0, address 0x36'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-SOIL-002'),
    'I2C', 'GP2 (SDA) / GP3 (SCL)', 'SDA / SCL', 'I2C bus 1, address 0x37'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-TEMP-001'),
    '1-Wire', 'GP4', 'Data', '5.1kΩ pullup to 3V3'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-WEIGHT-001'),
    'GPIO', 'GP6 (DOUT) / GP7 (SCK)', 'DOUT / SCK', 'HX711 2-wire protocol'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-FLOW-001'),
    'GPIO', 'GP10', 'Signal', '5V→3.3V via 1kΩ+2kΩ voltage divider'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-VALVE-001'),
    'GPIO', 'GP8', 'Relay IN1', 'Active low relay, NC valve'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PICO-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-PUMP-001'),
    'GPIO', 'GP9', 'Relay IN2', 'Active low relay'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PI-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-PRES-001'),
    'I2C', 'GP2 (SDA) / GP3 (SCL)', 'SDA / SCL', 'I2C bus 1, address 0x77, STEMMA QT'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PI-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-SENSOR-LIGHT-001'),
    'I2C', 'GP4 (SDA) / GP5 (SCL)', 'SDA / SCL', 'I2C bus 0, address 0x23'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-PSU-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-BUCK-001'),
    '12V', '12V output', '12V input', '12V rail to buck converter'
),
(
    (SELECT id FROM assets WHERE asset_tag = 'SG-BUCK-001'),
    (SELECT id FROM assets WHERE asset_tag = 'SG-PI-001'),
    'USB-C PD', '5V/5A USB-C', 'USB-C power input', 'PD negotiation required'
);

-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- Active assets by zone
CREATE VIEW active_assets_by_zone AS
SELECT
    a.zone,
    a.asset_tag,
    at.name AS type,
    a.name,
    a.status,
    a.mqtt_topic,
    a.opcua_node_id
FROM assets a
JOIN asset_types at ON a.asset_type_code = at.code
WHERE a.status = 'active'
ORDER BY a.zone, at.code, a.asset_tag;

-- Assets with pending maintenance
CREATE VIEW maintenance_due AS
SELECT
    a.asset_tag,
    a.name,
    ml.next_due_date,
    ml.event_type,
    ml.description,
    (ml.next_due_date - CURRENT_DATE) AS days_until_due
FROM assets a
JOIN maintenance_log ml ON a.id = ml.asset_id
WHERE ml.next_due_date IS NOT NULL
  AND ml.next_due_date >= CURRENT_DATE
ORDER BY ml.next_due_date;

-- Asset connection map
CREATE VIEW connection_map AS
SELECT
    fa.asset_tag AS from_asset,
    fa.name AS from_name,
    ac.interface,
    ac.from_pin,
    ac.to_pin,
    ta.asset_tag AS to_asset,
    ta.name AS to_name,
    ac.signal_description
FROM asset_connections ac
JOIN assets fa ON ac.from_asset_id = fa.id
JOIN assets ta ON ac.to_asset_id = ta.id
ORDER BY fa.asset_tag;

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_assets_tag ON assets(asset_tag);
CREATE INDEX idx_assets_zone ON assets(zone);
CREATE INDEX idx_assets_status ON assets(status);
CREATE INDEX idx_maintenance_asset ON maintenance_log(asset_id);
CREATE INDEX idx_maintenance_date ON maintenance_log(event_date);
CREATE INDEX idx_alerts_asset ON asset_alerts(asset_id);
CREATE INDEX idx_alerts_resolved ON asset_alerts(resolved_at);
CREATE INDEX idx_connections_from ON asset_connections(from_asset_id);
CREATE INDEX idx_connections_to ON asset_connections(to_asset_id);

-- ============================================================
-- ACCESS TOKENS — time-limited access for sharing
-- (Phase 9 — Utvei)
-- ============================================================
CREATE TABLE access_tokens (
    id              SERIAL PRIMARY KEY,
    token           VARCHAR(64) UNIQUE NOT NULL,
    label           VARCHAR(100) NOT NULL,  -- e.g. "ABB interview March 2027"
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked         BOOLEAN DEFAULT FALSE,
    accessed_count  INTEGER DEFAULT 0,
    last_accessed   TIMESTAMPTZ,
    notes           TEXT
);

CREATE INDEX idx_tokens_token ON access_tokens(token);
CREATE INDEX idx_tokens_expires ON access_tokens(expires_at);

-- Example: generate a 14-day token for a recruiter
-- INSERT INTO access_tokens (token, label, expires_at)
-- VALUES (
--     encode(gen_random_bytes(32), 'hex'),
--     'ABB R&D interview — March 2027',
--     NOW() + INTERVAL '14 days'
-- );
