/**
 * Smart Garden — Zone Controller
 * Phase 1: Sensor reading + servo
 *
 * Sensors:
 *   DS18B20  — soil temperature  (1-Wire, GP4, 5.1kΩ pullup)
 *   HX711    — load cell weight  (GPIO, GP6 DOUT / GP7 SCK)
 *   SG90     — servo motor       (PWM, GP8)
 *
 * Raspberry Pi Pico 2W / RP2350
 * Pico SDK 2.3.0 — C++17
 */

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/pwm.h"
#include <cmath>

// ============================================================
// PIN DEFINITIONS
// ============================================================
namespace Pins {
    constexpr uint DS18B20   = 4;
    constexpr uint HX711_DT  = 6;
    constexpr uint HX711_SCK = 7;
    constexpr uint SERVO     = 8;
}

// ============================================================
// TIMING CONSTANTS
// ============================================================
namespace Timing {
    // DS18B20 1-Wire (microseconds)
    constexpr uint32_t OW_RESET_PULSE   = 480;
    constexpr uint32_t OW_PRESENCE_DLY  = 70;
    constexpr uint32_t OW_PRESENCE_END  = 410;
    constexpr uint32_t OW_WRITE_1_LOW   = 1;
    constexpr uint32_t OW_WRITE_1_HIGH  = 59;
    constexpr uint32_t OW_WRITE_0_LOW   = 60;
    constexpr uint32_t OW_WRITE_0_HIGH  = 1;
    constexpr uint32_t OW_READ_START    = 1;
    constexpr uint32_t OW_READ_SAMPLE   = 14;
    constexpr uint32_t OW_READ_END      = 45;
    constexpr uint32_t DS18B20_CONV_MS  = 750;

    // SG90 servo PWM — calibrated for this specific servo
    constexpr uint16_t SERVO_MIN_US     = 500;   // 0°
    constexpr uint16_t SERVO_MAX_US     = 2900;  // 180°
}

// ============================================================
// SENSOR DATA STRUCTS
// ============================================================
struct TemperatureReading {
    float celsius;
    bool  valid;
};

struct WeightReading {
    int32_t raw;
    bool    valid;
};

// ============================================================
// DS18B20 — 1-Wire soil temperature
// ============================================================
namespace DS18B20 {

    void pin_low()     { gpio_set_dir(Pins::DS18B20, GPIO_OUT); gpio_put(Pins::DS18B20, 0); }
    void pin_release() { gpio_set_dir(Pins::DS18B20, GPIO_IN); }
    bool pin_read()    { return gpio_get(Pins::DS18B20); }

    void init() {
        gpio_init(Pins::DS18B20);
        gpio_set_dir(Pins::DS18B20, GPIO_IN);
    }

    bool reset() {
        pin_low();
        sleep_us(Timing::OW_RESET_PULSE);
        pin_release();
        sleep_us(Timing::OW_PRESENCE_DLY);
        bool present = !pin_read();
        sleep_us(Timing::OW_PRESENCE_END);
        return present;
    }

    void write_bit(bool bit) {
        pin_low();
        sleep_us(bit ? Timing::OW_WRITE_1_LOW : Timing::OW_WRITE_0_LOW);
        pin_release();
        sleep_us(bit ? Timing::OW_WRITE_1_HIGH : Timing::OW_WRITE_0_HIGH);
    }

    void write_byte(uint8_t byte) {
        for (int i = 0; i < 8; i++) write_bit(byte & (1 << i));
    }

    bool read_bit() {
        pin_low();
        sleep_us(Timing::OW_READ_START);
        pin_release();
        sleep_us(Timing::OW_READ_SAMPLE);
        bool bit = pin_read();
        sleep_us(Timing::OW_READ_END);
        return bit;
    }

    uint8_t read_byte() {
        uint8_t byte = 0;
        for (int i = 0; i < 8; i++) if (read_bit()) byte |= (1 << i);
        return byte;
    }

    TemperatureReading read() {
        if (!reset()) return {0.0f, false};
        write_byte(0xCC);
        write_byte(0x44);
        sleep_ms(Timing::DS18B20_CONV_MS);
        reset();
        write_byte(0xCC);
        write_byte(0xBE);
        uint8_t lsb = read_byte();
        uint8_t msb = read_byte();
        int16_t raw = (msb << 8) | lsb;
        return {raw / 16.0f, true};
    }
}

