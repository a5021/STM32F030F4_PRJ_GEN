#!/bin/sh

nothing_to_do=1

# Array with directory names
directories=("inc" "src" "MDK-ARM")

# URLs for files
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Source/Templates/system_stm32f0xx.c
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Source/Templates/gcc/startup_stm32f030x6.s
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Source/Templates/arm/startup_stm32f030x6.s
#
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Include/system_stm32f0xx.h
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Include/stm32f0xx.h
#    https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master/Include/stm32f030x6.h
#
#               https://github.com/ARM-software/CMSIS_6/tree/main/CMSIS/Core/Include
#
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_compiler.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_armclang.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_gcc.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_iccarm.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_version.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/core_cm0.h
#    https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/cmsis_armcc.h

fname1=("system_stm32f0xx.c" "startup_stm32f030x6.s")
fname2=("system_stm32f0xx.h" "stm32f0xx.h" "stm32f030x6.h")
fname3=("cmsis_compiler.h" "cmsis_armclang.h" "cmsis_gcc.h" "cmsis_iccarm.h" "cmsis_version.h" "core_cm0.h" "cmsis_armcc.h")

url1="https://raw.githubusercontent.com/STMicroelectronics/cmsis_device_f0/master"
url2="https://raw.githubusercontent.com/ARM-software/CMSIS_6/main/CMSIS/Core/Include/"


# Function to check for the existence of a directory and create it if it doesn't exist
create_directory() {
  if [ ! -d "$1" ]; then
    mkdir "$1"
    nothing_to_do=0
    echo "Directory $1 successfully created."
  fi
}


# Function to check for the existence of a file and create it if it doesn't exist
create_file() {
  if [ ! -f "$1" ]; then
    echo "$2" | base64 -d | tar xvjf -
    nothing_to_do=0
    echo "File $1 created."
  fi
}


# Function to check if a file exists and download it if it doesn't
download_file() {
  url="$1"
  filename="$2"
  if [ ! -f "$filename" ]; then
    curl -o "$filename" "$url"
    nothing_to_do=0
    echo "File $filename successfully downloaded."
  fi
}


# Create directories
for dir in "${directories[@]}"
do
  create_directory "$dir"
done

download_file "${url1}/Source/Templates/${fname1[0]}" "src/${fname1[0]}"
download_file "${url1}/Source/Templates/gcc/${fname1[1]}" "${directories[1]}/${fname1[1]}"
download_file "${url1}/Source/Templates/arm/${fname1[1]}" "${directories[2]}/${fname1[1]}"

# Download files
for filename in "${fname2[@]}"
do
  download_file "${url1}/Include/${filename}" "inc/${filename}"
done

for filename in "${fname3[@]}"
do
  download_file "${url2}${filename}" "inc/${filename}"
done

