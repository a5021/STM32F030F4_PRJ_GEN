#!/bin/bash
set -euo pipefail

function press_any_key {
    echo -n "Press any key to continue..."
    # read one character of input and discard it
    read -n 1 -s -r || true
    echo ""
}

if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Please install curl and try again."
    echo "For Debian/Ubuntu users: sudo apt-get install curl"
    echo "For Red Hat/CentOS users: sudo yum install curl"
    press_any_key
    exit 1
fi

# Array with directory names
directories=("inc" "src" "MDK-ARM")

fname1=("system_stm32f0xx.c" "startup_stm32f030x6.s")
fname2=("system_stm32f0xx.h" "stm32f0xx.h" "stm32f030x6.h")
fname3=("cmsis_compiler.h" "cmsis_armclang.h" "cmsis_gcc.h" "cmsis_iccarm.h" "cmsis_version.h" "core_cm0.h" "cmsis_armcc.h")

raw_github="https://raw.githubusercontent.com/"

url1="${raw_github}STMicroelectronics/cmsis-device-f0/refs/heads/master"
url2="${raw_github}ARM-software/CMSIS_5/refs/heads/develop/CMSIS/Core/Include/"
url3="${raw_github}Open-CMSIS-Pack/STM32F0xx_DFP/main/CMSIS/SVD/STM32F031x.svd"

op_counter=0

# Function to check for the existence of a directory and create it if it doesn't exist
create_directory() {
  if [ ! -d "$1" ]; then
    mkdir "$1"
    op_counter=$(expr $op_counter + 1)
    echo "Directory $1 created."
  fi
}


# Function to check for the existence of a file and create it from a heredoc if it doesn't exist.
# Usage: create_file "path" <<'CREATE_EOF' ... CREATE_EOF
create_file() {
  if [ ! -f "$1" ]; then
    cat > "$1"
    op_counter=$(expr $op_counter + 1)
    echo "File $1 created."
  fi
}


# Function to check if a file exists and download it if it doesn't
download_file() {
  if [ ! -f "$2" ]; then
    local tmp="$2.tmp"
    if ! curl -fSL --max-time 30 "$1" -o "$tmp"; then
      echo "Error: failed to download '$1'" >&2
      rm -f "$tmp"
      exit 1
    fi
    mv "$tmp" "$2"
    op_counter=$(expr $op_counter + 1)
    echo "File $2 downloaded."
  fi
}


# Create directories
for dir in "${directories[@]}"
do
  create_directory "$dir"
done

download_file "${url1}/Source/Templates/${fname1[0]}" "${directories[1]}/${fname1[0]}"
download_file "${url1}/Source/Templates/gcc/${fname1[1]}" "${directories[1]}/${fname1[1]}"
download_file "${url1}/Source/Templates/arm/${fname1[1]}" "${directories[2]}/${fname1[1]}"
download_file "${url3}" "STM32F031x.svd"

# Download files
for filename in "${fname2[@]}"
do
  download_file "${url1}/Include/${filename}" "${directories[0]}/${filename}"
done

for filename in "${fname3[@]}"
do
  download_file "${url2}${filename}" "${directories[0]}/${filename}"
done

create_file "Makefile" <<'CREATE_EOF'
# Define the target name and build directory.
TARGET    := Project
BUILD_DIR := _build

# Find all source files.
SRC := $(wildcard ./src/*.c)
ASM := $(wildcard ./src/*.s)

# Define the toolchain used.
# If GCC_PATH is set, use that as prefix for the toolchain path, 
# otherwise, assume the toolchain is in the PATH.
PREFIX := $(if $(GCC_PATH),$(GCC_PATH)/,)arm-none-eabi-

# Define the build tools used.
# CC - C compiler, AS - assembly compiler, CP - object copy program, SZ - size program
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
SZ = $(PREFIX)size

# Define the binary format we want to generate.
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S

# Define the CPU we are targeting, as well as any relevant flags.
MCU = -mcpu=cortex-m0 -mthumb
DEF = -DSTM32F030x6
INC = -I./inc

# Define the compiler flags.
FLG := $(MCU) $(DEF) $(INC) 

# Use the GNU dialect of the C11 standard, which includes specific extensions and conventions provided by GCC.
FLG += -std=gnu11

# Enable strict warnings and treat warnings as errors.
FLG += -Wall -Werror -Wextra -Wpedantic

# Place each variable and function into its own separate section and generate verbose assembly code.
FLG += -fdata-sections -ffunction-sections -fverbose-asm

# The -MMD flag generates a dependency file containing only user-defined headers,
# while the -MP flag adds phony targets to the Makefile for each dependency to ensure they exist.
FLG += -MMD -MP

# Set optimization flags
# ======================
# -Os:      optimize for size
# -g0:      disable generation of debug information
# -DNDEBUG: define a preprocessor macro to disable debugging functionality
# -s:       strip symbol tables from the resulting executable
OPT = -Os -g0 -DNDEBUG -s

# Set the LST variable to generate an assembly listing file if -flto is not set in OPT.
ifeq ($(findstring -flto,$(OPT)), -flto)
  LST =
else
  LST = -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst))
endif

# Linker script for STM32F030F4P6
LDS = stm32f030x6_flash.ld

# Standard libraries for linking
LIB = -lc -lm -lnosys 

# Linker flags: MCU settings, specs, script, and libraries
LDF = $(MCU) -specs=nano.specs -T$(LDS) $(LIB) -flto 

# Map file generation and garbage collection
LDF += -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref,--gc-sections

# Suppress RWX segment warnings
LDF += -Wl,--no-warn-rwx-segment

# Define the build targets and commands.

# Default target builds all targets: elf, hex and bin files.
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin

# Object files are placed into BUILD_DIR directory.
OBJ = $(addprefix $(BUILD_DIR)/,$(notdir $(SRC:.c=.o)))
vpath %.c $(sort $(dir $(SRC)))

OBJ += $(addprefix $(BUILD_DIR)/,$(notdir $(ASM:.s=.o)))
vpath %.s $(sort $(dir $(ASM)))

# Compile C files.
$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR) 
	$(CC) -c $(FLG) $(OPT) -MF"$(@:%.o=%.d)" $(LST) $< -o $@

# Compile assembly files.
$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR)
	$(AS) -c $(FLG) $(OPT) $< -o $@

# Link all object files together into a single ELF file.
$(BUILD_DIR)/$(TARGET).elf: $(OBJ) Makefile
	$(CC) $(OBJ) $(OPT) $(LDF) -o $@
	$(SZ) $@

# Generate a hex file from the ELF file.
$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) $< $@
	
# Generate a binary file from the ELF file.
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(BIN) $< $@	
	

# Create the build directory if it doesn't exist yet.
$(BUILD_DIR):
	mkdir $@

# Set optimization and debugging flags for the debug target.
debug:	OPT = -Og -g3 -gdwarf
debug:	all

# Clean up all generated files.
clean:
	-rm -fR $(BUILD_DIR)

.PHONY: clean all

# Print GCC version information.
gccversion :
	@$(CC) --version

# Program the microcontroller using ST-Link.
program: $(BUILD_DIR)/$(TARGET).hex
	$(STLINK) $(STLINK_FLAGS)
   
# Include any dependency files.
-include $(wildcard $(BUILD_DIR)/*.d)
CREATE_EOF

create_file "stm32f030x6_flash.ld" <<'CREATE_EOF'
/* Entry Point */
ENTRY(Reset_Handler)

/* Highest address of the user mode stack */
_estack = 0x20001000;    /* end of RAM */

/* Generate a link error if heap and stack don't fit into RAM */
_Min_Heap_Size = 0x200;      /* required amount of heap  */
_Min_Stack_Size = 0x400; /* required amount of stack */

/* Specify the memory areas */
MEMORY
{
    RAM (xrw)      : ORIGIN = 0x20000000, LENGTH = 4K
    FLASH (rx)      : ORIGIN = 0x8000000, LENGTH = 32K
}

/* Define output sections */
SECTIONS
{
    /* The startup code goes first into FLASH */
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector)) /* Startup code */
        . = ALIGN(4);
    } >FLASH

    /* The program code and other data goes into FLASH */
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.glue_7)         /* glue arm to thumb code */
        *(.glue_7t)        /* glue thumb to arm code */
        *(.eh_frame)

        KEEP (*(.init))
        KEEP (*(.fini))

        . = ALIGN(4);
        _etext = .;        /* define a global symbols at end of code */
    } >FLASH

    /* Constant data goes into FLASH */
    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        . = ALIGN(4);
    } >FLASH

    .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >FLASH
    .ARM : {
        __exidx_start = .;
        *(.ARM.exidx*)
        __exidx_end = .;
    } >FLASH

    .preinit_array     :
    {
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP (*(.preinit_array*))
        PROVIDE_HIDDEN (__preinit_array_end = .);
    } >FLASH
    .init_array :
    {
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array*))
        PROVIDE_HIDDEN (__init_array_end = .);
    } >FLASH
    .fini_array :
    {
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array*))
        PROVIDE_HIDDEN (__fini_array_end = .);
    } >FLASH

    /* used by the startup to initialize data */
    _sidata = LOADADDR(.data);

    /* Initialized data sections goes into RAM, load LMA copy after code */
    .data : 
    {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start */
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end */
    } >RAM AT> FLASH

    
    /* Uninitialized data section */
    . = ALIGN(4);
    .bss :
    {
        /* This is used by the startup in order to initialize the .bss secion */
        _sbss = .;         /* define a global symbol at bss start */
        __bss_start__ = _sbss;
        *(.bss)
        *(.bss*)
        *(COMMON)

        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end */
        __bss_end__ = _ebss;
    } >RAM

    /* User_heap_stack section, used to check that there is enough RAM left */
    ._user_heap_stack :
    {
        . = ALIGN(8);
        PROVIDE ( end = . );
        PROVIDE ( _end = . );
        . = . + _Min_Heap_Size;
        . = . + _Min_Stack_Size;
        . = ALIGN(8);
    } >RAM

    
    /* Remove information from the standard libraries */
    /DISCARD/ :
    {
        libc.a ( * )
        libm.a ( * )
        libgcc.a ( * )
    }

    .ARM.attributes 0 : { *(.ARM.attributes) }
}
CREATE_EOF

