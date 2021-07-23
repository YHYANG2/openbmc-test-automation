#!/usr/bin/env python

r"""
Redfish Sensor Info Map Table:

   - Define SENSOR_MAP for redfish_sensor_info_map variable

"""

SENSOR_MAP = {
    'Nuvoton': {
        'Voltage': [
            "P12V_STBY",
            "P1V05_STBY_PCH",
            "P3V3",
            "P3V3_STBY",
            "P5V",
            "P5V_STBY",
            "PVNN_STBY_PCH",
            "hotswap_vin",
            "hotswap_vout",
            "p0_dimm_vr0_voltage",
            "p0_dimm_vr1_voltage",
            "p0_vccin_vr_voltage",
            "p0_vccio_vr_voltage",
            "p1_dimm_vr0_voltage",
            "p1_dimm_vr1_voltage",
            "p1_vccin_vr_voltage",
            "p1_vccio_vr_voltage",
            "ps0_input_voltage",
            "ps0_output_voltage"
        ],
        'Temperature': [
            "bmc_card",
            "cpu0_core0_temp",
            "cpu0_core1_temp",
            "cpu0_core2_temp",
            "cpu0_core3_temp",
            "cpu0_core4_temp",
            "cpu0_core5_temp",
            "cpu0_die_temp",
            "cpu1_core0_temp",
            "cpu1_core1_temp",
            "cpu1_core2_temp",
            "cpu1_core3_temp",
            "cpu1_core4_temp",
            "cpu1_core5_temp",
            "cpu1_die_temp",
            "dimm0_temp",
            "hotswap_temp",
            "inlet",
            "outlet",
            "p0_dimm_vr0_temp",
            "p0_dimm_vr1_temp",
            "p0_vccin_vr_temp",
            "p0_vccio_vr_temp",
            "p1_dimm_vr0_temp",
            "p1_dimm_vr1_temp",
            "p1_vccin_vr_temp",
            "p1_vccio_vr_temp",
            "ps0_tempture"
        ],
        'Fans': [
            "fan1",
            "fan2",
            "fan3",
            "fan4",
            "fan5",
            "fan6"
        ],
        'Current_Power': [
            "hotswap_iout",
            "p0_dimm_vr0_current",
            "p0_dimm_vr0_iin",
            "p0_dimm_vr1_current",
            "p0_dimm_vr1_iin",
            "p0_vccin_vr_current",
            "p0_vccio_vr_current",
            "p1_dimm_vr0_current",
            "p1_dimm_vr0_iin",
            "p1_dimm_vr1_current",
            "p1_dimm_vr1_iin",
            "p1_vccin_vr_current",
            "p1_vccio_vr_current",
            "cpu_power",
            "hotswap_pout",
            "memory_power",
            "p0_dimm_vr0_pin",
            "p0_dimm_vr0_pout",
            "p0_dimm_vr1_pin",
            "p0_dimm_vr1_pout",
            "p0_vccin_vr_pin",
            "p0_vccin_vr_pout",
            "p0_vccio_vr_pin",
            "p0_vccio_vr_pout",
            "p1_dimm_vr0_pin",
            "p1_dimm_vr0_pout",
            "p1_dimm_vr1_pin",
            "p1_dimm_vr1_pout",
            "p1_vccin_vr_pin",
            "p1_vccin_vr_pout",
            "p1_vccio_vr_pin",
            "p1_vccio_vr_pout",
            "ps0_input_power",
            "ps0_output_power",
            "total_power"
        ]
    }
}
