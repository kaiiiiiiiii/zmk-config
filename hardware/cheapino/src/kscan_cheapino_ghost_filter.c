/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The Cheapino v2 PCB has several known three-key combinations that can create
 * a phantom fourth matrix edge. The masks below reproduce the suppression in
 * the official Cheapino v2 QMK firmware at
 * fe770a75b87996cb89807d7de14ebf8c85e3ae3b.
 */

#define DT_DRV_COMPAT zmk_kscan_cheapino_ghost_filter

#include <zephyr/device.h>
#include <zephyr/drivers/kscan.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/util.h>

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

#define CHEAPINO_PIN_COUNT 14
#define CHEAPINO_QMK_ROW_COUNT 8
#define CHEAPINO_QMK_COL_PIN_FIRST 8
#define CHEAPINO_QMK_COL_PIN_COUNT 6

struct cheapino_ghost_filter_config {
    const struct device *kscan;
};

struct cheapino_ghost_filter_data {
    const struct device *dev;
    kscan_callback_t callback;
    struct k_work_delayable work;
    bool enabled;
    bool raw[CHEAPINO_PIN_COUNT][CHEAPINO_PIN_COUNT];
    bool reported[CHEAPINO_PIN_COUNT][CHEAPINO_PIN_COUNT];
};

#define GET_FILTER_DEVICE(n) DEVICE_DT_GET(DT_DRV_INST(n)),

static const struct device *filters[] = {DT_INST_FOREACH_STATUS_OKAY(GET_FILTER_DEVICE)};

static const struct device *filter_for_inner(const struct device *inner) {
    for (size_t i = 0; i < ARRAY_SIZE(filters); i++) {
        const struct cheapino_ghost_filter_config *config = filters[i]->config;

        if (config->kscan == inner) {
            return filters[i];
        }
    }

    return NULL;
}

static bool contains_bits(uint16_t value, uint16_t bits) { return (value & bits) == bits; }

static void suppress_instance(uint16_t matrix[], uint8_t cause_row, uint16_t cause,
                              uint8_t ghost_row, uint16_t ghost_pattern, uint16_t ghost_bit) {
    if (contains_bits(matrix[cause_row], cause) &&
        contains_bits(matrix[ghost_row], ghost_pattern)) {
        matrix[ghost_row] ^= ghost_bit;
    }
}

static void suppress_column(uint16_t matrix[], uint16_t cause, uint16_t ghost_pattern,
                            uint16_t ghost_bit) {
    for (uint8_t row = 0; row < 3; row++) {
        suppress_instance(matrix, row, cause, (row + 1) % 3, ghost_pattern, ghost_bit);
        suppress_instance(matrix, row, cause, (row + 2) % 3, ghost_pattern, ghost_bit);
    }

    for (uint8_t row = 0; row < 3; row++) {
        suppress_instance(matrix, row + 4, cause << 6, 4 + ((row + 1) % 3),
                          ghost_pattern << 6, ghost_bit << 6);
        suppress_instance(matrix, row + 4, cause << 6, 4 + ((row + 2) % 3),
                          ghost_pattern << 6, ghost_bit << 6);
    }
}

static void suppress_known_v2_ghosts(uint16_t matrix[]) {
    suppress_column(matrix, 0x006, 0x005, 0x004);
    suppress_column(matrix, 0x006, 0x00A, 0x002);
    suppress_column(matrix, 0x018, 0x014, 0x010);
    suppress_column(matrix, 0x018, 0x028, 0x008);
    suppress_column(matrix, 0x021, 0x011, 0x001);
    suppress_column(matrix, 0x021, 0x022, 0x020);
    suppress_column(matrix, 0x009, 0x00A, 0x008);
    suppress_column(matrix, 0x009, 0x005, 0x001);
    suppress_column(matrix, 0x012, 0x022, 0x002);
    suppress_column(matrix, 0x012, 0x011, 0x010);
}