create_file "MDK-ARM/Project.uvprojx" <<'CREATE_EOF'
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<Project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="project_projx.xsd">

  <SchemaVersion>2.1</SchemaVersion>

  <Header>### uVision Project, (C) Keil Software</Header>

  <Targets>
    <Target>
      <TargetName>Debug</TargetName>
      <ToolsetNumber>0x4</ToolsetNumber>
      <ToolsetName>ARM-ADS</ToolsetName>
      <uAC6>1</uAC6>
      <TargetOption>
        <TargetCommonOption>
          <Device>STM32F030F4Px</Device>
          <Vendor>STMicroelectronics</Vendor>
          <Cpu>IRAM(0x20000000,0x00001000) IROM(0x08000000,0x00004000) CPUTYPE("Cortex-M0") CLOCK(8000000) ELITTLE</Cpu>
          <FlashUtilSpec></FlashUtilSpec>
          <StartupFile></StartupFile>
          <FlashDriverDll></FlashDriverDll>
          <DeviceId></DeviceId>
          <RegisterFile></RegisterFile>
          <MemoryEnv></MemoryEnv>
          <Cmp></Cmp>
          <Asm></Asm>
          <Linker></Linker>
          <OHString></OHString>
          <InfinionOptionDll></InfinionOptionDll>
          <SLE66CMisc></SLE66CMisc>
          <SLE66AMisc></SLE66AMisc>
          <SLE66LinkerMisc></SLE66LinkerMisc>
          <SFDFile>$$Device:STM32F030F4Px$CMSIS\SVD\STM32F0x0.svd</SFDFile>
          <bCustSvd>0</bCustSvd>
          <UseEnv>0</UseEnv>
          <BinPath></BinPath>
          <IncludePath></IncludePath>
          <LibPath></LibPath>
          <RegisterFilePath></RegisterFilePath>
          <DBRegisterFilePath></DBRegisterFilePath>
          <TargetStatus>
            <Error>0</Error>
            <ExitCodeStop>0</ExitCodeStop>
            <ButtonStop>0</ButtonStop>
            <NotGenerated>0</NotGenerated>
            <InvalidFlash>1</InvalidFlash>
          </TargetStatus>
          <OutputDirectory>.\Objects\</OutputDirectory>
          <OutputName>Project</OutputName>
          <CreateExecutable>1</CreateExecutable>
          <CreateLib>0</CreateLib>
          <CreateHexFile>1</CreateHexFile>
          <DebugInformation>1</DebugInformation>
          <BrowseInformation>1</BrowseInformation>
          <ListingPath>.\Listings\</ListingPath>
          <HexFormatSelection>1</HexFormatSelection>
          <Merge32K>0</Merge32K>
          <CreateBatchFile>0</CreateBatchFile>
          <BeforeCompile>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopU1X>0</nStopU1X>
            <nStopU2X>0</nStopU2X>
          </BeforeCompile>
          <BeforeMake>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopB1X>0</nStopB1X>
            <nStopB2X>0</nStopB2X>
          </BeforeMake>
          <AfterMake>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopA1X>0</nStopA1X>
            <nStopA2X>0</nStopA2X>
          </AfterMake>
          <SelectedForBatchBuild>0</SelectedForBatchBuild>
          <SVCSIdString></SVCSIdString>
        </TargetCommonOption>
        <CommonProperty>
          <UseCPPCompiler>0</UseCPPCompiler>
          <RVCTCodeConst>0</RVCTCodeConst>
          <RVCTZI>0</RVCTZI>
          <RVCTOtherData>0</RVCTOtherData>
          <ModuleSelection>0</ModuleSelection>
          <IncludeInBuild>1</IncludeInBuild>
          <AlwaysBuild>0</AlwaysBuild>
          <GenerateAssemblyFile>0</GenerateAssemblyFile>
          <AssembleAssemblyFile>0</AssembleAssemblyFile>
          <PublicsOnly>0</PublicsOnly>
          <StopOnExitCode>3</StopOnExitCode>
          <CustomArgument></CustomArgument>
          <IncludeLibraryModules></IncludeLibraryModules>
          <ComprImg>1</ComprImg>
        </CommonProperty>
        <DllOption>
          <SimDllName>SARMCM3.DLL</SimDllName>
          <SimDllArguments> -REMAP </SimDllArguments>
          <SimDlgDll>DARMCM1.DLL</SimDlgDll>
          <SimDlgDllArguments>-pCM0</SimDlgDllArguments>
          <TargetDllName>SARMCM3.DLL</TargetDllName>
          <TargetDllArguments> </TargetDllArguments>
          <TargetDlgDll>TARMCM1.DLL</TargetDlgDll>
          <TargetDlgDllArguments>-pCM0</TargetDlgDllArguments>
        </DllOption>
        <DebugOption>
          <OPTHX>
            <HexSelection>1</HexSelection>
            <HexRangeLowAddress>0</HexRangeLowAddress>
            <HexRangeHighAddress>0</HexRangeHighAddress>
            <HexOffset>0</HexOffset>
            <Oh166RecLen>16</Oh166RecLen>
          </OPTHX>
        </DebugOption>
        <Utilities>
          <Flash1>
            <UseTargetDll>1</UseTargetDll>
            <UseExternalTool>0</UseExternalTool>
            <RunIndependent>0</RunIndependent>
            <UpdateFlashBeforeDebugging>1</UpdateFlashBeforeDebugging>
            <Capability>1</Capability>
            <DriverSelection>4096</DriverSelection>
          </Flash1>
          <bUseTDR>1</bUseTDR>
          <Flash2>BIN\UL2CM3.DLL</Flash2>
          <Flash3></Flash3>
          <Flash4></Flash4>
          <pFcarmOut></pFcarmOut>
          <pFcarmGrp></pFcarmGrp>
          <pFcArmRoot></pFcArmRoot>
          <FcArmLst>0</FcArmLst>
        </Utilities>
        <TargetArmAds>
          <ArmAdsMisc>
            <GenerateListings>0</GenerateListings>
            <asHll>1</asHll>
            <asAsm>1</asAsm>
            <asMacX>1</asMacX>
            <asSyms>1</asSyms>
            <asFals>1</asFals>
            <asDbgD>1</asDbgD>
            <asForm>1</asForm>
            <ldLst>0</ldLst>
            <ldmm>1</ldmm>
            <ldXref>1</ldXref>
            <BigEnd>0</BigEnd>
            <AdsALst>1</AdsALst>
            <AdsACrf>1</AdsACrf>
            <AdsANop>0</AdsANop>
            <AdsANot>0</AdsANot>
            <AdsLLst>1</AdsLLst>
            <AdsLmap>1</AdsLmap>
            <AdsLcgr>1</AdsLcgr>
            <AdsLsym>1</AdsLsym>
            <AdsLszi>1</AdsLszi>
            <AdsLtoi>1</AdsLtoi>
            <AdsLsun>1</AdsLsun>
            <AdsLven>1</AdsLven>
            <AdsLsxf>1</AdsLsxf>
            <RvctClst>0</RvctClst>
            <GenPPlst>0</GenPPlst>
            <AdsCpuType>"Cortex-M0"</AdsCpuType>
            <RvctDeviceName></RvctDeviceName>
            <mOS>0</mOS>
            <uocRom>0</uocRom>
            <uocRam>0</uocRam>
            <hadIROM>1</hadIROM>
            <hadIRAM>1</hadIRAM>
            <hadXRAM>0</hadXRAM>
            <uocXRam>0</uocXRam>
            <RvdsVP>0</RvdsVP>
            <RvdsMve>0</RvdsMve>
            <RvdsCdeCp>0</RvdsCdeCp>
            <hadIRAM2>0</hadIRAM2>
            <hadIROM2>0</hadIROM2>
            <StupSel>8</StupSel>
            <useUlib>1</useUlib>
            <EndSel>0</EndSel>
            <uLtcg>0</uLtcg>
            <nSecure>0</nSecure>
            <RoSelD>3</RoSelD>
            <RwSelD>3</RwSelD>
            <CodeSel>0</CodeSel>
            <OptFeed>0</OptFeed>
            <NoZi1>0</NoZi1>
            <NoZi2>0</NoZi2>
            <NoZi3>0</NoZi3>
            <NoZi4>0</NoZi4>
            <NoZi5>0</NoZi5>
            <Ro1Chk>0</Ro1Chk>
            <Ro2Chk>0</Ro2Chk>
            <Ro3Chk>0</Ro3Chk>
            <Ir1Chk>1</Ir1Chk>
            <Ir2Chk>0</Ir2Chk>
            <Ra1Chk>0</Ra1Chk>
            <Ra2Chk>0</Ra2Chk>
            <Ra3Chk>0</Ra3Chk>
            <Im1Chk>1</Im1Chk>
            <Im2Chk>0</Im2Chk>
            <OnChipMemories>
              <Ocm1>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm1>
              <Ocm2>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm2>
              <Ocm3>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm3>
              <Ocm4>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm4>
              <Ocm5>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm5>
              <Ocm6>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm6>
              <IRAM>
                <Type>0</Type>
                <StartAddress>0x20000000</StartAddress>
                <Size>0x1000</Size>
              </IRAM>
              <IROM>
                <Type>1</Type>
                <StartAddress>0x8000000</StartAddress>
                <Size>0x4000</Size>
              </IROM>
              <XRAM>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </XRAM>
              <OCR_RVCT1>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT1>
              <OCR_RVCT2>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT2>
              <OCR_RVCT3>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT3>
              <OCR_RVCT4>
                <Type>1</Type>
                <StartAddress>0x8000000</StartAddress>
                <Size>0x4000</Size>
              </OCR_RVCT4>
              <OCR_RVCT5>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT5>
              <OCR_RVCT6>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT6>
              <OCR_RVCT7>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT7>
              <OCR_RVCT8>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT8>
              <OCR_RVCT9>
                <Type>0</Type>
                <StartAddress>0x20000000</StartAddress>
                <Size>0x1000</Size>
              </OCR_RVCT9>
              <OCR_RVCT10>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT10>
            </OnChipMemories>
            <RvctStartVector></RvctStartVector>
          </ArmAdsMisc>
          <Cads>
            <interw>1</interw>
            <Optim>1</Optim>
            <oTime>0</oTime>
            <SplitLS>0</SplitLS>
            <OneElfS>1</OneElfS>
            <Strict>0</Strict>
            <EnumInt>0</EnumInt>
            <PlainCh>0</PlainCh>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <wLevel>2</wLevel>
            <uThumb>0</uThumb>
            <uSurpInc>0</uSurpInc>
            <uC99>0</uC99>
            <uGnu>0</uGnu>
            <useXO>0</useXO>
            <v6Lang>6</v6Lang>
            <v6LangP>9</v6LangP>
            <vShortEn>1</vShortEn>
            <vShortWch>1</vShortWch>
            <v6Lto>0</v6Lto>
            <v6WtE>1</v6WtE>
            <v6Rtti>0</v6Rtti>
            <VariousControls>
              <MiscControls>-Wpedantic -Wextra</MiscControls>
              <Define>DEBUG</Define>
              <Undefine></Undefine>
              <IncludePath>../inc</IncludePath>
            </VariousControls>
          </Cads>
          <Aads>
            <interw>1</interw>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <thumb>0</thumb>
            <SplitLS>0</SplitLS>
            <SwStkChk>0</SwStkChk>
            <NoWarn>0</NoWarn>
            <uSurpInc>0</uSurpInc>
            <useXO>0</useXO>
            <ClangAsOpt>1</ClangAsOpt>
            <VariousControls>
              <MiscControls></MiscControls>
              <Define></Define>
              <Undefine></Undefine>
              <IncludePath></IncludePath>
            </VariousControls>
          </Aads>
          <LDads>
            <umfTarg>1</umfTarg>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <noStLib>0</noStLib>
            <RepFail>1</RepFail>
            <useFile>0</useFile>
            <TextAddressRange>0x08000000</TextAddressRange>
            <DataAddressRange>0x20000000</DataAddressRange>
            <pXoBase></pXoBase>
            <ScatterFile></ScatterFile>
            <IncludeLibs></IncludeLibs>
            <IncludeLibsPath></IncludeLibsPath>
            <Misc></Misc>
            <LinkerInputFile></LinkerInputFile>
            <DisabledWarnings></DisabledWarnings>
          </LDads>
        </TargetArmAds>
      </TargetOption>
      <Groups>
        <Group>
          <GroupName>src</GroupName>
          <Files>
            <File>
              <FileName>main.c</FileName>
              <FileType>1</FileType>
              <FilePath>..\src\main.c</FilePath>
            </File>
            <File>
              <FileName>startup_stm32f030x6.s</FileName>
              <FileType>2</FileType>
              <FilePath>..\MDK-ARM\startup_stm32f030x6.s</FilePath>
            </File>
            <File>
              <FileName>system_stm32f0xx.c</FileName>
              <FileType>1</FileType>
              <FilePath>..\src\system_stm32f0xx.c</FilePath>
            </File>
          </Files>
        </Group>
      </Groups>
    </Target>
    <Target>
      <TargetName>Release</TargetName>
      <ToolsetNumber>0x4</ToolsetNumber>
      <ToolsetName>ARM-ADS</ToolsetName>
      <uAC6>1</uAC6>
      <TargetOption>
        <TargetCommonOption>
          <Device>STM32F030F4Px</Device>
          <Vendor>STMicroelectronics</Vendor>
          <Cpu>IRAM(0x20000000,0x00001000) IROM(0x08000000,0x00004000) CPUTYPE("Cortex-M0") CLOCK(8000000) ELITTLE</Cpu>
          <FlashUtilSpec></FlashUtilSpec>
          <StartupFile></StartupFile>
          <FlashDriverDll></FlashDriverDll>
          <DeviceId></DeviceId>
          <RegisterFile></RegisterFile>
          <MemoryEnv></MemoryEnv>
          <Cmp></Cmp>
          <Asm></Asm>
          <Linker></Linker>
          <OHString></OHString>
          <InfinionOptionDll></InfinionOptionDll>
          <SLE66CMisc></SLE66CMisc>
          <SLE66AMisc></SLE66AMisc>
          <SLE66LinkerMisc></SLE66LinkerMisc>
          <SFDFile>$$Device:STM32F030F4Px$CMSIS\SVD\STM32F0x0.svd</SFDFile>
          <bCustSvd>0</bCustSvd>
          <UseEnv>0</UseEnv>
          <BinPath></BinPath>
          <IncludePath></IncludePath>
          <LibPath></LibPath>
          <RegisterFilePath></RegisterFilePath>
          <DBRegisterFilePath></DBRegisterFilePath>
          <TargetStatus>
            <Error>0</Error>
            <ExitCodeStop>0</ExitCodeStop>
            <ButtonStop>0</ButtonStop>
            <NotGenerated>0</NotGenerated>
            <InvalidFlash>1</InvalidFlash>
          </TargetStatus>
          <OutputDirectory>.\Objects\</OutputDirectory>
          <OutputName>Project</OutputName>
          <CreateExecutable>1</CreateExecutable>
          <CreateLib>0</CreateLib>
          <CreateHexFile>1</CreateHexFile>
          <DebugInformation>0</DebugInformation>
          <BrowseInformation>0</BrowseInformation>
          <ListingPath>.\Listings\</ListingPath>
          <HexFormatSelection>1</HexFormatSelection>
          <Merge32K>0</Merge32K>
          <CreateBatchFile>0</CreateBatchFile>
          <BeforeCompile>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopU1X>0</nStopU1X>
            <nStopU2X>0</nStopU2X>
          </BeforeCompile>
          <BeforeMake>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopB1X>0</nStopB1X>
            <nStopB2X>0</nStopB2X>
          </BeforeMake>
          <AfterMake>
            <RunUserProg1>0</RunUserProg1>
            <RunUserProg2>0</RunUserProg2>
            <UserProg1Name></UserProg1Name>
            <UserProg2Name></UserProg2Name>
            <UserProg1Dos16Mode>0</UserProg1Dos16Mode>
            <UserProg2Dos16Mode>0</UserProg2Dos16Mode>
            <nStopA1X>0</nStopA1X>
            <nStopA2X>0</nStopA2X>
          </AfterMake>
          <SelectedForBatchBuild>0</SelectedForBatchBuild>
          <SVCSIdString></SVCSIdString>
        </TargetCommonOption>
        <CommonProperty>
          <UseCPPCompiler>0</UseCPPCompiler>
          <RVCTCodeConst>0</RVCTCodeConst>
          <RVCTZI>0</RVCTZI>
          <RVCTOtherData>0</RVCTOtherData>
          <ModuleSelection>0</ModuleSelection>
          <IncludeInBuild>1</IncludeInBuild>
          <AlwaysBuild>0</AlwaysBuild>
          <GenerateAssemblyFile>0</GenerateAssemblyFile>
          <AssembleAssemblyFile>0</AssembleAssemblyFile>
          <PublicsOnly>0</PublicsOnly>
          <StopOnExitCode>3</StopOnExitCode>
          <CustomArgument></CustomArgument>
          <IncludeLibraryModules></IncludeLibraryModules>
          <ComprImg>1</ComprImg>
        </CommonProperty>
        <DllOption>
          <SimDllName>SARMCM3.DLL</SimDllName>
          <SimDllArguments> -REMAP </SimDllArguments>
          <SimDlgDll>DARMCM1.DLL</SimDlgDll>
          <SimDlgDllArguments>-pCM0</SimDlgDllArguments>
          <TargetDllName>SARMCM3.DLL</TargetDllName>
          <TargetDllArguments> </TargetDllArguments>
          <TargetDlgDll>TARMCM1.DLL</TargetDlgDll>
          <TargetDlgDllArguments>-pCM0</TargetDlgDllArguments>
        </DllOption>
        <DebugOption>
          <OPTHX>
            <HexSelection>1</HexSelection>
            <HexRangeLowAddress>0</HexRangeLowAddress>
            <HexRangeHighAddress>0</HexRangeHighAddress>
            <HexOffset>0</HexOffset>
            <Oh166RecLen>16</Oh166RecLen>
          </OPTHX>
        </DebugOption>
        <Utilities>
          <Flash1>
            <UseTargetDll>1</UseTargetDll>
            <UseExternalTool>0</UseExternalTool>
            <RunIndependent>0</RunIndependent>
            <UpdateFlashBeforeDebugging>1</UpdateFlashBeforeDebugging>
            <Capability>1</Capability>
            <DriverSelection>4096</DriverSelection>
          </Flash1>
          <bUseTDR>1</bUseTDR>
          <Flash2>BIN\UL2CM3.DLL</Flash2>
          <Flash3>"" ()</Flash3>
          <Flash4></Flash4>
          <pFcarmOut></pFcarmOut>
          <pFcarmGrp></pFcarmGrp>
          <pFcArmRoot></pFcArmRoot>
          <FcArmLst>0</FcArmLst>
        </Utilities>
        <TargetArmAds>
          <ArmAdsMisc>
            <GenerateListings>0</GenerateListings>
            <asHll>1</asHll>
            <asAsm>1</asAsm>
            <asMacX>1</asMacX>
            <asSyms>1</asSyms>
            <asFals>1</asFals>
            <asDbgD>1</asDbgD>
            <asForm>1</asForm>
            <ldLst>0</ldLst>
            <ldmm>1</ldmm>
            <ldXref>1</ldXref>
            <BigEnd>0</BigEnd>
            <AdsALst>0</AdsALst>
            <AdsACrf>1</AdsACrf>
            <AdsANop>0</AdsANop>
            <AdsANot>0</AdsANot>
            <AdsLLst>1</AdsLLst>
            <AdsLmap>1</AdsLmap>
            <AdsLcgr>1</AdsLcgr>
            <AdsLsym>1</AdsLsym>
            <AdsLszi>1</AdsLszi>
            <AdsLtoi>1</AdsLtoi>
            <AdsLsun>1</AdsLsun>
            <AdsLven>1</AdsLven>
            <AdsLsxf>1</AdsLsxf>
            <RvctClst>0</RvctClst>
            <GenPPlst>0</GenPPlst>
            <AdsCpuType>"Cortex-M0"</AdsCpuType>
            <RvctDeviceName></RvctDeviceName>
            <mOS>0</mOS>
            <uocRom>0</uocRom>
            <uocRam>0</uocRam>
            <hadIROM>1</hadIROM>
            <hadIRAM>1</hadIRAM>
            <hadXRAM>0</hadXRAM>
            <uocXRam>0</uocXRam>
            <RvdsVP>0</RvdsVP>
            <RvdsMve>0</RvdsMve>
            <RvdsCdeCp>0</RvdsCdeCp>
            <hadIRAM2>0</hadIRAM2>
            <hadIROM2>0</hadIROM2>
            <StupSel>8</StupSel>
            <useUlib>1</useUlib>
            <EndSel>0</EndSel>
            <uLtcg>0</uLtcg>
            <nSecure>0</nSecure>
            <RoSelD>3</RoSelD>
            <RwSelD>3</RwSelD>
            <CodeSel>0</CodeSel>
            <OptFeed>0</OptFeed>
            <NoZi1>0</NoZi1>
            <NoZi2>0</NoZi2>
            <NoZi3>0</NoZi3>
            <NoZi4>0</NoZi4>
            <NoZi5>0</NoZi5>
            <Ro1Chk>0</Ro1Chk>
            <Ro2Chk>0</Ro2Chk>
            <Ro3Chk>0</Ro3Chk>
            <Ir1Chk>1</Ir1Chk>
            <Ir2Chk>0</Ir2Chk>
            <Ra1Chk>0</Ra1Chk>
            <Ra2Chk>0</Ra2Chk>
            <Ra3Chk>0</Ra3Chk>
            <Im1Chk>1</Im1Chk>
            <Im2Chk>0</Im2Chk>
            <OnChipMemories>
              <Ocm1>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm1>
              <Ocm2>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm2>
              <Ocm3>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm3>
              <Ocm4>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm4>
              <Ocm5>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm5>
              <Ocm6>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </Ocm6>
              <IRAM>
                <Type>0</Type>
                <StartAddress>0x20000000</StartAddress>
                <Size>0x1000</Size>
              </IRAM>
              <IROM>
                <Type>1</Type>
                <StartAddress>0x8000000</StartAddress>
                <Size>0x4000</Size>
              </IROM>
              <XRAM>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </XRAM>
              <OCR_RVCT1>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT1>
              <OCR_RVCT2>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT2>
              <OCR_RVCT3>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT3>
              <OCR_RVCT4>
                <Type>1</Type>
                <StartAddress>0x8000000</StartAddress>
                <Size>0x4000</Size>
              </OCR_RVCT4>
              <OCR_RVCT5>
                <Type>1</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT5>
              <OCR_RVCT6>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT6>
              <OCR_RVCT7>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT7>
              <OCR_RVCT8>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT8>
              <OCR_RVCT9>
                <Type>0</Type>
                <StartAddress>0x20000000</StartAddress>
                <Size>0x1000</Size>
              </OCR_RVCT9>
              <OCR_RVCT10>
                <Type>0</Type>
                <StartAddress>0x0</StartAddress>
                <Size>0x0</Size>
              </OCR_RVCT10>
            </OnChipMemories>
            <RvctStartVector></RvctStartVector>
          </ArmAdsMisc>
          <Cads>
            <interw>1</interw>
            <Optim>6</Optim>
            <oTime>0</oTime>
            <SplitLS>0</SplitLS>
            <OneElfS>1</OneElfS>
            <Strict>0</Strict>
            <EnumInt>0</EnumInt>
            <PlainCh>0</PlainCh>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <wLevel>2</wLevel>
            <uThumb>0</uThumb>
            <uSurpInc>0</uSurpInc>
            <uC99>0</uC99>
            <uGnu>0</uGnu>
            <useXO>0</useXO>
            <v6Lang>6</v6Lang>
            <v6LangP>9</v6LangP>
            <vShortEn>1</vShortEn>
            <vShortWch>1</vShortWch>
            <v6Lto>1</v6Lto>
            <v6WtE>1</v6WtE>
            <v6Rtti>0</v6Rtti>
            <VariousControls>
              <MiscControls>-Wpedantic -Wextra</MiscControls>
              <Define>NDEBUG</Define>
              <Undefine></Undefine>
              <IncludePath>../inc</IncludePath>
            </VariousControls>
          </Cads>
          <Aads>
            <interw>1</interw>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <thumb>0</thumb>
            <SplitLS>0</SplitLS>
            <SwStkChk>0</SwStkChk>
            <NoWarn>0</NoWarn>
            <uSurpInc>0</uSurpInc>
            <useXO>0</useXO>
            <ClangAsOpt>1</ClangAsOpt>
            <VariousControls>
              <MiscControls></MiscControls>
              <Define></Define>
              <Undefine></Undefine>
              <IncludePath></IncludePath>
            </VariousControls>
          </Aads>
          <LDads>
            <umfTarg>1</umfTarg>
            <Ropi>0</Ropi>
            <Rwpi>0</Rwpi>
            <noStLib>0</noStLib>
            <RepFail>1</RepFail>
            <useFile>0</useFile>
            <TextAddressRange>0x08000000</TextAddressRange>
            <DataAddressRange>0x20000000</DataAddressRange>
            <pXoBase></pXoBase>
            <ScatterFile></ScatterFile>
            <IncludeLibs></IncludeLibs>
            <IncludeLibsPath></IncludeLibsPath>
            <Misc></Misc>
            <LinkerInputFile></LinkerInputFile>
            <DisabledWarnings></DisabledWarnings>
          </LDads>
        </TargetArmAds>
      </TargetOption>
      <Groups>
        <Group>
          <GroupName>src</GroupName>
          <Files>
            <File>
              <FileName>main.c</FileName>
              <FileType>1</FileType>
              <FilePath>..\src\main.c</FilePath>
            </File>
            <File>
              <FileName>startup_stm32f030x6.s</FileName>
              <FileType>2</FileType>
              <FilePath>..\MDK-ARM\startup_stm32f030x6.s</FilePath>
            </File>
            <File>
              <FileName>system_stm32f0xx.c</FileName>
              <FileType>1</FileType>
              <FilePath>..\src\system_stm32f0xx.c</FilePath>
            </File>
          </Files>
        </Group>
      </Groups>
    </Target>
  </Targets>

  <RTE>
    <apis/>
    <components/>
    <files/>
  </RTE>

  <LayerInfo>
    <Layers>
      <Layer>
        <LayName>Project</LayName>
        <LayPrjMark>1</LayPrjMark>
      </Layer>
    </Layers>
  </LayerInfo>

