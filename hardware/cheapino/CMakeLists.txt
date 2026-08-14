if(CONFIG_ZMK_BEHAVIOR_CHEAPINO_ENCODER)
  target_sources(app PRIVATE src/behavior_cheapino_encoder.c)
endif()

if(CONFIG_ZMK_KSCAN_CHEAPINO_GHOST_FILTER)
  target_sources(app PRIVATE src/kscan_cheapino_ghost_filter.c)
endif()