static void ghost_filter_work(struct k_work *work) {
    struct k_work_delayable *delayable = k_work_delayable_from_work(work);
    struct cheapino_ghost_filter_data *data =
        CONTAINER_OF(delayable, struct cheapino_ghost_filter_data, work);
    bool filtered[CHEAPINO_PIN_COUNT][CHEAPINO_PIN_COUNT];
    uint16_t matrix[CHEAPINO_QMK_ROW_COUNT] = {};

    for (uint8_t row = 0; row < CHEAPINO_PIN_COUNT; row++) {
        for (uint8_t column = 0; column < CHEAPINO_PIN_COUNT; column++) {
            filtered[row][column] = data->raw[row][column];
        }
    }

    /* Convert the directed GPIO edges to the official 8x12 QMK matrix. */
    for (uint8_t row = 0; row < CHEAPINO_QMK_ROW_COUNT; row++) {
        for (uint8_t pin = CHEAPINO_QMK_COL_PIN_FIRST; pin < CHEAPINO_PIN_COUNT; pin++) {
            const uint8_t pair = pin - CHEAPINO_QMK_COL_PIN_FIRST;

            if (data->raw[row][pin]) {
                matrix[row] |= BIT(pair * 2);
            }
            if (data->raw[pin][row]) {
                matrix[row] |= BIT((pair * 2) + 1);
            }
        }
    }

    suppress_known_v2_ghosts(matrix);

    for (uint8_t row = 0; row < CHEAPINO_QMK_ROW_COUNT; row++) {
        for (uint8_t pin = CHEAPINO_QMK_COL_PIN_FIRST; pin < CHEAPINO_PIN_COUNT; pin++) {
            const uint8_t pair = pin - CHEAPINO_QMK_COL_PIN_FIRST;

            filtered[row][pin] = (matrix[row] & BIT(pair * 2)) != 0;
            filtered[pin][row] = (matrix[row] & BIT((pair * 2) + 1)) != 0;
        }
    }

    if (!data->enabled || !data->callback) {
        return;
    }

    for (uint8_t row = 0; row < CHEAPINO_PIN_COUNT; row++) {
        for (uint8_t column = 0; column < CHEAPINO_PIN_COUNT; column++) {
            if (filtered[row][column] == data->reported[row][column]) {
                continue;
            }

            data->reported[row][column] = filtered[row][column];
            data->callback(data->dev, row, column, filtered[row][column]);
        }
    }
}

static void inner_kscan_callback(const struct device *inner, uint32_t row, uint32_t column,
                                 bool pressed) {
    const struct device *dev = filter_for_inner(inner);

    if (!dev || row >= CHEAPINO_PIN_COUNT || column >= CHEAPINO_PIN_COUNT) {
        return;
    }

    struct cheapino_ghost_filter_data *data = dev->data;
    data->raw[row][column] = pressed;

    /* Coalesce all changes from one charlieplex pass before filtering them. */
    k_work_reschedule(&data->work, K_MSEC(1));
}

static int ghost_filter_configure(const struct device *dev, kscan_callback_t callback) {
    struct cheapino_ghost_filter_data *data = dev->data;
    data->callback = callback;
    return 0;
}

static int ghost_filter_enable(const struct device *dev) {
    const struct cheapino_ghost_filter_config *config = dev->config;
    struct cheapino_ghost_filter_data *data = dev->data;
    data->enabled = true;

    int err = kscan_config(config->kscan, inner_kscan_callback);
    return err < 0 ? err : kscan_enable_callback(config->kscan);
}

static int ghost_filter_disable(const struct device *dev) {
    const struct cheapino_ghost_filter_config *config = dev->config;
    struct cheapino_ghost_filter_data *data = dev->data;
    data->enabled = false;
    k_work_cancel_delayable(&data->work);
    return kscan_disable_callback(config->kscan);
}

static int ghost_filter_init(const struct device *dev) {
    const struct cheapino_ghost_filter_config *config = dev->config;
    struct cheapino_ghost_filter_data *data = dev->data;

    if (!device_is_ready(config->kscan)) {
        return -ENODEV;
    }

    data->dev = dev;
    k_work_init_delayable(&data->work, ghost_filter_work);
    return 0;
}

static const struct kscan_driver_api ghost_filter_api = {
    .config = ghost_filter_configure,
    .enable_callback = ghost_filter_enable,
    .disable_callback = ghost_filter_disable,
};

#define CHEAPINO_GHOST_FILTER_INST(n)                                                              \
    BUILD_ASSERT(DT_PROP_LEN(DT_INST_PHANDLE(n, kscan), gpios) == CHEAPINO_PIN_COUNT,              \
                 "Cheapino ghost filter requires the stock 14-pin matrix");                       \
    static const struct cheapino_ghost_filter_config ghost_filter_config_##n = {                   \
        .kscan = DEVICE_DT_GET(DT_INST_PHANDLE(n, kscan)),                                         \
    };                                                                                             \
    static struct cheapino_ghost_filter_data ghost_filter_data_##n = {};                           \
    DEVICE_DT_INST_DEFINE(n, ghost_filter_init, NULL, &ghost_filter_data_##n,                      \
                          &ghost_filter_config_##n, POST_KERNEL,                                  \
                          CONFIG_KSCAN_INIT_PRIORITY, &ghost_filter_api);

DT_INST_FOREACH_STATUS_OKAY(CHEAPINO_GHOST_FILTER_INST)

#endif