</Project>
CREATE_EOF

create_file "project.jdebug" <<'CREATE_EOF'
void OnProjectLoad (void) {
  Project.AddPathSubstitute (".", "$(ProjectDir)");
  Project.AddPathSubstitute (".", "$(ProjectDir)");
  Project.SetDevice ("STM32F030F4");
  Project.SetHostIF ("USB", "");
  Project.SetTargetIF ("SWD");
  Project.SetTIFSpeed ("4 MHz");
  Project.AddSvdFile ("$(InstallDir)/Config/CPU/Cortex-M0.svd");
  Project.AddSvdFile ("$(InstallDir)/Config/Peripherals/ARMv6M.svd");
  Project.AddSvdFile ("$(ProjectDir)/STM32F031x.svd");
  File.Open ("$(ProjectDir)/_build/Project.elf");
}

void AfterTargetReset (void) {
  _SetupTarget();
}

void AfterTargetDownload (void) {
  _SetupTarget();
}

void _SetupTarget(void) {
  unsigned int SP;
  unsigned int PC;
  unsigned int VectorTableAddr;

  VectorTableAddr = Elf.GetBaseAddr();
  SP = Target.ReadU32(VectorTableAddr);
  if (SP != 0xFFFFFFFF) {
    Target.SetReg("SP", SP);
  }
  PC = Elf.GetEntryPointPC();
  if (PC != 0xFFFFFFFF) {
    Target.SetReg("PC", PC);
  } else {
    Util.Error("Project script error: failed to set up entry point PC", 1);
  }
}
CREATE_EOF

create_file "inc/main.h" <<'CREATE_EOF'
#ifndef __MAIN_H__
#define __MAIN_H__

#ifdef __cplusplus /* provide compatibility between C and C++ */
  extern "C" {
#endif

#define NO                             0
#define NONE                           NO
#define OFF                            NO
#define YES                            (!NO)
#define ON                             YES

#define HCLK                           8    /* 8 to 64 (MHz) with a step of 4               */

#define SYSTICK_CLOCK_SOURCE           0    /* 0 = HCLK / 8; 1 = HCLK                       */
#define SYSTICK_EN                     YES  /* Set to YES to enable systick, NO otherwise   */
#define SYSTICK_IRQ_EN                 NO   /* Enable interrupt: YES, Disable interrupt: NO */

#include "stm32f030x6.h" /* Include CMSIS header file */

/* Uncomment corresponding line if using the peripheral is intended. */
// #include "pwr.h"
// #include "ob.h"
// #include "tim.h"
// #include "rtc.h"
// #include "wwdg.h"
// #include "iwdg.h"
// #include "i2c.h"
// #include "syscfg.h"
// #include "exti.h"
// #include "adc.h"
// #include "spi.h"
// #include "usart.h"
// #include "dbgmcu.h"
// #include "dma.h"
// #include "crc.h"
// #include "flash.h"

#include "gpio.h"
#include "rcc.h"


__STATIC_FORCEINLINE void init_systick(void);


/* Initialize all the required peripherals */
__STATIC_FORCEINLINE void init(void) {

#if(defined(FLASH_EN) && FLASH_EN)
  init_flash();
#endif

  /* RCC should always be initialized as it is essential peripheral for the functioning of the system. */
  init_rcc();

#if(defined(PWR_EN) && PWR_EN)
  init_pwr();
#endif

#if(defined(OB_EN) && OB_EN)
  init_ob();
#endif

#if(defined(TIM1_EN) && TIM1_EN) || (defined(TIM3_EN) && TIM3_EN) || (defined(TIM14_EN) && TIM14_EN) || (defined(TIM16_EN) && TIM16_EN) || (defined(TIM17_EN) && TIM17_EN)
  init_tim();
#endif

#if(defined(RTC_EN) && RTC_EN)
  init_rtc();
#endif

#if(defined(WWDG_EN) && WWDG_EN)
  init_wwdg();
#endif

#if(defined(IWDG_EN) && IWDG_EN)
  init_iwdg();
#endif

#if(defined(I2C1_EN) && I2C1_EN)
  init_i2c();
#endif

#if(defined(SYSCFG_EN) && SYSCFG_EN)
  init_syscfg();
#endif

#if(defined(EXTI_EN) && EXTI_EN)
  init_exti();
#endif

#if(defined(ADC1_EN) && ADC1_EN)
  init_adc();
#endif

#if(defined(SPI1_EN) && SPI1_EN)
  init_spi();
#endif

#if(defined(USART1_EN) && USART1_EN)
  init_usart();
#endif

#if(defined(DBGMCU_EN) && DBGMCU_EN)
  init_dbgmcu();
#endif

#if(defined(DMA1_EN) && DMA1_EN)
  init_dma();
#endif

#if(defined(CRC_EN) && CRC_EN)
  init_crc();
#endif

  /* GPIO should always be initialized as it is essential peripheral for the functioning of the system. */
  init_gpio();

  /* Perform additional steps after initialization */
  init_systick();

} /* init() */


__STATIC_FORCEINLINE void init_systick(void) {

  /* Initialize SysTick to 1 ms period */

  SysTick->LOAD = HCLK * 1000 / (8 - SYSTICK_CLOCK_SOURCE * 7) - 1;
  SysTick->VAL  = SysTick->LOAD;
  SysTick->CTRL = (
    + SYSTICK_CLOCK_SOURCE * SysTick_CTRL_CLKSOURCE_Msk
    + SYSTICK_IRQ_EN       * SysTick_CTRL_TICKINT_Msk
    + SYSTICK_EN           * SysTick_CTRL_ENABLE_Msk
  );
} /* init_systick() */


__STATIC_FORCEINLINE void idle(void); // {
  /* The body of the main program loop follows here */


//} /* idle() */

#if YES == SYSTICK_IRQ_EN
  #define __SYSTICK_VOLATILE volatile
#else
  #define __SYSTICK_VOLATILE
#endif

#if defined(__GNUC__) && ! defined(__clang__)
  void _close_r(void){} void _close(void){} void _lseek_r(void){} void _lseek(void){} void _read_r(void){} void _read(void){} void _write_r(void){}
#endif

////////////////////////////////////////////////////////////////////////////////////////
//  This code was generated for the stm32f030x6 microcontroller by "stm32cgen" tool.
//                          https://github.com/a5021/stm32codegen                          
//  Arguments used:
//    -l 030f4 -M -D NO 0 NONE NO OFF NO YES (!NO) ON YES "" HCLK "8    /* 8 to 64
//    (MHz) with a step of 4               */" "" SYSTICK_CLOCK_SOURCE "0    /* 0 =
//    HCLK / 8; 1 = HCLK                       */" SYSTICK_EN "YES  /* Set to YES to
//    enable systick, NO otherwise   */" SYSTICK_IRQ_EN "NO   /* Enable interrupt:
//    YES, Disable interrupt: NO */" --force-inline --post-init init_systick -F "" -F
//    "__STATIC_FORCEINLINE void init_systick(void) {" -F "" -F "  /* Initialize
//    SysTick to 1 ms period */" -F "" -F "  SysTick->LOAD = HCLK * 1000 / (8 -
//    SYSTICK_CLOCK_SOURCE * 7) - 1;" -F "  SysTick->VAL  = SysTick->LOAD;" -F "
//    SysTick->CTRL = (" -F "    + SYSTICK_CLOCK_SOURCE * SysTick_CTRL_CLKSOURCE_Msk"
//    -F "    + SYSTICK_IRQ_EN       * SysTick_CTRL_TICKINT_Msk" -F "    + SYSTICK_EN
//    * SysTick_CTRL_ENABLE_Msk" -F "  );" -F "} /* init_systick() */" -F "" -F "" -F
//    "__STATIC_FORCEINLINE void idle(void); // {" -F "  /* The body of the main
//    program loop follows here */" -F "" -F "" -F "//} /* idle() */" -F "" -F "#if
//    YES == SYSTICK_IRQ_EN" -F "  #define __SYSTICK_VOLATILE volatile" -F #else -F "
//    #define __SYSTICK_VOLATILE" -F #endif -F "" -F "#if defined(__GNUC__) && !
//    defined(__clang__)" -F "  void _close_r(void){} void _close(void){} void
//    _lseek_r(void){} void _lseek(void){} void _read_r(void){} void _read(void){}
//    void _write_r(void){}" -F #endif
////////////////////////////////////////////////////////////////////////////////////////


#ifdef __cplusplus
  }
#endif /* __cplusplus */
#endif /* __MAIN_H__ */

CREATE_EOF

create_file "inc/gpio.h" <<'CREATE_EOF'
#ifndef __GPIO_H__
#define __GPIO_H__