// ============================================================
// HX711 — 24-bit ADC for load cell
// ============================================================
namespace HX711 {

    void init() {
        gpio_init(Pins::HX711_DT);
        gpio_set_dir(Pins::HX711_DT, GPIO_IN);
        gpio_init(Pins::HX711_SCK);
        gpio_set_dir(Pins::HX711_SCK, GPIO_OUT);
        gpio_put(Pins::HX711_SCK, 0);
    }

    void wait_ready() {
        while (gpio_get(Pins::HX711_DT) == 1) sleep_ms(1);
    }

    int32_t read_raw() {
        wait_ready();
        int32_t raw = 0;
        for (int i = 0; i < 24; i++) {
            gpio_put(Pins::HX711_SCK, 1); sleep_us(1);
            raw = (raw << 1) | gpio_get(Pins::HX711_DT);
            gpio_put(Pins::HX711_SCK, 0); sleep_us(1);
        }
        // 25th pulse — sets gain 128
        gpio_put(Pins::HX711_SCK, 1); sleep_us(1);
        gpio_put(Pins::HX711_SCK, 0); sleep_us(1);
        // Sign extend 24-bit to 32-bit
        if (raw & 0x800000) raw |= 0xFF000000;
        return raw;
    }

    WeightReading read(int samples = 5) {
        int64_t sum = 0;
        for (int i = 0; i < samples; i++) sum += read_raw();
        return {(int32_t)(sum / samples), true};
    }
}

// ============================================================
// SERVO — SG90 PWM (calibrated 500-2900us)
// ============================================================
// ============================================================
// SERVO — SG90 with software position tracking
// ============================================================
namespace Servo {

    uint     slice;
    uint     channel;

    // ── State ─────────────────────────────────────────────
    float    current_angle   = 90.0f;  // estimated actual angle
    float    target_angle    = 90.0f;  // commanded angle
    float    start_angle     = 90.0f;  // angle when move started
    uint32_t move_start_ms   = 0;      // when move started
    bool     is_moving       = false;

    // SG90 speed: ~120ms per 60 degrees = 2ms per degree
    constexpr float MS_PER_DEGREE = 2.0f;

    // ── PWM output ────────────────────────────────────────
    void set_pwm(uint8_t degrees) {
        if (degrees > 180) degrees = 180;
        uint16_t pulse_us = Timing::SERVO_MIN_US +
            (uint16_t)((degrees / 180.0f) *
            (Timing::SERVO_MAX_US - Timing::SERVO_MIN_US));
        pwm_set_chan_level(slice, channel, pulse_us);
    }

    void init() {
        gpio_set_function(Pins::SERVO, GPIO_FUNC_PWM);
        slice   = pwm_gpio_to_slice_num(Pins::SERVO);
        channel = pwm_gpio_to_channel(Pins::SERVO);
        pwm_set_clkdiv(slice, 125.0f);
        pwm_set_wrap(slice, 20000);
        pwm_set_enabled(slice, true);
        set_pwm(90);
        current_angle = 90.0f;
        target_angle  = 90.0f;
    }

    // ── Command a new position ────────────────────────────
    void set_angle(float degrees) {
        if (degrees < 0)   degrees = 0;
        if (degrees > 180) degrees = 180;

        start_angle    = current_angle;  // start from estimated position
        target_angle   = degrees;
        move_start_ms  = to_ms_since_boot(get_absolute_time());
        is_moving      = true;

        set_pwm((uint8_t)degrees);  // send PWM command immediately
    }

    // ── Update estimated position — call frequently ───────
    void update() {
        if (!is_moving) return;

        uint32_t now     = to_ms_since_boot(get_absolute_time());
        uint32_t elapsed = now - move_start_ms;
        float    travel  = fabsf(target_angle - start_angle);
        float    travel_time_ms = travel * MS_PER_DEGREE;

        if (elapsed >= (uint32_t)travel_time_ms) {
            // Move complete
            current_angle = target_angle;
            is_moving     = false;
        } else {
            // Interpolate position
            float progress = elapsed / travel_time_ms;
            current_angle  = start_angle +
                             (target_angle - start_angle) * progress;
        }
    }

    float    get_angle()    { return current_angle; }
    float    get_target()   { return target_angle; }
    bool     get_moving()   { return is_moving; }