create_file "Makefile" "`cat << EOF
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
ShjwK8UB5xe4XckU4UJCzXHocA==
EOF`"

create_file "stm32f030x6_flash.ld" "`cat << EOF
QlpoOTFBWSZTWXgpltoABtnfgf+SQP3/2y/v3yD/7//6AAgACFAFnuGOWdHc47YOTrrXTCSSGTTU
ZMVPyo9I9T9U9QaNqeoA00ZAM0g9QAJRNExGSp6myR5R6QYEwAExHqGhgAgwkRIJ6iI8o9TaTRo2
k0NPUaaaA9QyekNDQMQcAwjCaYhgEAyAGEaZMmEYCGgkUT1ATCaZNSn4qA9TQyAMAjJoaAeoH6p5
9OvqYkboEhYGzSQ+j5+3ZFLGMSGAnJpjBAZAEB1cGiGt1y9nbZZEPXHSCLXI5Yyr6ogngpG8sTFg
wFGJsiEQ24ggsVycsoS5E5bboREqXElAoL1e7FWohJVYJc7EhCvEjCxC6YwkiE3CiAScDRyc9vyX
EaUvWLeGGPEtpsXWH0dP2/G6pPrm4aJ5r2ZNPPBqCNtWc40BGxKWGVT0q82mVGkyfZr0XFoykmZ4
0TGVw7qFIKHOZJFoKvBcm9OXpND9Zh9IbWpA4yGTXixjIm7bTbuDHEiQy39+pc5c2ClpK0c8MuSv
pfBoZ45tKKFha4h6C6sMBOwVWXHfOkJvIkaNAoPlVos4Vy1sirQcqi5EZr7mI1WUX5rdEc9ldPVX
cLskHeZQF0MG5gbFnBPQywFN9demtbYJydHTOXt8MkTXebwVt/ltCViZfxK9csGvKiJgIWg2mCVb
iKe9tG6MYNDMN9JVd7yZWgDz+is7zOkBuPpaR3ExZXEkoOsNuzcebCUttIiBslOWEuGN6OiZdIbz
TMt5kkubVq1Y5m/T/mQOsFrHcMiI2KUH7QbA/Pf+tj1FhGeDlsfFzSUVQluPs1S6N5b9phoX7dxm
ESk1JTlCsLS6Mp0zacrGqWUROlTCKmwmsqGs5XJpCiNBOhqEkHkZI7u/XMC8wH1pFqQp91vRND3b
xMxUJhed1DFPSBXMKRwyAmFA+YGTlIS5B0kLgc0E/YL+gMzAF3FV9Xb8PgAx7kKDYExouaaLtOfH
jmDFqbwUTG6udVNxqTuAqAxAjPY3zJMyvGL0gSWtHP2sdK0Kg0CljxKNDhZCLgLS47xkFp0mte3q
+jdD527AYxRyNsbbTeIpgbe1bPBnoeG3m5SYJ4tqtJKUuKI9yzpRQwzJI53HqRkFRMI77WwnpRDL
MhKEin2QjOtCKK/JYSEvXMZgi9TQ4pytm2TneQQXnry/zlFheJsklyBkwWcARMWUwkyMscYwgIiR
KQ23XIRMK65b9K1JHDqUrNuj8aJdbaqnQwimXGg1ggg2GVmxy0oYjcQSKx02h4OOtQYe/oVtgx96
UHDClLnGF8cUfUC0tspOQ69SIji+aWqbuRCARJC1Vz8ksuN0ESSKFsymW+5k11VUiVPaxGDiQihi
DCW+4pW2dJfMHpRKCQssWN4yHBfuMpow3MRmW0bO4nYI2YfQXDGWomwdwbIqrs5dqkTgJbIuYZKT
GzjjGbqLb6Zoy0HnqtpjByIoNkohoP9aF87JwkSi4kjvzMcBHEWCOKXYyAxRR470OksW2MB4orM9
o6czuBw5rC0GDr8BqHxwxIOcNp2SORrfpRiJV1zllmfIF5rgUsZW8kU7rqBLDWEjc361youdrjGt
l4Jo1EpuHkLyA7KxpHaR0qujO01CGA99hTOUnerZE0NaNLhUU8JA8L09T+tV5C6z7tBSs2QIIIPS
QmQUEVUsHl0zA9hXelq1IOytoLMEQiZZoQQqTAJcQt6naSKwuDXrz7CkoLjs9AmaLo0GSix8bShI
zRqBwngQddsiHEIbQl/xdyRThQkHgpltoA==
EOF
`"

create_file "MDK-ARM/Project.uvprojx" "`cat << EOF
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
5IpwoSE3Z2LA
EOF
`"

create_file "./MDK-ARM/startup_stm32f030x6.s" "`cat << EOF
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
IXckU4UJAoh7p0A=
EOF
`"

# Create main.c and main.h files in src and inc directories respectively from embedded data using Here Document
main_c_file="src/main.c"
if [ ! -f "$main_c_file" ]; then
  nothing_to_do=0
  cat << EOF > "$main_c_file"
#include <stdio.h>
#include "main.h"

int main(void) {

  for(init();; idle());

}
EOF
  echo "File main.c successfully created in src directory."
fi

main_h_file="inc/main.h"
if [ ! -f "$main_h_file" ]; then
  nothing_to_do=0
  cat << EOF > "$main_h_file"
#ifndef __MAIN_H_
#define __MAIN_H_

#include "stm32f0xx.h"

#define NO 0
#define YES (!NO)

__STATIC_FORCEINLINE void init(void) {
  /* intentionally left empty */
}

__STATIC_FORCEINLINE void idle(void) {
  /* intentionally left empty */
}


#if defined(__GNUC__) && !defined(__clang__)
void _close_r(void){} void _close(void){} void _lseek_r(void){} void _lseek(void){} void _read_r(void){} void _read(void){} void _write_r(void){}
#endif


#endif /* __MAIN_H_ */
EOF
  echo "File main.h successfully created in inc directory."
fi

if [ $nothing_to_do -gt 0 ]
then
  echo "Nothing to do."
fi

make

# Wait for any key to be pressed (if your system supports the read command)
read -n 1 -s -r -p "Press any key to continue..."