#ifdef __cplusplus
  extern "C" {
#endif


#define USE_ANALOG_MODE_FOR_ALL_PINS_BY_DEFALUT        1

#define GPIO_MODE                      (USE_ANALOG_MODE_FOR_ALL_PINS_BY_DEFALUT * UINT32_MAX)
#define PIN_XOR                        (GPIO_MODE & 3UL)

#define PIN_MODE_INPUT                 (0x00UL ^ PIN_XOR)
#define PIN_MODE_OUTPUT                (0x01UL ^ PIN_XOR)
#define PIN_MODE_AF                    (0x02UL ^ PIN_XOR)
#define PIN_MODE_ANALOG                (0x03UL ^ PIN_XOR)

#define PIN_CFG(PIN, MODE)             ((MODE)   << ((PIN) * 2))
#define PIN_MODE(PIN, MODE)            (((MODE)  << GPIO_MODER_MODER ## PIN ## _Pos) & GPIO_MODER_MODER ## PIN ## _Msk)
#define PIN_SPEED(PIN, SPEED)          (((SPEED) << GPIO_OSPEEDR_OSPEEDR ## PIN ## _Pos) & GPIO_OSPEEDR_OSPEEDR ## PIN ## _Msk)
#define PIN_OTYPE(PIN, OTYPE)          ((OTYPE)   ? GPIO_OTYPER_OT_ ## PIN : 0)
#define PIN_PUPD(PIN, PUPD)            (((PUPD)  << GPIO_PUPDR_PUPDR ## PIN ## _Pos) & GPIO_PUPDR_PUPDR ## PIN ## _Msk)
#define PIN_AF(PIN, AF)                (AF << (PIN * 4))

#define PA0_AF1_USART1_CTS             PIN_AF(0, 1ULL)
#define PA1_AF0_EVENTOUT               PIN_AF(1, 0ULL)
#define PA1_AF1_USART1_RTS             PIN_AF(1, 1ULL)
#define PA2_AF1_USART1_TX              PIN_AF(2, 1ULL)
#define PA3_AF1_USART1_RX              PIN_AF(3, 1ULL)
#define PA4_AF0_SPI1_NSS               PIN_AF(4, 0ULL)
#define PA4_AF1_USART1_CK              PIN_AF(4, 1ULL)
#define PA4_AF4_TIM14_CH1              PIN_AF(4, 4ULL)
#define PA5_AF0_SPI1_SCK               PIN_AF(5, 0ULL)
#define PA6_AF0_SPI1_MISO              PIN_AF(6, 0ULL)
#define PA6_AF1_TIM3_CH1               PIN_AF(6, 1ULL)
#define PA6_AF2_TIM1_BKIN              PIN_AF(6, 2ULL)
#define PA6_AF5_TIM16_CH1              PIN_AF(6, 5ULL)
#define PA6_AF6_EVENTOUT               PIN_AF(6, 6ULL)
#define PA7_AF0_SPI1_MOSI              PIN_AF(7, 0ULL)
#define PA7_AF1_TIM3_CH2               PIN_AF(7, 1ULL)
#define PA7_AF2_TIM1_CH1N              PIN_AF(7, 2ULL)
#define PA7_AF4_TIM14_CH1              PIN_AF(7, 4ULL)
#define PA7_AF5_TIM17_CH1              PIN_AF(7, 5ULL)
#define PA7_AF6_EVENTOUT               PIN_AF(7, 6ULL)
#define PA9_AF1_USART1_TX              PIN_AF(9, 1ULL)
#define PA9_AF2_TIM1_CH2               PIN_AF(9, 2ULL)
#define PA9_AF4_I2C1_SCL               PIN_AF(9, 4ULL)
#define PA10_AF0_TIM17_BKIN            PIN_AF(10, 0ULL)
#define PA10_AF1_USART1_RX             PIN_AF(10, 1ULL)
#define PA10_AF2_TIM1_CH3              PIN_AF(10, 2ULL)
#define PA10_AF4_I2C1_SDA              PIN_AF(10, 4ULL)
#define PA13_AF0_SWDIO                 PIN_AF(13, 0ULL)
#define PA13_AF1_IR_OUT                PIN_AF(13, 1ULL)
#define PA14_AF0_SWCLK                 PIN_AF(14, 0ULL)
#define PA14_AF1_USART1_TX             PIN_AF(14, 1ULL)

#define PB1_AF0_TIM14_CH1              PIN_AF(1, 0ULL)
#define PB1_AF1_TIM3_CH4               PIN_AF(1, 1ULL)
#define PB1_AF2_TIM1_CH3N              PIN_AF(1, 2ULL)

#define PIN_TYPE_PP                    0x00UL
#define PIN_TYPE_OD                    0x01UL

#define PIN_SPEED_LOW                  0x00UL
#define PIN_SPEED_MED                  0x01UL
#define PIN_SPEED_HIGH                 0x03UL

#define PIN_PUPD_NONE                  0x00UL
#define PIN_PUPD_UP                    0x01UL
#define PIN_PUPD_DOWN                  0x02UL

#define _BR(PIN)                       GPIO_BSRR_BR_ ## PIN
#define BR(PIN)                        _BR(PIN)
#define _BS(PIN)                       GPIO_BSRR_BS_ ## PIN
#define BS(PIN)                        _BS(PIN)
#define _ODR(PIN)                      GPIO_ODR_ ## PIN
#define ODR(PIN)                       _ODR(PIN)

#define GPIOA_MODER                    (GPIO_MODE ^ (GPIOA_MODE))
#define GPIOB_MODER                    (GPIO_MODE ^ (GPIOB_MODE))
#define GPIOF_MODER                    (GPIO_MODE ^ (GPIOF_MODE))

#define GPIOA_AFR_0                    (GPIOA_AF & UINT32_MAX)
#define GPIOA_AFR_1                    ((GPIOA_AF >> 32) & UINT32_MAX)

#define GPIOB_AFR_0                    (GPIOB_AF & UINT32_MAX)
#define GPIOB_AFR_1                    ((GPIOB_AF >> 32) & UINT32_MAX)


#define CONFIGURE_PIN(GPIOx, PIN, MODE, OTYPE, SPEED, PUPD) do {                               \
  if (MODE)   MODIFY_REG((GPIOx)->MODER,   (0x03UL << ((PIN) * 2)), ((MODE)  << ((PIN) * 2))); \
  if (SPEED)  MODIFY_REG((GPIOx)->OSPEEDR, (0x03UL << ((PIN) * 2)), ((SPEED) << ((PIN) * 2))); \
  if (PUPD)   MODIFY_REG((GPIOx)->PUPDR,   (0x03UL << ((PIN) * 2)), ((PUPD)  << ((PIN) * 2))); \
  if (OTYPE)  MODIFY_REG((GPIOx)->OTYPER,  (0x01UL << (PIN)),       ((OTYPE) << (PIN)));       \
}while(0)

#ifndef USART1_EN
  #define USART1_EN 0
#endif

#ifndef SPI1_EN
  #define SPI1_EN 0
#endif

#ifndef I2C1_EN
  #define I2C1_EN 0
#endif

#ifndef SWD_EN
  #ifndef NDEBUG
    #define SWD_EN 1
  #else
    #define SWD_EN 0
  #endif
#endif

#define GPIO_MODE_EXAMPLE (       \
  + PIN_MODE(0,  PIN_MODE_ANALOG) \
  + PIN_MODE(1,  PIN_MODE_ANALOG) \
  + PIN_MODE(2,  PIN_MODE_ANALOG) \
  + PIN_MODE(3,  PIN_MODE_ANALOG) \
  + PIN_MODE(4,  PIN_MODE_ANALOG) \
  + PIN_MODE(5,  PIN_MODE_ANALOG) \
  + PIN_MODE(6,  PIN_MODE_ANALOG) \
  + PIN_MODE(7,  PIN_MODE_ANALOG) \
  + PIN_MODE(8,  PIN_MODE_ANALOG) \
  + PIN_MODE(9,  PIN_MODE_ANALOG) \
  + PIN_MODE(10, PIN_MODE_ANALOG) \
  + PIN_MODE(11, PIN_MODE_ANALOG) \
  + PIN_MODE(12, PIN_MODE_ANALOG) \
  + PIN_MODE(13, PIN_MODE_ANALOG) \
  + PIN_MODE(14, PIN_MODE_ANALOG) \
  + PIN_MODE(15, PIN_MODE_ANALOG) \
)

#define GPIOA_MODE (                                                    \
  1          * PIN_MODE(0,  PIN_MODE_OUTPUT) /* PA0  -- OUTPUT     */ | \
  1          * PIN_MODE(1,  PIN_MODE_OUTPUT) /* PA1  -- OUTPUT     */ | \
  !USART1_EN * PIN_MODE(2,  PIN_MODE_OUTPUT) /* PA2  -- OUTPUT     */ | \
  !USART1_EN * PIN_MODE(3,  PIN_MODE_OUTPUT) /* PA3  -- OUTPUT     */ | \
  USART1_EN  * PIN_MODE(2,  PIN_MODE_AF)     /* PA2  -- USART1 TX  */ | \
  USART1_EN  * PIN_MODE(3,  PIN_MODE_AF)     /* PA3  -- USART1 RX  */ | \
  !SPI1_EN   * PIN_MODE(4,  PIN_MODE_OUTPUT) /* PA4  -- OUTPUT     */ | \
  SPI1_EN    * PIN_MODE(4,  PIN_MODE_AF)     /* PA4  -- SPI1 CS    */ | \
  SPI1_EN    * PIN_MODE(5,  PIN_MODE_AF)     /* PA5  -- SPI1 SCK   */ | \
  SPI1_EN    * PIN_MODE(6,  PIN_MODE_AF)     /* PA6  -- SPI1 MISO  */ | \
  SPI1_EN    * PIN_MODE(7,  PIN_MODE_AF)     /* PA7  -- SPI1 MOSI  */ | \
  I2C1_EN    * PIN_MODE(9,  PIN_MODE_AF)     /* PA9  -- I2C1 SDA   */ | \
  I2C1_EN    * PIN_MODE(10, PIN_MODE_AF)     /* PA10 -- I2C1 SCL   */ | \
  SWD_EN     * PIN_MODE(13, PIN_MODE_AF)     /* PA13 -- SWDCLK     */ | \
  SWD_EN     * PIN_MODE(14, PIN_MODE_AF)     /* PA14 -- SWDIO      */   \
)

#if 0
#define GPIOA_OTYPE (                         \
  I2C1_EN   * (PIN_TYPE_OD << 9)            | \
  I2C1_EN   * (PIN_TYPE_OD << 10)             \
)
#else
#define GPIOA_OTYPE (                         \
  I2C1_EN   * PIN_OTYPE(9,  PIN_TYPE_OD)    | \
  I2C1_EN   * PIN_OTYPE(10, PIN_TYPE_OD)      \
)
#endif

#define GPIOA_OSPEED (                        \
  SPI1_EN   * PIN_SPEED(4,  PIN_SPEED_HIGH) | \
  SPI1_EN   * PIN_SPEED(5,  PIN_SPEED_HIGH) | \
  SPI1_EN   * PIN_SPEED(6,  PIN_SPEED_HIGH) | \
  SPI1_EN   * PIN_SPEED(7,  PIN_SPEED_HIGH)   \
)

#define GPIOA_AF (                            \
  USART1_EN * PA2_AF1_USART1_TX             | \
  USART1_EN * PA3_AF1_USART1_RX             | \
  SPI1_EN   * PA4_AF0_SPI1_NSS              | \
  SPI1_EN   * PA5_AF0_SPI1_SCK              | \
  SPI1_EN   * PA6_AF0_SPI1_MISO             | \
  SPI1_EN   * PA7_AF0_SPI1_MOSI             | \
  I2C1_EN   * PA9_AF4_I2C1_SCL              | \
  I2C1_EN   * PA10_AF4_I2C1_SDA             | \
  SWD_EN    * PA13_AF0_SWDIO                | \
  SWD_EN    * PA14_AF0_SWCLK                  \
)

#define GPIOB_MODE                     PIN_MODE(1,  PIN_MODE_AF)
#define GPIOB_OSPEEDR                  PIN_SPEED(1, PIN_SPEED_HIGH)

#define GPIOB_AF                       PB1_AF2_TIM1_CH3N

#define GPIOF_MODE (                          \
  PIN_MODE(0,  PIN_MODE_INPUT)              | \
  PIN_MODE(1,  PIN_MODE_INPUT)                \
)

#define GPIOF_PUPDR (                         \
  PIN_PUPD(0,  PIN_PUPD_UP)                 | \
  PIN_PUPD(1,  PIN_PUPD_UP)                   \
)

__STATIC_FORCEINLINE void init_gpio(void) {


  #if defined GPIOA_BRR
    #if GPIOA_BRR != 0
      GPIOA->BRR = GPIOA_BRR; /* 0x48000028: GPIO bit reset register, Address offset: 0x28 */
    #endif
  #else
    #define GPIOA_BRR 0
  #endif

  #if defined GPIOA_AFR_0
    #if GPIOA_AFR_0 != 0
      GPIOA->AFR[0] = GPIOA_AFR_0; /* 0x48000020: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOA_AFR_0 0
  #endif

  #if defined GPIOA_AFR_1
    #if GPIOA_AFR_1 != 0
      GPIOA->AFR[1] = GPIOA_AFR_1; /* 0x48000024: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOA_AFR_1 0
  #endif

  #if defined GPIOA_BSRR
    #if GPIOA_BSRR != 0
      GPIOA->BSRR = GPIOA_BSRR; /* 0x48000018: GPIO port bit set/reset register, Address offset: 0x1A */
    #endif
  #else
    #define GPIOA_BSRR 0
  #endif

  #if defined GPIOA_IDR
    #if GPIOA_IDR != 0
      GPIOA->IDR = GPIOA_IDR; /* 0x48000010: GPIO port input data register, Address offset: 0x10 */
    #endif
  #else
    #define GPIOA_IDR 0
  #endif

  #if defined GPIOA_LCKR
    #if GPIOA_LCKR != 0
      GPIOA->LCKR = GPIOA_LCKR; /* 0x4800001C: GPIO port configuration lock register, Address offset: 0x1C */
    #endif
  #else
    #define GPIOA_LCKR 0
  #endif

  #if defined GPIOA_MODER
    #if GPIOA_MODER != 0
      GPIOA->MODER = GPIOA_MODER; /* 0x48000000: GPIO port mode register, Address offset: 0x00 */
    #endif
  #else
    #define GPIOA_MODER 0
  #endif

  #if defined GPIOA_ODR
    #if GPIOA_ODR != 0
      GPIOA->ODR = GPIOA_ODR; /* 0x48000014: GPIO port output data register, Address offset: 0x14 */
    #endif
  #else
    #define GPIOA_ODR 0
  #endif

  #if defined GPIOA_OSPEEDR
    #if GPIOA_OSPEEDR != 0
      GPIOA->OSPEEDR = GPIOA_OSPEEDR; /* 0x48000008: GPIO port output speed register, Address offset: 0x08 */
    #endif
  #else
    #define GPIOA_OSPEEDR 0
  #endif

  #if defined GPIOA_OTYPER
    #if GPIOA_OTYPER != 0
      GPIOA->OTYPER = GPIOA_OTYPER; /* 0x48000004: GPIO port output type register, Address offset: 0x04 */
    #endif
  #else
    #define GPIOA_OTYPER 0
  #endif

  #if defined GPIOA_PUPDR
    #if GPIOA_PUPDR != 0
      GPIOA->PUPDR = GPIOA_PUPDR; /* 0x4800000C: GPIO port pull-up/pull-down register, Address offset: 0x0C */
    #endif
  #else
    #define GPIOA_PUPDR 0
  #endif

  #if defined GPIOB_BRR
    #if GPIOB_BRR != 0
      GPIOB->BRR = GPIOB_BRR; /* 0x48000428: GPIO bit reset register, Address offset: 0x28 */
    #endif
  #else
    #define GPIOB_BRR 0
  #endif

  #if defined GPIOB_AFR_0
    #if GPIOB_AFR_0 != 0
      GPIOB->AFR[0] = GPIOB_AFR_0; /* 0x48000420: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOB_AFR_0 0
  #endif

  #if defined GPIOB_AFR_1
    #if GPIOB_AFR_1 != 0
      GPIOB->AFR[1] = GPIOB_AFR_1; /* 0x48000424: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOB_AFR_1 0
  #endif

  #if defined GPIOB_BSRR
    #if GPIOB_BSRR != 0
      GPIOB->BSRR = GPIOB_BSRR; /* 0x48000418: GPIO port bit set/reset register, Address offset: 0x1A */
    #endif
  #else
    #define GPIOB_BSRR 0
  #endif

  #if defined GPIOB_IDR
    #if GPIOB_IDR != 0
      GPIOB->IDR = GPIOB_IDR; /* 0x48000410: GPIO port input data register, Address offset: 0x10 */
    #endif
  #else
    #define GPIOB_IDR 0
  #endif

  #if defined GPIOB_LCKR
    #if GPIOB_LCKR != 0
      GPIOB->LCKR = GPIOB_LCKR; /* 0x4800041C: GPIO port configuration lock register, Address offset: 0x1C */
    #endif
  #else
    #define GPIOB_LCKR 0
  #endif

  #if defined GPIOB_MODER
    #if GPIOB_MODER != 0
      GPIOB->MODER = GPIOB_MODER; /* 0x48000400: GPIO port mode register, Address offset: 0x00 */
    #endif
  #else
    #define GPIOB_MODER 0
  #endif

  #if defined GPIOB_ODR
    #if GPIOB_ODR != 0
      GPIOB->ODR = GPIOB_ODR; /* 0x48000414: GPIO port output data register, Address offset: 0x14 */
    #endif
  #else
    #define GPIOB_ODR 0
  #endif

  #if defined GPIOB_OSPEEDR
    #if GPIOB_OSPEEDR != 0
      GPIOB->OSPEEDR = GPIOB_OSPEEDR; /* 0x48000408: GPIO port output speed register, Address offset: 0x08 */
    #endif
  #else
    #define GPIOB_OSPEEDR 0
  #endif

  #if defined GPIOB_OTYPER
    #if GPIOB_OTYPER != 0
      GPIOB->OTYPER = GPIOB_OTYPER; /* 0x48000404: GPIO port output type register, Address offset: 0x04 */
    #endif
  #else
    #define GPIOB_OTYPER 0
  #endif

  #if defined GPIOB_PUPDR
    #if GPIOB_PUPDR != 0
      GPIOB->PUPDR = GPIOB_PUPDR; /* 0x4800040C: GPIO port pull-up/pull-down register, Address offset: 0x0C */
    #endif
  #else
    #define GPIOB_PUPDR 0
  #endif

  #if defined GPIOF_BRR
    #if GPIOF_BRR != 0
      GPIOF->BRR = GPIOF_BRR; /* 0x48001428: GPIO bit reset register, Address offset: 0x28 */
    #endif
  #else
    #define GPIOF_BRR 0
  #endif

  #if defined GPIOF_AFR_0
    #if GPIOF_AFR_0 != 0
      GPIOF->AFR[0] = GPIOF_AFR_0; /* 0x48001420: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOF_AFR_0 0
  #endif

  #if defined GPIOF_AFR_1
    #if GPIOF_AFR_1 != 0
      GPIOF->AFR[1] = GPIOF_AFR_1; /* 0x48001424: GPIO alternate function low register, Address offset: 0x20-0x24 */
    #endif
  #else
    #define GPIOF_AFR_1 0
  #endif

  #if defined GPIOF_BSRR
    #if GPIOF_BSRR != 0
      GPIOF->BSRR = GPIOF_BSRR; /* 0x48001418: GPIO port bit set/reset register, Address offset: 0x1A */
    #endif
  #else
    #define GPIOF_BSRR 0
  #endif

  #if defined GPIOF_IDR
    #if GPIOF_IDR != 0
      GPIOF->IDR = GPIOF_IDR; /* 0x48001410: GPIO port input data register, Address offset: 0x10 */
    #endif
  #else
    #define GPIOF_IDR 0
  #endif

  #if defined GPIOF_LCKR
    #if GPIOF_LCKR != 0
      GPIOF->LCKR = GPIOF_LCKR; /* 0x4800141C: GPIO port configuration lock register, Address offset: 0x1C */
    #endif
  #else
    #define GPIOF_LCKR 0
  #endif

  #if defined GPIOF_MODER
    #if GPIOF_MODER != 0
      GPIOF->MODER = GPIOF_MODER; /* 0x48001400: GPIO port mode register, Address offset: 0x00 */
    #endif
  #else
    #define GPIOF_MODER 0
  #endif

  #if defined GPIOF_ODR
    #if GPIOF_ODR != 0
      GPIOF->ODR = GPIOF_ODR; /* 0x48001414: GPIO port output data register, Address offset: 0x14 */
    #endif
  #else
    #define GPIOF_ODR 0
  #endif

  #if defined GPIOF_OSPEEDR
    #if GPIOF_OSPEEDR != 0
      GPIOF->OSPEEDR = GPIOF_OSPEEDR; /* 0x48001408: GPIO port output speed register, Address offset: 0x08 */
    #endif
  #else
    #define GPIOF_OSPEEDR 0
  #endif

  #if defined GPIOF_OTYPER
    #if GPIOF_OTYPER != 0
      GPIOF->OTYPER = GPIOF_OTYPER; /* 0x48001404: GPIO port output type register, Address offset: 0x04 */
    #endif
  #else
    #define GPIOF_OTYPER 0
  #endif

  #if defined GPIOF_PUPDR
    #if GPIOF_PUPDR != 0
      GPIOF->PUPDR = GPIOF_PUPDR; /* 0x4800140C: GPIO port pull-up/pull-down register, Address offset: 0x0C */
    #endif
  #else
    #define GPIOF_PUPDR 0
  #endif  
} /* init_gpio() */