    void sweep(float from_deg, float to_deg, uint32_t step_ms = 15) {
        if (from_deg < to_deg) {
            for (float d = from_deg; d <= to_deg; d += 1.0f) {
                set_angle(d);
                sleep_ms(step_ms);
                update();
            }
        } else {
            for (float d = from_deg; d >= to_deg; d -= 1.0f) {
                set_angle(d);
                sleep_ms(step_ms);
                update();
            }
        }
    }
}
// ============================================================
// DISPLAY — formatted serial output
// ============================================================
namespace Display {

    void header() {
        printf("\n");
        printf("========================================\n");
        printf("  Smart Garden -- Zone 1 Controller\n");
        printf("  Pico 2W / RP2350 / Phase 1\n");
        printf("========================================\n\n");
    }

    void readings(
        const TemperatureReading& temp,
        const WeightReading& weight,
        uint32_t count)
    {
        printf("-- Reading #%lu --\n", (unsigned long)count);

        if (temp.valid) {
            printf("  Soil temp  : %6.2f C  ", temp.celsius);
            if      (temp.celsius < 10.0f) printf("[COLD]\n");
            else if (temp.celsius > 35.0f) printf("[HOT]\n");
            else                           printf("[OK]\n");
        } else {
            printf("  Soil temp  : ERROR -- check DS18B20\n");
        }

        if (weight.valid) {
            printf("  Load cell  : %ld raw\n", (long)weight.raw);
        } else {
            printf("  Load cell  : ERROR -- check HX711\n");
        }

        // Servo position tracking
        printf("  Servo      : target=%.1f  estimated=%.1f  %s\n",
               Servo::get_target(),
               Servo::get_angle(),
               Servo::get_moving() ? "[MOVING]" : "[ARRIVED]");
        printf("\n");
    }
}

// ============================================================
// MAIN
// ============================================================
int main() {
    stdio_init_all();
    sleep_ms(2000);

    DS18B20::init();
    HX711::init();
    Servo::init();

    Display::header();

    // Startup sweep
    printf("Servo startup sweep...\n");
    Servo::sweep(90, 0);
    Servo::sweep(0, 180);
    Servo::sweep(180, 90);
    printf("Servo ready.\n\n");

    uint32_t count        = 1;
    float    last_temp    = -999.0f;
    float    servo_angle  = 90.0f;
    float    temp_baseline = -999.0f;

    while (true) {
        Servo::update();

        TemperatureReading temp   = DS18B20::read();
        WeightReading      weight = HX711::read();

        if (temp.valid) {
            if (temp_baseline == -999.0f) {
                // First reading — set baseline and map to servo
                temp_baseline = temp.celsius;
                servo_angle   = (temp.celsius / 50.0f) * 180.0f;
                servo_angle   = (servo_angle < 0)   ? 0   : servo_angle;
                servo_angle   = (servo_angle > 180) ? 180 : servo_angle;
                Servo::set_angle(servo_angle);
                printf("Baseline: %.2f C -- servo %.1f degrees\n\n",
                       temp_baseline, servo_angle);
            } else {
                // Compare against baseline (last move position)
                float delta = temp.celsius - temp_baseline;

                if (delta >= 1.0f) {
                    // Moved up by 1°C or more from last move
                    int steps = (int)(delta);  // how many full degrees
                    servo_angle += steps * 10.0f;
                    if (servo_angle > 180.0f) servo_angle = 180.0f;
                    Servo::set_angle(servo_angle);
                    temp_baseline += steps;  // advance baseline by steps
                    printf("Temp UP   %.2f C (+%d deg) -- servo -> %.1f\n",
                           temp.celsius, steps, servo_angle);
                } else if (delta <= -1.0f) {
                    // Moved down by 1°C or more from last move
                    int steps = (int)(-delta);
                    servo_angle -= steps * 10.0f;
                    if (servo_angle < 0.0f) servo_angle = 0.0f;
                    Servo::set_angle(servo_angle);
                    temp_baseline -= steps;
                    printf("Temp DOWN %.2f C (-%d deg) -- servo -> %.1f\n",
                           temp.celsius, steps, servo_angle);
                } else {
                    printf("Temp HOLD %.2f C (delta %.2f) -- servo holds %.1f\n",
                           temp.celsius, delta, servo_angle);
                }
            }
        }

        Display::readings(temp, weight, count++);

        for (int i = 0; i < 40; i++) {
            Servo::update();
            sleep_ms(50);
        }
    }
}