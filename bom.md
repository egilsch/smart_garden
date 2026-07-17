# Bill of Materials

All prices approximate in NOK. Electrokit.se ships to Norway in 2–3 days.

---

## Compute

| Component | Supplier | Link | ~NOK |
|---|---|---|---|
| Raspberry Pi 5 4GB | Electrokit | https://www.electrokit.com/en/raspberry-pi-5-/4gb | 700 |
| Raspberry Pi Pico 2WH × 2 | Electrokit | https://www.electrokit.com/en/raspberry-pi-pico-2-wh | 280 |

## Sensors

| Component | Supplier | Link | ~NOK |
|---|---|---|---|
| Capacitive soil moisture I2C (Adafruit STEMMA) × 3 | Electrokit | https://www.electrokit.com/en/product/jordfuktighetssensor-kapacitiv-i2c/ | 450 |
| BME280 temp/humidity/pressure (Adafruit) | Electrokit | https://www.electrokit.com/en/bme280-temperature-humidity-pressure-sensor-i2c-or-spi | 250 |
| Load cell 10kg + HX711 module | Electrokit | https://www.electrokit.com/en/load-cell-10kg-with-hx711-amplifier-module | 200 |
| DS18B20 waterproof temp sensor × 2 | Electrokit | https://www.electrokit.com/en/temperatursensor-vattentat-ds18b20 | 200 |
| BH1750 light sensor | Amazon.se | Search: BH1750 I2C module | 80 |
| YF-S201 flow sensor | Amazon.se | Search: YF-S201 hall effect flow sensor | 100 |

## Actuation

| Component | Supplier | Link | ~NOK |
|---|---|---|---|
| Solenoid valve 12V ½" 8bar (NC) × 2 | Electrokit | https://www.electrokit.com/en/magnetventil-12v-1/2 | 400 |
| Fluid pump 12V | Electrokit | https://www.electrokit.com/en/vatskepump-12v-1300l/h | 200 |
| Relay module 5V × 4 | Electrokit | https://www.electrokit.com/en/relamodul-5v | 300 |

## Power

| Component | Supplier | Notes | ~NOK |
|---|---|---|---|
| 12V 5–8A DC PSU | Biltema / Kjell | Wall-mount or DIN, 60W+ | 200 |
| Buck converter 12V→5V USB-C PD | Amazon.se | Must include PD trigger chip for Pi 5 compatibility — search: "12V 5V USB-C PD buck converter Raspberry Pi 5" | 200 |

## Passive components & consumables

| Component | Notes | ~NOK |
|---|---|---|
| Full-size breadboard | Prototyping phases 1–5 | 80 |
| Jumper wire assortment (M-M, M-F, F-F) | Buy more than you think you need | 100 |
| Resistors: 1kΩ, 2kΩ, 4.7kΩ | Voltage divider (YF-S201) + DS18B20 pullup | 30 |
| MicroSD 32GB+ (Samsung Pro Endurance) | Endurance-rated — InfluxDB writes constantly | 150 |
| Waterproof enclosure IP65 | For outdoor deployment (Phase 6) | 200 |
| Cable glands × 6 | Seal cable entries in enclosure | 60 |
| Terminal blocks | Clean internal wiring | 50 |
| Heat shrink assortment | Cable joints | 50 |

---

## Budget summary

| Category | ~NOK |
|---|---|
| Compute | 980 |
| Sensors | 1,280 |
| Actuation | 900 |
| Power | 400 |
| Consumables | 720 |
| **Total** | **~4,280** |

> Core hardware (compute + sensors + actuation) sits at ~3,160kr — within the original 2,000–3,000kr target if consumables and enclosure are bought separately as needed.

---

## To buy later

These are not needed until Phase 5–6 but worth ordering together to save shipping:

| Component | Purpose | Supplier | ~NOK |
|---|---|---|---|
| Pinecil v2 soldering iron | Permanent wiring (Phase 6) | eleshop.eu | ~380 |
| UT61E+ multimeter | High-res bench meter + data logging | eleshop.eu | ~700 |
| USB logic analyser | Debug I2C/SPI/UART bus signals | eleshop.eu | ~200 |
| Bench power supply 0–30V/5A | Development and debugging | eleshop.eu | ~800 |
| Solder tin 60/40 ~0.8mm | Soldering consumable | eleshop.eu | ~80 |
| Flux pen | Better joint quality | eleshop.eu | ~80 |
| Desoldering pump | Inevitable | eleshop.eu | ~80 |
| Portable iron stand | Safety | eleshop.eu | ~80 |
| Stripboard | Replace breadboard (Phase 6) | Electrokit | ~80 |