#if (GPIOA_AFR_0 != 0) || (GPIOA_AFR_1 != 0) || (GPIOA_BRR != 0) || (GPIOA_BSRR != 0) || (GPIOA_IDR != 0) || \
    (GPIOA_LCKR != 0) || (GPIOA_MODER != 0) || (GPIOA_ODR != 0) || (GPIOA_OSPEEDR != 0) || (GPIOA_OTYPER != 0) || \
    (GPIOA_PUPDR != 0)

  #define GPIOA_EN (!0)
#else
  #define GPIOA_EN 0
#endif

#if (GPIOB_AFR_0 != 0) || (GPIOB_AFR_1 != 0) || (GPIOB_BRR != 0) || (GPIOB_BSRR != 0) || (GPIOB_IDR != 0) || \
    (GPIOB_LCKR != 0) || (GPIOB_MODER != 0) || (GPIOB_ODR != 0) || (GPIOB_OSPEEDR != 0) || (GPIOB_OTYPER != 0) || \
    (GPIOB_PUPDR != 0)

  #define GPIOB_EN (!0)
#else
  #define GPIOB_EN 0
#endif

#if (GPIOF_AFR_0 != 0) || (GPIOF_AFR_1 != 0) || (GPIOF_BRR != 0) || (GPIOF_BSRR != 0) || (GPIOF_IDR != 0) || \
    (GPIOF_LCKR != 0) || (GPIOF_MODER != 0) || (GPIOF_ODR != 0) || (GPIOF_OSPEEDR != 0) || (GPIOF_OTYPER != 0) || \
    (GPIOF_PUPDR != 0)

  #define GPIOF_EN (!0)
#else
  #define GPIOF_EN 0
#endif

#if 0
  #if (GPIOA_EN != 0) || (GPIOB_EN != 0) || (GPIOF_EN != 0)
    init_gpio();
  #endif
#endif


////////////////////////////////////////////////////////////////////////////////////////
//  This code was generated for the stm32f030x6 microcontroller by "stm32cgen" tool.
//                          https://github.com/a5021/stm32codegen                          
//  Arguments used:
//    -l 030f4 -p GPIOA GPIOB GPIOF -m gpio -f init_gpio -D
//    USE_ANALOG_MODE_FOR_ALL_PINS_BY_DEFALUT 1 "" GPIO_MODE
//    "(USE_ANALOG_MODE_FOR_ALL_PINS_BY_DEFALUT * UINT32_MAX)" PIN_XOR "(GPIO_MODE &
//    3UL)" "" PIN_MODE_INPUT "(0x00UL ^ PIN_XOR)" PIN_MODE_OUTPUT "(0x01UL ^
//    PIN_XOR)" PIN_MODE_AF "(0x02UL ^ PIN_XOR)" PIN_MODE_ANALOG "(0x03UL ^ PIN_XOR)"
//    "" "PIN_CFG(PIN, MODE)" "((MODE)   << ((PIN) * 2))" "PIN_MODE(PIN, MODE)"
//    "(((MODE)  << GPIO_MODER_MODER ## PIN ## _Pos) & GPIO_MODER_MODER ## PIN ##
//    _Msk)" "PIN_SPEED(PIN, SPEED)" "(((SPEED) << GPIO_OSPEEDR_OSPEEDR ## PIN ##
//    _Pos) & GPIO_OSPEEDR_OSPEEDR ## PIN ## _Msk)" "PIN_OTYPE(PIN, OTYPE)" "((OTYPE)
//    ? GPIO_OTYPER_OT_ ## PIN : 0)" "PIN_PUPD(PIN, PUPD)" "(((PUPD)  <<
//    GPIO_PUPDR_PUPDR ## PIN ## _Pos) & GPIO_PUPDR_PUPDR ## PIN ## _Msk)"
//    "PIN_AF(PIN, AF)" "(AF << (PIN * 4))" "" PA0_AF1_USART1_CTS "PIN_AF(0, 1ULL)"
//    PA1_AF0_EVENTOUT "PIN_AF(1, 0ULL)" PA1_AF1_USART1_RTS "PIN_AF(1, 1ULL)"
//    PA2_AF1_USART1_TX "PIN_AF(2, 1ULL)" PA3_AF1_USART1_RX "PIN_AF(3, 1ULL)"
//    PA4_AF0_SPI1_NSS "PIN_AF(4, 0ULL)" PA4_AF1_USART1_CK "PIN_AF(4, 1ULL)"
//    PA4_AF4_TIM14_CH1 "PIN_AF(4, 4ULL)" PA5_AF0_SPI1_SCK "PIN_AF(5, 0ULL)"
//    PA6_AF0_SPI1_MISO "PIN_AF(6, 0ULL)" PA6_AF1_TIM3_CH1 "PIN_AF(6, 1ULL)"
//    PA6_AF2_TIM1_BKIN "PIN_AF(6, 2ULL)" PA6_AF5_TIM16_CH1 "PIN_AF(6, 5ULL)"
//    PA6_AF6_EVENTOUT "PIN_AF(6, 6ULL)" PA7_AF0_SPI1_MOSI "PIN_AF(7, 0ULL)"
//    PA7_AF1_TIM3_CH2 "PIN_AF(7, 1ULL)" PA7_AF2_TIM1_CH1N "PIN_AF(7, 2ULL)"
//    PA7_AF4_TIM14_CH1 "PIN_AF(7, 4ULL)" PA7_AF5_TIM17_CH1 "PIN_AF(7, 5ULL)"
//    PA7_AF6_EVENTOUT "PIN_AF(7, 6ULL)" PA9_AF1_USART1_TX "PIN_AF(9, 1ULL)"
//    PA9_AF2_TIM1_CH2 "PIN_AF(9, 2ULL)" PA9_AF4_I2C1_SCL "PIN_AF(9, 4ULL)"
//    PA10_AF0_TIM17_BKIN "PIN_AF(10, 0ULL)" PA10_AF1_USART1_RX "PIN_AF(10, 1ULL)"
//    PA10_AF2_TIM1_CH3 "PIN_AF(10, 2ULL)" PA10_AF4_I2C1_SDA "PIN_AF(10, 4ULL)"
//    PA13_AF0_SWDIO "PIN_AF(13, 0ULL)" PA13_AF1_IR_OUT "PIN_AF(13, 1ULL)"
//    PA14_AF0_SWCLK "PIN_AF(14, 0ULL)" PA14_AF1_USART1_TX "PIN_AF(14, 1ULL)" ""
//    PB1_AF0_TIM14_CH1 "PIN_AF(1, 0ULL)" PB1_AF1_TIM3_CH4 "PIN_AF(1, 1ULL)"
//    PB1_AF2_TIM1_CH3N "PIN_AF(1, 2ULL)" "" PIN_TYPE_PP 0x00UL PIN_TYPE_OD 0x01UL ""
//    PIN_SPEED_LOW 0x00UL PIN_SPEED_MED 0x01UL PIN_SPEED_HIGH 0x03UL "" PIN_PUPD_NONE
//    0x00UL PIN_PUPD_UP 0x01UL PIN_PUPD_DOWN 0x02UL "" _BR(PIN) "GPIO_BSRR_BR_ ##
//    PIN" BR(PIN) _BR(PIN) _BS(PIN) "GPIO_BSRR_BS_ ## PIN" BS(PIN) _BS(PIN) _ODR(PIN)
//    "GPIO_ODR_ ## PIN" ODR(PIN) _ODR(PIN) "" GPIOA_MODER "(GPIO_MODE ^
//    (GPIOA_MODE))" GPIOB_MODER "(GPIO_MODE ^ (GPIOB_MODE))" GPIOF_MODER "(GPIO_MODE
//    ^ (GPIOF_MODE))" "" GPIOA_AFR_0 "(GPIOA_AF & UINT32_MAX)" GPIOA_AFR_1
//    "((GPIOA_AF >> 32) & UINT32_MAX)" "" GPIOB_AFR_0 "(GPIOB_AF & UINT32_MAX)"
//    GPIOB_AFR_1 "((GPIOB_AF >> 32) & UINT32_MAX)" -H "" -H "#define
//    CONFIGURE_PIN(GPIOx, PIN, MODE, OTYPE, SPEED, PUPD) do {
//    \" -H "  if (MODE)   MODIFY_REG((GPIOx)->MODER,   (0x03UL << ((PIN) * 2)),
//    ((MODE)  << ((PIN) * 2))); \" -H "  if (SPEED)  MODIFY_REG((GPIOx)->OSPEEDR,
//    (0x03UL << ((PIN) * 2)), ((SPEED) << ((PIN) * 2))); \" -H "  if (PUPD)
//    MODIFY_REG((GPIOx)->PUPDR,   (0x03UL << ((PIN) * 2)), ((PUPD)  << ((PIN) * 2)));
//    \" -H "  if (OTYPE)  MODIFY_REG((GPIOx)->OTYPER,  (0x01UL << (PIN)),
//    ((OTYPE) << (PIN)));       \" -H }while(0) -H "" -H "#ifndef USART1_EN" -H "
//    #define USART1_EN 0" -H #endif -H "" -H "#ifndef SPI1_EN" -H "  #define SPI1_EN
//    0" -H #endif -H "" -H "#ifndef I2C1_EN" -H "  #define I2C1_EN 0" -H #endif -H ""
//    -H "#ifndef SWD_EN" -H "  #ifndef NDEBUG" -H "    #define SWD_EN 1" -H "  #else"
//    -H "    #define SWD_EN 0" -H "  #endif" -H #endif -H "" -H "#define
//    GPIO_MODE_EXAMPLE (       \" -H "  + PIN_MODE(0,  PIN_MODE_ANALOG) \" -H "  +
//    PIN_MODE(1,  PIN_MODE_ANALOG) \" -H "  + PIN_MODE(2,  PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(3,  PIN_MODE_ANALOG) \" -H "  + PIN_MODE(4,  PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(5,  PIN_MODE_ANALOG) \" -H "  + PIN_MODE(6,  PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(7,  PIN_MODE_ANALOG) \" -H "  + PIN_MODE(8,  PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(9,  PIN_MODE_ANALOG) \" -H "  + PIN_MODE(10, PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(11, PIN_MODE_ANALOG) \" -H "  + PIN_MODE(12, PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(13, PIN_MODE_ANALOG) \" -H "  + PIN_MODE(14, PIN_MODE_ANALOG) \" -H "
//    + PIN_MODE(15, PIN_MODE_ANALOG) \" -H ) -H "" -H "#define GPIOA_MODE (
//    \" -H "  1          * PIN_MODE(0,  PIN_MODE_OUTPUT) /* PA0  -- OUTPUT     */ |
//    \" -H "  1          * PIN_MODE(1,  PIN_MODE_OUTPUT) /* PA1  -- OUTPUT     */ |
//    \" -H "  !USART1_EN * PIN_MODE(2,  PIN_MODE_OUTPUT) /* PA2  -- OUTPUT     */ |
//    \" -H "  !USART1_EN * PIN_MODE(3,  PIN_MODE_OUTPUT) /* PA3  -- OUTPUT     */ |
//    \" -H "  USART1_EN  * PIN_MODE(2,  PIN_MODE_AF)     /* PA2  -- USART1 TX  */ |
//    \" -H "  USART1_EN  * PIN_MODE(3,  PIN_MODE_AF)     /* PA3  -- USART1 RX  */ |
//    \" -H "  !SPI1_EN   * PIN_MODE(4,  PIN_MODE_OUTPUT) /* PA4  -- OUTPUT     */ |
//    \" -H "  SPI1_EN    * PIN_MODE(4,  PIN_MODE_AF)     /* PA4  -- SPI1 CS    */ |
//    \" -H "  SPI1_EN    * PIN_MODE(5,  PIN_MODE_AF)     /* PA5  -- SPI1 SCK   */ |
//    \" -H "  SPI1_EN    * PIN_MODE(6,  PIN_MODE_AF)     /* PA6  -- SPI1 MISO  */ |
//    \" -H "  SPI1_EN    * PIN_MODE(7,  PIN_MODE_AF)     /* PA7  -- SPI1 MOSI  */ |
//    \" -H "  I2C1_EN    * PIN_MODE(9,  PIN_MODE_AF)     /* PA9  -- I2C1 SDA   */ |
//    \" -H "  I2C1_EN    * PIN_MODE(10, PIN_MODE_AF)     /* PA10 -- I2C1 SCL   */ |
//    \" -H "  SWD_EN     * PIN_MODE(13, PIN_MODE_AF)     /* PA13 -- SWDCLK     */ |
//    \" -H "  SWD_EN     * PIN_MODE(14, PIN_MODE_AF)     /* PA14 -- SWDIO      */
//    \" -H ) -H "" -H "#if 0" -H "#define GPIOA_OTYPE (                         \" -H
//    "  I2C1_EN   * (PIN_TYPE_OD << 9)            | \" -H "  I2C1_EN   * (PIN_TYPE_OD
//    << 10)             \" -H ) -H #else -H "#define GPIOA_OTYPE (
//    \" -H "  I2C1_EN   * PIN_OTYPE(9,  PIN_TYPE_OD)    | \" -H "  I2C1_EN   *
//    PIN_OTYPE(10, PIN_TYPE_OD)      \" -H ) -H #endif -H "" -H "#define GPIOA_OSPEED
//    (                        \" -H "  SPI1_EN   * PIN_SPEED(4,  PIN_SPEED_HIGH) | \"
//    -H "  SPI1_EN   * PIN_SPEED(5,  PIN_SPEED_HIGH) | \" -H "  SPI1_EN   *
//    PIN_SPEED(6,  PIN_SPEED_HIGH) | \" -H "  SPI1_EN   * PIN_SPEED(7,
//    PIN_SPEED_HIGH)   \" -H ) -H "" -H "#define GPIOA_AF (
//    \" -H "  USART1_EN * PA2_AF1_USART1_TX             | \" -H "  USART1_EN *
//    PA3_AF1_USART1_RX             | \" -H "  SPI1_EN   * PA4_AF0_SPI1_NSS
//    | \" -H "  SPI1_EN   * PA5_AF0_SPI1_SCK              | \" -H "  SPI1_EN   *
//    PA6_AF0_SPI1_MISO             | \" -H "  SPI1_EN   * PA7_AF0_SPI1_MOSI
//    | \" -H "  I2C1_EN   * PA9_AF4_I2C1_SCL              | \" -H "  I2C1_EN   *
//    PA10_AF4_I2C1_SDA             | \" -H "  SWD_EN    * PA13_AF0_SWDIO
//    | \" -H "  SWD_EN    * PA14_AF0_SWCLK                  \" -H ) -H "" -H "#define
//    GPIOB_MODE                     PIN_MODE(1,  PIN_MODE_AF)" -H "#define
//    GPIOB_OSPEEDR                  PIN_SPEED(1, PIN_SPEED_HIGH)" -H "" -H "#define
//    GPIOB_AF                       PB1_AF2_TIM1_CH3N" -H "" -H "#define GPIOF_MODE (
//    \" -H "  PIN_MODE(0,  PIN_MODE_INPUT)              | \" -H "  PIN_MODE(1,
//    PIN_MODE_INPUT)                \" -H ) -H "" -H "#define GPIOF_PUPDR (
//    \" -H "  PIN_PUPD(0,  PIN_PUPD_UP)                 | \" -H "  PIN_PUPD(1,
//    PIN_PUPD_UP)                   \" -H ) --force-inline --no-def
////////////////////////////////////////////////////////////////////////////////////////


