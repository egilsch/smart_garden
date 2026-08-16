#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

// HX711 pins
#define HX711_DOUT  6
#define HX711_SCK   7

// ── Initialise HX711 pins ─────────────────────────
void hx711_init() {
    gpio_init(HX711_DOUT);
    gpio_set_dir(HX711_DOUT, GPIO_IN);
    gpio_init(HX711_SCK);
    gpio_set_dir(HX711_SCK, GPIO_OUT);
    gpio_put(HX711_SCK, 0);  // SCK low = HX711 powered on
}

// ── Wait until HX711 has data ready ───────────────
void hx711_wait_ready() {
    // DOUT goes LOW when conversion is ready
    while (gpio_get(HX711_DOUT) == 1) {
        sleep_ms(1);
    }
}

// ── Read 24-bit raw value from HX711 ──────────────
int32_t hx711_read() {
    hx711_wait_ready();

    int32_t raw = 0;

    // Read 24 bits, MSB first
    for (int i = 0; i < 24; i++) {
        gpio_put(HX711_SCK, 1);
        sleep_us(1);
        raw = (raw << 1) | gpio_get(HX711_DOUT);
        gpio_put(HX711_SCK, 0);
        sleep_us(1);
    }

    // 25th pulse — sets gain to 128 for next reading
    gpio_put(HX711_SCK, 1);
    sleep_us(1);
    gpio_put(HX711_SCK, 0);
    sleep_us(1);

    // HX711 output is two's complement — sign extend from 24 to 32 bits
    if (raw & 0x800000) {
        raw |= 0xFF000000;
    }

    return raw;
}

// ── Average multiple readings to reduce noise ─────
int32_t hx711_read_average(int times) {
    int64_t sum = 0;
    for (int i = 0; i < times; i++) {
        sum += hx711_read();
    }
    return (int32_t)(sum / times);
}

int main() {
    stdio_init_all();
    sleep_ms(2000);

    hx711_init();

    printf("=== HX711 Load Cell ===\n");
    printf("Reading raw values — place weight on load cell to see changes\n\n");

    while (true) {
        int32_t raw = hx711_read_average(5);  // average 5 readings
        printf("Raw value: %ld\n", raw);
        sleep_ms(500);
    }
}