# STM32F030F4_PRJ_GEN
This repo consists of a single shell script that generates an empty STM32F030F4 microcontroller project, with support for both Makefile and MDK-ARM.

## Hardware references

* [STM32F030F4 datasheet](https://www.st.com/resource/en/datasheet/stm32f030f4.pdf)
* [RM0360: STM32F030x4/x6/x8/xC reference manual](https://www.st.com/resource/en/reference_manual/dm00091010-stm32f030x4-x6-x8-xc-and-stm32f070x6-xb-advanced-arm-based-32-bit-mcus-stmicroelectronics.pdf)
* [PM0215: STM32F0 series Cortex-M0 programming manual](https://www.st.com/resource/en/programming_manual/dm00051352-stm32f0xxx-cortexm0-programming-manual-stmicroelectronics.pdf)
* [ES0219: STM32F030x4/x6/x8/xC device errata](https://www.st.com/resource/en/errata_sheet/es0219-stm32f030x4x6x8xc-device-errata-stmicroelectronics.pdf)

## Software references
* [STMicroelectronics CMSIS Device F0 Repository](https://github.com/STMicroelectronics/cmsis-device-f0/tree/master)
* [ARM CMSIS 5 Core](https://github.com/ARM-software/CMSIS_5/tree/develop/CMSIS/Core/Include)

## Notes

* **STM32F030F4 is the same silicon as STM32F031x6.** The F030F4 is a marketing variant of the
  `x6` die (up to 32 KB Flash / 6 KB RAM), so the generated project intentionally uses the
  `stm32f030x6` CMSIS headers, the `startup_stm32f030x6.s` startup file and the
  `stm32f030x6_flash.ld` linker script (where `FLASH` length is 32K and `RAM` length is 4K).
  This works on the F030F4 because it is the same chip; only the available Flash is smaller.
  Do not reduce the linker `FLASH` length unless you also change the device.

* **SVD file.** The script downloads `STM32F031x.svd` — the genuine per-part SVD from the
  Keil/Open-CMSIS device family pack (`Open-CMSIS-Pack/STM32F0xx_DFP`) — for use with external
  debuggers such as VS Code + Cortex-Debug. The MDK-ARM project (`Project.uvprojx`) instead uses the
  SVD shipped with the STM32 device pack (`STM32F0x0.svd` from the CMSIS pack), so the downloaded
  file is optional for MDK users.