#ifdef __cplusplus
  }
#endif /* __cplusplus */
#endif /* __GPIO_H__ */

CREATE_EOF

create_file "inc/rcc.h" <<'CREATE_EOF'
#ifndef __RCC_H__
#define __RCC_H__

#ifdef __cplusplus
  extern "C" {
#endif


#define R                              (HCLK >= 12)
#define XMUL                           (HCLK / 4 - 2)     /* Calculate PLL multiplication factor      */
#define A                              ((XMUL >> 0) & 1)  /* LSB or BIT0 of PLL multiplication factor */
#define B                              ((XMUL >> 1) & 1)  /*        BIT1 of PLL multiplication factor */
#define C                              ((XMUL >> 2) & 1)  /*        BIT2 of PLL multiplication factor */
#define D                              ((XMUL >> 3) & 1)  /* MSB or BIT3 of PLL multiplication factor */


__STATIC_FORCEINLINE void configure_flash(void);
__STATIC_FORCEINLINE void wait_for_clock_settles(void);


#define RCC_CFGR (                      \
  0 * RCC_CFGR_SW                       |  /* (3 << 0)     SW[1:0] bits (System clock Switch)                        0x00000003  */\
  0 * RCC_CFGR_SW_0                     |  /* (1 << 0)       0x00000001                                                          */\
  0 * RCC_CFGR_SW_1                     |  /* (2 << 0)       0x00000002                                                          */\
  0 * RCC_CFGR_SW_HSI                   |  /* 0x00000000   HSI selected as system clock                                          */\
  0 * RCC_CFGR_SW_HSE                   |  /* 0x00000001   HSE selected as system clock                                          */\
  R * RCC_CFGR_SW_PLL                   |  /* 0x00000002   PLL selected as system clock                                          */\
  0 * RCC_CFGR_SWS                      |  /* (3 << 2)     SWS[1:0] bits (System Clock Switch Status)                0x0000000C  */\
  0 * RCC_CFGR_SWS_0                    |  /* (1 << 2)       0x00000004                                                          */\
  0 * RCC_CFGR_SWS_1                    |  /* (2 << 2)       0x00000008                                                          */\
  0 * RCC_CFGR_SWS_HSI                  |  /* 0x00000000   HSI oscillator used as system clock                                   */\
  0 * RCC_CFGR_SWS_HSE                  |  /* 0x00000004   HSE oscillator used as system clock                                   */\
  0 * RCC_CFGR_SWS_PLL                  |  /* 0x00000008   PLL used as system clock                                              */\
  0 * RCC_CFGR_HPRE                     |  /* (0xF << 4)   HPRE[3:0] bits (AHB prescaler)                            0x000000F0  */\
  0 * RCC_CFGR_HPRE_0                   |  /* (1 << 4)       0x00000010                                                          */\
  0 * RCC_CFGR_HPRE_1                   |  /* (2 << 4)       0x00000020                                                          */\
  0 * RCC_CFGR_HPRE_2                   |  /* (4 << 4)       0x00000040                                                          */\
  0 * RCC_CFGR_HPRE_3                   |  /* (8 << 4)       0x00000080                                                          */\
  0 * RCC_CFGR_HPRE_DIV1                |  /* 0x00000000   SYSCLK not divided                                                    */\
  0 * RCC_CFGR_HPRE_DIV2                |  /* 0x00000080   SYSCLK divided by 2                                                   */\
  0 * RCC_CFGR_HPRE_DIV4                |  /* 0x00000090   SYSCLK divided by 4                                                   */\
  0 * RCC_CFGR_HPRE_DIV8                |  /* 0x000000A0   SYSCLK divided by 8                                                   */\
  0 * RCC_CFGR_HPRE_DIV16               |  /* 0x000000B0   SYSCLK divided by 16                                                  */\
  0 * RCC_CFGR_HPRE_DIV64               |  /* 0x000000C0   SYSCLK divided by 64                                                  */\
  0 * RCC_CFGR_HPRE_DIV128              |  /* 0x000000D0   SYSCLK divided by 128                                                 */\
  0 * RCC_CFGR_HPRE_DIV256              |  /* 0x000000E0   SYSCLK divided by 256                                                 */\
  0 * RCC_CFGR_HPRE_DIV512              |  /* 0x000000F0   SYSCLK divided by 512                                                 */\
  0 * RCC_CFGR_PPRE                     |  /* (7 << 8)     PRE[2:0] bits (APB prescaler)                             0x00000700  */\
  0 * RCC_CFGR_PPRE_0                   |  /* (1 << 8)       0x00000100                                                          */\
  0 * RCC_CFGR_PPRE_1                   |  /* (2 << 8)       0x00000200                                                          */\
  0 * RCC_CFGR_PPRE_2                   |  /* (4 << 8)       0x00000400                                                          */\
  0 * RCC_CFGR_PPRE_DIV1                |  /* 0x00000000   HCLK not divided                                                      */\
  0 * RCC_CFGR_PPRE_DIV2                |  /* (1 << 10)    HCLK divided by 2                                         0x00000400  */\
  0 * RCC_CFGR_PPRE_DIV4                |  /* (5 << 8)     HCLK divided by 4                                         0x00000500  */\
  0 * RCC_CFGR_PPRE_DIV8                |  /* (3 << 9)     HCLK divided by 8                                         0x00000600  */\
  0 * RCC_CFGR_PPRE_DIV16               |  /* (7 << 8)     HCLK divided by 16                                        0x00000700  */\
  0 * RCC_CFGR_ADCPRE                   |  /* (1 << 14)    ADCPRE bit (ADC prescaler)                                0x00004000  */\
  0 * RCC_CFGR_ADCPRE_DIV2              |  /* 0x00000000   PCLK divided by 2                                                     */\
  0 * RCC_CFGR_ADCPRE_DIV4              |  /* 0x00004000   PCLK divided by 4                                                     */\
  0 * RCC_CFGR_PLLSRC                   |  /* (1 << 16)    PLL entry clock source                                    0x00010000  */\
  0 * RCC_CFGR_PLLSRC_HSI_DIV2          |  /* 0x00000000   HSI clock divided by 2 selected as PLL entry clock source             */\
  0 * RCC_CFGR_PLLSRC_HSE_PREDIV        |  /* 0x00010000   HSE/PREDIV clock selected as PLL entry clock source                   */\
  0 * RCC_CFGR_PLLXTPRE                 |  /* (1 << 17)    HSE divider for PLL entry                                 0x00020000  */\
  0 * RCC_CFGR_PLLXTPRE_HSE_PREDIV_DIV1 |  /* 0x00000000   HSE/PREDIV clock not divided for PLL entry                            */\
  0 * RCC_CFGR_PLLXTPRE_HSE_PREDIV_DIV2 |  /* 0x00020000   HSE/PREDIV clock divided by 2 for PLL entry                           */\
  0 * RCC_CFGR_PLLMUL                   |  /* (0xF << 18)  PLLMUL[3:0] bits (PLL multiplication factor)              0x003C0000  */\
  A * RCC_CFGR_PLLMUL_0                 |  /* (1 << 18)      0x00040000                                                          */\
  B * RCC_CFGR_PLLMUL_1                 |  /* (2 << 18)      0x00080000                                                          */\
  C * RCC_CFGR_PLLMUL_2                 |  /* (4 << 18)      0x00100000                                                          */\
  D * RCC_CFGR_PLLMUL_3                 |  /* (8 << 18)      0x00200000                                                          */\
  0 * RCC_CFGR_PLLMUL2                  |  /* 0x00000000   PLL input clock*2                                                     */\
  0 * RCC_CFGR_PLLMUL3                  |  /* 0x00040000   PLL input clock*3                                                     */\
  0 * RCC_CFGR_PLLMUL4                  |  /* 0x00080000   PLL input clock*4                                                     */\
  0 * RCC_CFGR_PLLMUL5                  |  /* 0x000C0000   PLL input clock*5                                                     */\
  0 * RCC_CFGR_PLLMUL6                  |  /* 0x00100000   PLL input clock*6                                                     */\
  0 * RCC_CFGR_PLLMUL7                  |  /* 0x00140000   PLL input clock*7                                                     */\
  0 * RCC_CFGR_PLLMUL8                  |  /* 0x00180000   PLL input clock*8                                                     */\
  0 * RCC_CFGR_PLLMUL9                  |  /* 0x001C0000   PLL input clock*9                                                     */\
  0 * RCC_CFGR_PLLMUL10                 |  /* 0x00200000   PLL input clock10                                                     */\
  0 * RCC_CFGR_PLLMUL11                 |  /* 0x00240000   PLL input clock*11                                                    */\
  0 * RCC_CFGR_PLLMUL12                 |  /* 0x00280000   PLL input clock*12                                                    */\
  0 * RCC_CFGR_PLLMUL13                 |  /* 0x002C0000   PLL input clock*13                                                    */\
  0 * RCC_CFGR_PLLMUL14                 |  /* 0x00300000   PLL input clock*14                                                    */\
  0 * RCC_CFGR_PLLMUL15                 |  /* 0x00340000   PLL input clock*15                                                    */\
  0 * RCC_CFGR_PLLMUL16                 |  /* 0x00380000   PLL input clock*16                                                    */\
  0 * RCC_CFGR_MCO                      |  /* (0xF << 24)  MCO[3:0] bits (Microcontroller Clock Output)              0x0F000000  */\
  0 * RCC_CFGR_MCO_0                    |  /* (1 << 24)      0x01000000                                                          */\
  0 * RCC_CFGR_MCO_1                    |  /* (2 << 24)      0x02000000                                                          */\
  0 * RCC_CFGR_MCO_2                    |  /* (4 << 24)      0x04000000                                                          */\
  0 * RCC_CFGR_MCO_NOCLOCK              |  /* 0x00000000   No clock                                                              */\
  0 * RCC_CFGR_MCO_HSI14                |  /* 0x01000000   HSI14 clock selected as MCO source                                    */\
  0 * RCC_CFGR_MCO_LSI                  |  /* 0x02000000   LSI clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCO_LSE                  |  /* 0x03000000   LSE clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCO_SYSCLK               |  /* 0x04000000   System clock selected as MCO source                                   */\
  0 * RCC_CFGR_MCO_HSI                  |  /* 0x05000000   HSI clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCO_HSE                  |  /* 0x06000000   HSE clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCO_PLL                  |  /* 0x07000000   PLL clock divided by 2 selected as MCO source                         */\
  0 * RCC_CFGR_MCOPRE                   |  /* (7 << 28)    MCO prescaler                                             0x70000000  */\
  0 * RCC_CFGR_MCOPRE_DIV1              |  /* 0x00000000   MCO is divided by 1                                                   */\
  0 * RCC_CFGR_MCOPRE_DIV2              |  /* 0x10000000   MCO is divided by 2                                                   */\
  0 * RCC_CFGR_MCOPRE_DIV4              |  /* 0x20000000   MCO is divided by 4                                                   */\
  0 * RCC_CFGR_MCOPRE_DIV8              |  /* 0x30000000   MCO is divided by 8                                                   */\
  0 * RCC_CFGR_MCOPRE_DIV16             |  /* 0x40000000   MCO is divided by 16                                                  */\
  0 * RCC_CFGR_MCOPRE_DIV32             |  /* 0x50000000   MCO is divided by 32                                                  */\
  0 * RCC_CFGR_MCOPRE_DIV64             |  /* 0x60000000   MCO is divided by 64                                                  */\
  0 * RCC_CFGR_MCOPRE_DIV128            |  /* 0x70000000   MCO is divided by 128                                                 */\
  0 * RCC_CFGR_PLLNODIV                 |  /* (1 << 31)    PLL is not divided to MCO                                 0x80000000  */\
  0 * RCC_CFGR_MCOSEL                   |  /* (0xF << 24)  0x0F000000                                                            */\
  0 * RCC_CFGR_MCOSEL_0                 |  /* (1 << 24)    0x01000000                                                            */\
  0 * RCC_CFGR_MCOSEL_1                 |  /* (2 << 24)    0x02000000                                                            */\
  0 * RCC_CFGR_MCOSEL_2                 |  /* (4 << 24)    0x04000000                                                            */\
  0 * RCC_CFGR_MCOSEL_NOCLOCK           |  /* 0x00000000   No clock                                                              */\
  0 * RCC_CFGR_MCOSEL_HSI14             |  /* 0x01000000   HSI14 clock selected as MCO source                                    */\
  0 * RCC_CFGR_MCOSEL_LSI               |  /* 0x02000000   LSI clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCOSEL_LSE               |  /* 0x03000000   LSE clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCOSEL_SYSCLK            |  /* 0x04000000   System clock selected as MCO source                                   */\
  0 * RCC_CFGR_MCOSEL_HSI               |  /* 0x05000000   HSI clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCOSEL_HSE               |  /* 0x06000000   HSE clock selected as MCO source                                      */\
  0 * RCC_CFGR_MCOSEL_PLL_DIV2             /* 0x07000000   PLL clock divided by 2 selected as MCO source                         */\
)


