/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The Cheapino encoder's common, A, and B contacts are part of the keyboard's
 * directed matrix. Sideband scan bindings feed A/B transitions into this
 * behavior, which converts a complete quadrature step into a normal ZMK
 * behavior tap. The actions match the upstream Cheapino v2 firmware at
 * fe770a75b87996cb89807d7de14ebf8c85e3ae3b.
 */

#define DT_DRV_COMPAT zmk_behavior_cheapino_encoder

#include <zephyr/device.h>
#include <drivers/behavior.h>
#include <zmk/behavior.h>
#include <zmk/keymap.h>

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

enum cheapino_encoder_contact {
    CHEAPINO_ENCODER_A,
    CHEAPINO_ENCODER_B,
};

struct cheapino_encoder_config {
    struct zmk_behavior_binding bindings[8];
    uint8_t mac_nav_layer;
    uint8_t mac_num_layer;
    uint8_t system_layer;
};

struct cheapino_encoder_data {
    bool a_pressed;
    bool b_pressed;
    bool both_pressed;
};

#define EXTRACT_BINDING(idx, node) ZMK_KEYMAP_EXTRACT_BINDING(idx, node)

static int tap_binding(const struct zmk_behavior_binding *binding,
                       struct zmk_behavior_binding_event event) {
    int err = zmk_behavior_invoke_binding(binding, event, true);
    if (err < 0) {
        return err;
    }

    return zmk_behavior_invoke_binding(binding, event, false);
}

static int encoder_binding_pressed(struct zmk_behavior_binding *binding,
                                   struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    struct cheapino_encoder_data *data = dev->data;

    if (binding->param1 == CHEAPINO_ENCODER_A) {
        data->a_pressed = true;
    } else if (binding->param1 == CHEAPINO_ENCODER_B) {
        data->b_pressed = true;
    } else {
        return -EINVAL;
    }

    if (data->a_pressed && data->b_pressed) {
        data->both_pressed = true;
    }

    return ZMK_BEHAVIOR_OPAQUE;
}

static int encoder_binding_released(struct zmk_behavior_binding *binding,
                                    struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct cheapino_encoder_config *config = dev->config;
    struct cheapino_encoder_data *data = dev->data;

    if (binding->param1 == CHEAPINO_ENCODER_A) {
        data->a_pressed = false;
    } else if (binding->param1 == CHEAPINO_ENCODER_B) {
        data->b_pressed = false;
    } else {
        return -EINVAL;
    }

    if (!data->both_pressed || data->a_pressed == data->b_pressed) {
        return ZMK_BEHAVIOR_OPAQUE;
    }

    data->both_pressed = false;
    const bool clockwise = data->a_pressed;
    const uint8_t layer = zmk_keymap_highest_layer_active();
    size_t pair = 0;

    if (layer == config->mac_nav_layer) {
        pair = 2;
    } else if (layer == config->mac_num_layer) {
        pair = 4;
    } else if (layer == config->system_layer) {
        pair = 6;
    }

    return tap_binding(&config->bindings[pair + (clockwise ? 0 : 1)], event);
}

static const struct behavior_driver_api cheapino_encoder_driver_api = {
    .binding_pressed = encoder_binding_pressed,
    .binding_released = encoder_binding_released,
};

#define CHEAPINO_ENCODER_INST(n)                                                                 \
    BUILD_ASSERT(DT_INST_PROP_LEN(n, bindings) == 8,                                             \
                 "Cheapino encoder requires four clockwise/counter-clockwise binding pairs");   \
    static const struct cheapino_encoder_config cheapino_encoder_config_##n = {                  \
        .bindings = {LISTIFY(8, EXTRACT_BINDING, (, ), DT_DRV_INST(n))},                          \
        .mac_nav_layer = DT_INST_PROP(n, mac_nav_layer),                                         \
        .mac_num_layer = DT_INST_PROP(n, mac_num_layer),                                         \
        .system_layer = DT_INST_PROP(n, system_layer),                                           \
    };                                                                                            \
    static struct cheapino_encoder_data cheapino_encoder_data_##n = {};                           \
    BEHAVIOR_DT_INST_DEFINE(n, NULL, NULL, &cheapino_encoder_data_##n,                            \
                            &cheapino_encoder_config_##n, POST_KERNEL,                            \
                            CONFIG_KERNEL_INIT_PRIORITY_DEFAULT, &cheapino_encoder_driver_api);

DT_INST_FOREACH_STATUS_OKAY(CHEAPINO_ENCODER_INST)

#endif