#define RCC_CFGR2 (                     \
  0 * RCC_CFGR2_PREDIV                  |  /* (0xF << 0)   PREDIV[3:0] bits                                          0x0000000F  */\
  0 * RCC_CFGR2_PREDIV_0                |  /* (1 << 0)       0x00000001                                                          */\
  0 * RCC_CFGR2_PREDIV_1                |  /* (2 << 0)       0x00000002                                                          */\
  0 * RCC_CFGR2_PREDIV_2                |  /* (4 << 0)       0x00000004                                                          */\
  0 * RCC_CFGR2_PREDIV_3                |  /* (8 << 0)       0x00000008                                                          */\
  0 * RCC_CFGR2_PREDIV_DIV1             |  /* 0x00000000   PREDIV input clock not divided                                        */\
  0 * RCC_CFGR2_PREDIV_DIV2             |  /* 0x00000001   PREDIV input clock divided by 2                                       */\
  0 * RCC_CFGR2_PREDIV_DIV3             |  /* 0x00000002   PREDIV input clock divided by 3                                       */\
  0 * RCC_CFGR2_PREDIV_DIV4             |  /* 0x00000003   PREDIV input clock divided by 4                                       */\
  0 * RCC_CFGR2_PREDIV_DIV5             |  /* 0x00000004   PREDIV input clock divided by 5                                       */\
  0 * RCC_CFGR2_PREDIV_DIV6             |  /* 0x00000005   PREDIV input clock divided by 6                                       */\
  0 * RCC_CFGR2_PREDIV_DIV7             |  /* 0x00000006   PREDIV input clock divided by 7                                       */\
  0 * RCC_CFGR2_PREDIV_DIV8             |  /* 0x00000007   PREDIV input clock divided by 8                                       */\
  0 * RCC_CFGR2_PREDIV_DIV9             |  /* 0x00000008   PREDIV input clock divided by 9                                       */\
  0 * RCC_CFGR2_PREDIV_DIV10            |  /* 0x00000009   PREDIV input clock divided by 10                                      */\
  0 * RCC_CFGR2_PREDIV_DIV11            |  /* 0x0000000A   PREDIV input clock divided by 11                                      */\
  0 * RCC_CFGR2_PREDIV_DIV12            |  /* 0x0000000B   PREDIV input clock divided by 12                                      */\
  0 * RCC_CFGR2_PREDIV_DIV13            |  /* 0x0000000C   PREDIV input clock divided by 13                                      */\
  0 * RCC_CFGR2_PREDIV_DIV14            |  /* 0x0000000D   PREDIV input clock divided by 14                                      */\
  0 * RCC_CFGR2_PREDIV_DIV15            |  /* 0x0000000E   PREDIV input clock divided by 15                                      */\
  0 * RCC_CFGR2_PREDIV_DIV16               /* 0x0000000F   PREDIV input clock divided by 16                                      */\
)


#define RCC_CFGR3 (                     \
  0 * RCC_CFGR3_USART1SW                |  /* (3 << 0)     USART1SW[1:0] bits                                        0x00000003  */\
  0 * RCC_CFGR3_USART1SW_0              |  /* (1 << 0)       0x00000001                                                          */\
  0 * RCC_CFGR3_USART1SW_1              |  /* (2 << 0)       0x00000002                                                          */\
  0 * RCC_CFGR3_USART1SW_PCLK           |  /* 0x00000000   PCLK clock used as USART1 clock source                                */\
  0 * RCC_CFGR3_USART1SW_SYSCLK         |  /* 0x00000001   System clock selected as USART1 clock source                          */\
  0 * RCC_CFGR3_USART1SW_LSE            |  /* 0x00000002   LSE oscillator clock used as USART1 clock source                      */\
  0 * RCC_CFGR3_USART1SW_HSI            |  /* 0x00000003   HSI oscillator clock used as USART1 clock source                      */\
  0 * RCC_CFGR3_I2C1SW                  |  /* (1 << 4)     I2C1SW bits                                               0x00000010  */\
  0 * RCC_CFGR3_I2C1SW_HSI              |  /* 0x00000000   HSI oscillator clock used as I2C1 clock source                        */\
  0 * RCC_CFGR3_I2C1SW_SYSCLK              /* (1 << 4)     System clock selected as I2C1 clock source                0x00000010  */\
)


#define RCC_CSR (                       \
  0 * RCC_CSR_LSION                     |  /* (1 << 0)     Internal Low Speed oscillator enable                      0x00000001  */\
  0 * RCC_CSR_LSIRDY                    |  /* (1 << 1)     Internal Low Speed oscillator Ready                       0x00000002  */\
  0 * RCC_CSR_V18PWRRSTF                |  /* (1 << 23)    V1.8 power domain reset flag                              0x00800000  */\
  0 * RCC_CSR_RMVF                      |  /* (1 << 24)    Remove reset flag                                         0x01000000  */\
  0 * RCC_CSR_OBLRSTF                   |  /* (1 << 25)    OBL reset flag                                            0x02000000  */\
  0 * RCC_CSR_PINRSTF                   |  /* (1 << 26)    PIN reset flag                                            0x04000000  */\
  0 * RCC_CSR_PORRSTF                   |  /* (1 << 27)    POR/PDR reset flag                                        0x08000000  */\
  0 * RCC_CSR_SFTRSTF                   |  /* (1 << 28)    Software Reset flag                                       0x10000000  */\
  0 * RCC_CSR_IWDGRSTF                  |  /* (1 << 29)    Independent Watchdog reset flag                           0x20000000  */\
  0 * RCC_CSR_WWDGRSTF                  |  /* (1 << 30)    Window watchdog reset flag                                0x40000000  */\
  0 * RCC_CSR_LPWRRSTF                  |  /* (1 << 31)    Low-Power reset flag                                      0x80000000  */\
  0 * RCC_CSR_OBL                          /* (1 << 25)    OBL reset flag                                            0x02000000  */\
)


#define RCC_AHBRSTR (                   \
  0 * RCC_AHBRSTR_GPIOARST              |  /* (1 << 17)    GPIOA reset                                               0x00020000  */\
  0 * RCC_AHBRSTR_GPIOBRST              |  /* (1 << 18)    GPIOB reset                                               0x00040000  */\
  0 * RCC_AHBRSTR_GPIOCRST              |  /* (1 << 19)    GPIOC reset                                               0x00080000  */\
  0 * RCC_AHBRSTR_GPIODRST              |  /* (1 << 20)    GPIOD reset                                               0x00100000  */\
  0 * RCC_AHBRSTR_GPIOFRST                 /* (1 << 22)    GPIOF reset                                               0x00400000  */\
)


#define RCC_APB1RSTR (                  \
  0 * RCC_APB1RSTR_TIM3RST              |  /* (1 << 1)     Timer 3 reset                                             0x00000002  */\
  0 * RCC_APB1RSTR_TIM14RST             |  /* (1 << 8)     Timer 14 reset                                            0x00000100  */\
  0 * RCC_APB1RSTR_WWDGRST              |  /* (1 << 11)    Window Watchdog reset                                     0x00000800  */\
  0 * RCC_APB1RSTR_I2C1RST              |  /* (1 << 21)    I2C 1 reset                                               0x00200000  */\
  0 * RCC_APB1RSTR_PWRRST                  /* (1 << 28)    PWR reset                                                 0x10000000  */\
)


#define RCC_APB2RSTR (                  \
  0 * RCC_APB2RSTR_SYSCFGRST            |  /* (1 << 0)     SYSCFG reset                                              0x00000001  */\
  0 * RCC_APB2RSTR_ADCRST               |  /* (1 << 9)     ADC reset                                                 0x00000200  */\
  0 * RCC_APB2RSTR_TIM1RST              |  /* (1 << 11)    TIM1 reset                                                0x00000800  */\
  0 * RCC_APB2RSTR_SPI1RST              |  /* (1 << 12)    SPI1 reset                                                0x00001000  */\
  0 * RCC_APB2RSTR_USART1RST            |  /* (1 << 14)    USART1 reset                                              0x00004000  */\
  0 * RCC_APB2RSTR_TIM16RST             |  /* (1 << 17)    TIM16 reset                                               0x00020000  */\
  0 * RCC_APB2RSTR_TIM17RST             |  /* (1 << 18)    TIM17 reset                                               0x00040000  */\
  0 * RCC_APB2RSTR_DBGMCURST            |  /* (1 << 22)    DBGMCU reset                                              0x00400000  */\
  0 * RCC_APB2RSTR_ADC1RST                 /* (1 << 9)     0x00000200                                                            */\
)


#define RCC_BDCR (                      \
  0 * RCC_BDCR_LSEON                    |  /* (1 << 0)     External Low Speed oscillator enable                      0x00000001  */\
  0 * RCC_BDCR_LSERDY                   |  /* (1 << 1)     External Low Speed oscillator Ready                       0x00000002  */\
  0 * RCC_BDCR_LSEBYP                   |  /* (1 << 2)     External Low Speed oscillator Bypass                      0x00000004  */\
  0 * RCC_BDCR_LSEDRV                   |  /* (3 << 3)     LSEDRV[1:0] bits (LSE Osc. drive capability)              0x00000018  */\
  0 * RCC_BDCR_LSEDRV_0                 |  /* (1 << 3)       0x00000008                                                          */\
  0 * RCC_BDCR_LSEDRV_1                 |  /* (2 << 3)       0x00000010                                                          */\
  0 * RCC_BDCR_RTCSEL                   |  /* (3 << 8)     RTCSEL[1:0] bits (RTC clock source selection)             0x00000300  */\
  0 * RCC_BDCR_RTCSEL_0                 |  /* (1 << 8)       0x00000100                                                          */\
  0 * RCC_BDCR_RTCSEL_1                 |  /* (2 << 8)       0x00000200                                                          */\
  0 * RCC_BDCR_RTCSEL_NOCLOCK           |  /* 0x00000000   No clock                                                              */\
  0 * RCC_BDCR_RTCSEL_LSE               |  /* 0x00000100   LSE oscillator clock used as RTC clock                                */\
  0 * RCC_BDCR_RTCSEL_LSI               |  /* 0x00000200   LSI oscillator clock used as RTC clock                                */\
  0 * RCC_BDCR_RTCSEL_HSE               |  /* 0x00000300   HSE oscillator clock divided by 128 used as RTC clock                 */\
  0 * RCC_BDCR_RTCEN                    |  /* (1 << 15)    RTC clock enable                                          0x00008000  */\
  0 * RCC_BDCR_BDRST                       /* (1 << 16)    Backup domain software reset                              0x00010000  */\
)


#define RCC_CR (       \
  R * RCC_CR_HSION     |  /* (1 << 0)     Internal High Speed clock enable      0x00000001  */\
  0 * RCC_CR_HSIRDY    |  /* (1 << 1)     Internal High Speed clock ready flag  0x00000002  */\
  0 * RCC_CR_HSITRIM   |  /* (0x1F << 3)  Internal High Speed clock trimming    0x000000F8  */\
  0 * RCC_CR_HSITRIM_0 |  /* (0x01 << 3)    0x00000008                                      */\
  0 * RCC_CR_HSITRIM_1 |  /* (0x02 << 3)    0x00000010                                      */\
  0 * RCC_CR_HSITRIM_2 |  /* (0x04 << 3)    0x00000020                                      */\
  0 * RCC_CR_HSITRIM_3 |  /* (0x08 << 3)    0x00000040                                      */\
  R * RCC_CR_HSITRIM_4 |  /* (0x10 << 3)    0x00000080                                      */\
  0 * RCC_CR_HSICAL    |  /* (0xFF << 8)  Internal High Speed clock Calibration 0x0000FF00  */\
  0 * RCC_CR_HSICAL_0  |  /* (0x01 << 8)    0x00000100                                      */\
  0 * RCC_CR_HSICAL_1  |  /* (0x02 << 8)    0x00000200                                      */\
  0 * RCC_CR_HSICAL_2  |  /* (0x04 << 8)    0x00000400                                      */\
  0 * RCC_CR_HSICAL_3  |  /* (0x08 << 8)    0x00000800                                      */\
  0 * RCC_CR_HSICAL_4  |  /* (0x10 << 8)    0x00001000                                      */\
  0 * RCC_CR_HSICAL_5  |  /* (0x20 << 8)    0x00002000                                      */\
  0 * RCC_CR_HSICAL_6  |  /* (0x40 << 8)    0x00004000                                      */\
  0 * RCC_CR_HSICAL_7  |  /* (0x80 << 8)    0x00008000                                      */\
  0 * RCC_CR_HSEON     |  /* (1 << 16)    External High Speed clock enable      0x00010000  */\
  0 * RCC_CR_HSERDY    |  /* (1 << 17)    External High Speed clock ready flag  0x00020000  */\
  0 * RCC_CR_HSEBYP    |  /* (1 << 18)    External High Speed clock Bypass      0x00040000  */\
  0 * RCC_CR_CSSON     |  /* (1 << 19)    Clock Security System enable          0x00080000  */\
  R * RCC_CR_PLLON     |  /* (1 << 24)    PLL enable                            0x01000000  */\
  0 * RCC_CR_PLLRDY       /* (1 << 25)    PLL clock ready flag                  0x02000000  */\
)


#define RCC_CR2 (                       \
  0 * RCC_CR2_HSI14ON                   |  /* (1 << 0)     Internal High Speed 14MHz clock enable                    0x00000001  */\
  0 * RCC_CR2_HSI14RDY                  |  /* (1 << 1)     Internal High Speed 14MHz clock ready flag                0x00000002  */\
  0 * RCC_CR2_HSI14DIS                  |  /* (1 << 2)     Internal High Speed 14MHz clock disable                   0x00000004  */\
  0 * RCC_CR2_HSI14TRIM                 |  /* (0x1F << 3)  Internal High Speed 14MHz clock trimming                  0x000000F8  */\
  0 * RCC_CR2_HSI14CAL                     /* (0xFF << 8)  Internal High Speed 14MHz clock Calibration               0x0000FF00  */\
)


#define RCC_CIR (                       \
  0 * RCC_CIR_LSIRDYF                   |  /* (1 << 0)     LSI Ready Interrupt flag                                  0x00000001  */\
  0 * RCC_CIR_LSERDYF                   |  /* (1 << 1)     LSE Ready Interrupt flag                                  0x00000002  */\
  0 * RCC_CIR_HSIRDYF                   |  /* (1 << 2)     HSI Ready Interrupt flag                                  0x00000004  */\
  0 * RCC_CIR_HSERDYF                   |  /* (1 << 3)     HSE Ready Interrupt flag                                  0x00000008  */\
  0 * RCC_CIR_PLLRDYF                   |  /* (1 << 4)     PLL Ready Interrupt flag                                  0x00000010  */\
  0 * RCC_CIR_HSI14RDYF                 |  /* (1 << 5)     HSI14 Ready Interrupt flag                                0x00000020  */\
  0 * RCC_CIR_CSSF                      |  /* (1 << 7)     Clock Security System Interrupt flag                      0x00000080  */\
  0 * RCC_CIR_LSIRDYIE                  |  /* (1 << 8)     LSI Ready Interrupt Enable                                0x00000100  */\
  0 * RCC_CIR_LSERDYIE                  |  /* (1 << 9)     LSE Ready Interrupt Enable                                0x00000200  */\
  0 * RCC_CIR_HSIRDYIE                  |  /* (1 << 10)    HSI Ready Interrupt Enable                                0x00000400  */\
  0 * RCC_CIR_HSERDYIE                  |  /* (1 << 11)    HSE Ready Interrupt Enable                                0x00000800  */\
  0 * RCC_CIR_PLLRDYIE                  |  /* (1 << 12)    PLL Ready Interrupt Enable                                0x00001000  */\
  0 * RCC_CIR_HSI14RDYIE                |  /* (1 << 13)    HSI14 Ready Interrupt Enable                              0x00002000  */\
  0 * RCC_CIR_LSIRDYC                   |  /* (1 << 16)    LSI Ready Interrupt Clear                                 0x00010000  */\
  0 * RCC_CIR_LSERDYC                   |  /* (1 << 17)    LSE Ready Interrupt Clear                                 0x00020000  */\
  0 * RCC_CIR_HSIRDYC                   |  /* (1 << 18)    HSI Ready Interrupt Clear                                 0x00040000  */\
  0 * RCC_CIR_HSERDYC                   |  /* (1 << 19)    HSE Ready Interrupt Clear                                 0x00080000  */\
  0 * RCC_CIR_PLLRDYC                   |  /* (1 << 20)    PLL Ready Interrupt Clear                                 0x00100000  */\
  0 * RCC_CIR_HSI14RDYC                 |  /* (1 << 21)    HSI14 Ready Interrupt Clear                               0x00200000  */\
  0 * RCC_CIR_CSSC                         /* (1 << 23)    Clock Security System Interrupt Clear                     0x00800000  */\
)

#if !defined(DMA_EN)
  #define DMA_EN 0
#endif

#if !defined(SRAM_EN)
  #define SRAM_EN 0
#endif

#if !defined(FLITF_EN)
  #define FLITF_EN 0
#endif

#if !defined(CRC_EN)
  #define CRC_EN 0
#endif

#if !defined(GPIOA_EN)
  #define GPIOA_EN 0
#endif

#if !defined(GPIOB_EN)
  #define GPIOB_EN 0
#endif

#if !defined(GPIOC_EN)
  #define GPIOC_EN 0
#endif

#if !defined(GPIOD_EN)
  #define GPIOD_EN 0
#endif

#if !defined(GPIOF_EN)
  #define GPIOF_EN 0
#endif

#if !defined(DMA1_EN)
  #define DMA1_EN 0
#endif


#define RCC_AHBENR (                                \
  DMA_EN        * RCC_AHBENR_DMAEN                  |  /* (1 << 0)     DMA1 clock enable                                         0x00000001  */\
  SRAM_EN       * RCC_AHBENR_SRAMEN                 |  /* (1 << 2)     SRAM interface clock enable                               0x00000004  */\
  FLITF_EN      * RCC_AHBENR_FLITFEN                |  /* (1 << 4)     FLITF clock enable                                        0x00000010  */\
  CRC_EN        * RCC_AHBENR_CRCEN                  |  /* (1 << 6)     CRC clock enable                                          0x00000040  */\
  GPIOA_EN      * RCC_AHBENR_GPIOAEN                |  /* (1 << 17)    GPIOA clock enable                                        0x00020000  */\
  GPIOB_EN      * RCC_AHBENR_GPIOBEN                |  /* (1 << 18)    GPIOB clock enable                                        0x00040000  */\
  GPIOC_EN      * RCC_AHBENR_GPIOCEN                |  /* (1 << 19)    GPIOC clock enable                                        0x00080000  */\
  GPIOD_EN      * RCC_AHBENR_GPIODEN                |  /* (1 << 20)    GPIOD clock enable                                        0x00100000  */\
  GPIOF_EN      * RCC_AHBENR_GPIOFEN                |  /* (1 << 22)    GPIOF clock enable                                        0x00400000  */\
  DMA1_EN       * RCC_AHBENR_DMA1EN                    /* (1 << 0)     DMA1 clock enable                                         0x00000001  */\
)

#if !defined(SYSCFGCOMP_EN)
  #define SYSCFGCOMP_EN 0
#endif

#if !defined(ADC_EN)
  #define ADC_EN 0
#endif

#if !defined(TIM1_EN)
  #define TIM1_EN 0
#endif

#if !defined(SPI1_EN)
  #define SPI1_EN 0
#endif

#if !defined(USART1_EN)
  #define USART1_EN 0
#endif

#if !defined(TIM16_EN)
  #define TIM16_EN 0
#endif

#if !defined(TIM17_EN)
  #define TIM17_EN 0
#endif

#if !defined(DBGMCU_EN)
  #define DBGMCU_EN 0
#endif

#if !defined(SYSCFG_EN)
  #define SYSCFG_EN 0
#endif

#if !defined(ADC1_EN)
  #define ADC1_EN 0
#endif


#define RCC_APB2ENR (                               \
  SYSCFGCOMP_EN * RCC_APB2ENR_SYSCFGCOMPEN          |  /* (1 << 0)     SYSCFG and comparator clock enable                        0x00000001  */\
  ADC_EN        * RCC_APB2ENR_ADCEN                 |  /* (1 << 9)     ADC1 clock enable                                         0x00000200  */\
  TIM1_EN       * RCC_APB2ENR_TIM1EN                |  /* (1 << 11)    TIM1 clock enable                                         0x00000800  */\
  SPI1_EN       * RCC_APB2ENR_SPI1EN                |  /* (1 << 12)    SPI1 clock enable                                         0x00001000  */\
  USART1_EN     * RCC_APB2ENR_USART1EN              |  /* (1 << 14)    USART1 clock enable                                       0x00004000  */\
  TIM16_EN      * RCC_APB2ENR_TIM16EN               |  /* (1 << 17)    TIM16 clock enable                                        0x00020000  */\
  TIM17_EN      * RCC_APB2ENR_TIM17EN               |  /* (1 << 18)    TIM17 clock enable                                        0x00040000  */\
  DBGMCU_EN     * RCC_APB2ENR_DBGMCUEN              |  /* (1 << 22)    DBGMCU clock enable                                       0x00400000  */\
  SYSCFG_EN     * RCC_APB2ENR_SYSCFGEN              |  /* (1 << 0)     SYSCFG clock enable                                       0x00000001  */\
  ADC1_EN       * RCC_APB2ENR_ADC1EN                   /* (1 << 9)     ADC1 clock enable                                         0x00000200  */\
)

#if !defined(TIM3_EN)
  #define TIM3_EN 0
#endif

#if !defined(TIM14_EN)
  #define TIM14_EN 0
#endif

#if !defined(WWDG_EN)
  #define WWDG_EN 0
#endif

#if !defined(I2C1_EN)
  #define I2C1_EN 0
#endif

#if !defined(PWR_EN)
  #define PWR_EN 0
#endif


#define RCC_APB1ENR (                               \
  TIM3_EN       * RCC_APB1ENR_TIM3EN                |  /* (1 << 1)     Timer 3 clock enable                                      0x00000002  */\
  TIM14_EN      * RCC_APB1ENR_TIM14EN               |  /* (1 << 8)     Timer 14 clock enable                                     0x00000100  */\
  WWDG_EN       * RCC_APB1ENR_WWDGEN                |  /* (1 << 11)    Window Watchdog clock enable                              0x00000800  */\
  I2C1_EN       * RCC_APB1ENR_I2C1EN                |  /* (1 << 21)    I2C1 clock enable                                         0x00200000  */\
  PWR_EN        * RCC_APB1ENR_PWREN                    /* (1 << 28)    PWR clock enable                                          0x10000000  */\
)


__STATIC_FORCEINLINE void init_rcc(void) {

  /* Perform pre-configuration of the hardware */
  configure_flash();

  #if defined RCC_AHBENR
    #if RCC_AHBENR != 0
      RCC->AHBENR = RCC_AHBENR; /* 0x40021014: RCC AHB peripheral clock register, Address offset: 0x14                               */
    #endif
  #else
    #define RCC_AHBENR 0
  #endif

  #if defined RCC_APB1ENR
    #if RCC_APB1ENR != 0
      RCC->APB1ENR = RCC_APB1ENR; /* 0x4002101C: RCC APB1 peripheral clock enable register, Address offset: 0x1C                       */
    #endif
  #else
    #define RCC_APB1ENR 0
  #endif

  #if defined RCC_APB2ENR
    #if RCC_APB2ENR != 0
      RCC->APB2ENR = RCC_APB2ENR; /* 0x40021018: RCC APB2 peripheral clock enable register, Address offset: 0x18                       */
    #endif
  #else
    #define RCC_APB2ENR 0
  #endif

  #if defined RCC_CFGR
    #if RCC_CFGR != 0
      RCC->CFGR = RCC_CFGR; /* 0x40021004: RCC clock configuration register, Address offset: 0x04                                */
    #endif
  #else
    #define RCC_CFGR 0
  #endif

  #if defined RCC_CFGR2
    #if RCC_CFGR2 != 0
      RCC->CFGR2 = RCC_CFGR2; /* 0x4002102C: RCC clock configuration register 2, Address offset: 0x2C                              */
    #endif
  #else
    #define RCC_CFGR2 0
  #endif

  #if defined RCC_CFGR3
    #if RCC_CFGR3 != 0
      RCC->CFGR3 = RCC_CFGR3; /* 0x40021030: RCC clock configuration register 3, Address offset: 0x30                              */
    #endif
  #else
    #define RCC_CFGR3 0
  #endif

  #if defined RCC_CSR
    #if RCC_CSR != 0
      RCC->CSR = RCC_CSR; /* 0x40021024: RCC clock control & status register, Address offset: 0x24                             */
    #endif
  #else
    #define RCC_CSR 0
  #endif

  #if defined RCC_AHBRSTR
    #if RCC_AHBRSTR != 0
      RCC->AHBRSTR = RCC_AHBRSTR; /* 0x40021028: RCC AHB peripheral reset register, Address offset: 0x28                               */
    #endif
  #else
    #define RCC_AHBRSTR 0
  #endif

  #if defined RCC_APB1RSTR
    #if RCC_APB1RSTR != 0
      RCC->APB1RSTR = RCC_APB1RSTR; /* 0x40021010: RCC APB1 peripheral reset register, Address offset: 0x10                              */
    #endif
  #else
    #define RCC_APB1RSTR 0
  #endif

  #if defined RCC_APB2RSTR
    #if RCC_APB2RSTR != 0
      RCC->APB2RSTR = RCC_APB2RSTR; /* 0x4002100C: RCC APB2 peripheral reset register, Address offset: 0x0C                              */
    #endif
  #else
    #define RCC_APB2RSTR 0
  #endif

  #if defined RCC_BDCR
    #if RCC_BDCR != 0
      RCC->BDCR = RCC_BDCR; /* 0x40021020: RCC Backup domain control register, Address offset: 0x20                              */
    #endif
  #else
    #define RCC_BDCR 0
  #endif

  #if defined RCC_CIR
    #if RCC_CIR != 0
      RCC->CIR = RCC_CIR; /* 0x40021008: RCC clock interrupt register, Address offset: 0x08                                    */
    #endif
  #else
    #define RCC_CIR 0
  #endif

  #if defined RCC_CR
    #if RCC_CR != 0
      RCC->CR = RCC_CR; /* 0x40021000: RCC clock control register, Address offset: 0x00                  */
    #endif
  #else
    #define RCC_CR 0
  #endif

  #if defined RCC_CR2
    #if RCC_CR2 != 0
      RCC->CR2 = RCC_CR2; /* 0x40021034: RCC clock control register 2, Address offset: 0x34                                    */
    #endif
  #else
    #define RCC_CR2 0
  #endif

#if 0
  NVIC_SetPriority(RCC_IRQn, NVIC_EncodePriority(NVIC_GetPriorityGrouping(), 0, 0));
  NVIC_ClearPendingIRQ(RCC_IRQn);
  NVIC_EnableIRQ(RCC_IRQn);
#endif
  
  /* Proceed with additional actions */
  wait_for_clock_settles();

} /* init_rcc() */


__STATIC_FORCEINLINE void configure_flash(void) {
  #if (HCLK > 24)
    /* Configure flash to use 1 wait state and enable prefetch buffer */
    FLASH->ACR = FLASH_ACR_LATENCY | FLASH_ACR_PRFTBE;
  #endif
}

__STATIC_FORCEINLINE void wait_for_clock_settles(void) {
  #if R
    while(RCC_CFGR_SWS_PLL != (RCC->CFGR & RCC_CFGR_SWS_PLL)) {}
  #endif

  // SystemCoreClockUpdate();

} /* wait_for_clock_settles() */

#undef A
#undef B
#undef C
#undef D
#undef R


////////////////////////////////////////////////////////////////////////////////////////
//  This code was generated for the stm32f030x6 microcontroller by "stm32cgen" tool.
//                          https://github.com/a5021/stm32codegen                          
//  Arguments used:
//    -l 030f4 -p RCC -m rcc -f init_rcc -D R "(HCLK >= 12)" XMUL "(HCLK / 4 - 2)
//    /* Calculate PLL multiplication factor      */" A "((XMUL >> 0) & 1)  /* LSB or
//    BIT0 of PLL multiplication factor */" B "((XMUL >> 1) & 1)  /*        BIT1 of
//    PLL multiplication factor */" C "((XMUL >> 2) & 1)  /*        BIT2 of PLL
//    multiplication factor */" D "((XMUL >> 3) & 1)  /* MSB or BIT3 of PLL
//    multiplication factor */" --tag-bit R SW_PLL PLLON HSION HSITRIM_4 --tag-bit A
//    PLLMUL_0 --tag-bit B PLLMUL_1 --tag-bit C PLLMUL_2 --tag-bit D PLLMUL_3 --force-
//    inline --pre-init configure_flash --post-init wait_for_clock_settles -F
//    "__STATIC_FORCEINLINE void configure_flash(void) {" -F "  #if (HCLK > 24)" -F "
//    /* Configure flash to use 1 wait state and enable prefetch buffer */" -F "
//    FLASH->ACR = FLASH_ACR_LATENCY | FLASH_ACR_PRFTBE;" -F "  #endif" -F } -F "" -F
//    "__STATIC_FORCEINLINE void wait_for_clock_settles(void) {" -F "  #if R" -F "
//    while(RCC_CFGR_SWS_PLL != (RCC->CFGR & RCC_CFGR_SWS_PLL)) {}" -F "  #endif" -F
//    "" -F "  // SystemCoreClockUpdate();" -F "" -F "} /* wait_for_clock_settles()
//    */" -F "" -F "#undef A" -F "#undef B" -F "#undef C" -F "#undef D" -F "#undef R"
////////////////////////////////////////////////////////////////////////////////////////


#ifdef __cplusplus
  }
#endif /* __cplusplus */
#endif /* __RCC_H__ */

CREATE_EOF

# Create main.c file in src directory from embedded data using Here Document
main_c_file="src/main.c"
if [ ! -f "$main_c_file" ]; then
  op_counter=$(expr $op_counter + 1)
  cat << EOF > "$main_c_file"
#include "main.h"

int main(void) {

  for(init();;idle());

}

__STATIC_FORCEINLINE __SYSTICK_VOLATILE uint32_t * get_uptime(void) {
  extern __SYSTICK_VOLATILE uint32_t uptime;
  return &uptime;
}

__STATIC_FORCEINLINE void set_uptime(uint32_t t) {
  extern __SYSTICK_VOLATILE uint32_t uptime;
  uptime = t;
}

#if YES == SYSTICK_IRQ_EN

__STATIC_FORCEINLINE void process_systick_event(void) {}
void SysTick_Handler(void);
void SysTick_Handler(void) {

#else

__STATIC_FORCEINLINE void process_systick_event(void) {
  if (0 == (SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk)) {
    return;
  }
  
#endif
  {
    static uint32_t cnt;
  
    if (++cnt == 1000) {
      cnt = 0;
      set_uptime(*get_uptime() + 1);
      GPIOA->ODR ^= GPIO_ODR_4;  
    } else if (cnt == 500) {
      GPIOA->ODR ^= GPIO_ODR_4;
    }
  }
}

__STATIC_FORCEINLINE void idle(void) {
  /* The body of the main program loop follows here */
  
  process_systick_event();
  
} /* idle() */

__SYSTICK_VOLATILE uint32_t uptime = 0;

EOF
  echo "File $main_c_file created."
fi

if [ $op_counter -eq 0 ]
then
  echo "Nothing to do."
else
  echo "$op_counter items created."
  make debug
fi

# Wait for any key to be pressed
press_any_key
