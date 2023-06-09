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

download_file "${url1}/Source/Templates/${fname1[0]}" "$directories[1]/${fname1[0]}"
download_file "${url1}/Source/Templates/gcc/${fname1[1]}" "${directories[1]}/${fname1[1]}"
download_file "${url1}/Source/Templates/arm/${fname1[1]}" "${directories[2]}/${fname1[1]}"

# Download files
for filename in "${fname2[@]}"
do
  download_file "${url1}/Include/${filename}" "${directories[0]}/${filename}"
done

for filename in "${fname3[@]}"
do
  download_file "${url2}${filename}" "${directories[0]}/${filename}"
done

create_file "Makefile" "`cat << EOF
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
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
QlpoOTFBWSZTWZuzsWAACb/fkN1UXGf/97/v3/T//9/wBAAACGAWPwAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAcwmgNAaNGEaDEaYmTE0GEaBkAyYHMJoDQGjRhGgxGmJkxNBhGgZAMmBzCaA0Bo0YRoMRp
iZMTQYRoGQDJgcwmgNAaNGEaDEaYmTE0GEaBkAyYHMJoDQGjRhGgxGmJkxNBhGgZAMmAVTUQQAQA
E0AGhBoI0yZNQxGT0RtTJyf4/1bXatWKjs/tiZErCKgtRaoREpUEBQ89KKKypYokKFoKqtLOLUKU
owqhRW/myfm0+Tt0PqZLK0dVH/f9buq3/l39uT0/z13e6P5+VgwNa1djyvocf2H2rb2x2o+nbyeV
i+rU1VtNZufyhX5e57+/4LIiMWCIdzSRh6Tlcf1y+n+n/tfWKpWuKqjliqKN0VVXRVKfTr5ZVKwy
LGp7LKVXyaWBhpj0EiuYfdkzIvoU18uPWf1Psy2mLqpVVW9gYCIIiquRVVC6VVFazSaXxPBioIhW
BDWebQauLWf7F9//ZpdIrC1VSuiUVWD9HWqzQ/8IwYKu+p53xRF12Ar8H738lllnbs4jy2Nza5mp
Ub20jBgrAxf7Mm5wcF1112ZXUpCuLg4rIswGtXo5qLK+k2DyciuDi5GJF7pwcER1uc8NKars2hpa
iLLvA4ev7MWTMizjjpJVvf8xWw/FG+vna2sizSP1EIZCrFh4XyPy9ba3Ea2JZqLtjAj/HW4+n8W2
tVPYsouujUssRZLxdYuu/FdzLrEYH1rXxfFi4IXc7JT8lfvNqEfO1G08X4a6rSrW0u5y6WKo/Eiy
M1MkWLtT7L6Po9Wav0RoQ9qwayl2pYrlcrWyS+hsYMo1wrSZrK9KKpcirIr966mF3KjJZYUdRwMm
hg+xHFzGhdpWc30anKxs/6e9obxBUNxFlRFWVFRWtznY5WSqyREREQiEKZCLIVEEQ6HmWvEV2uT/
XBrKqKqIREIjYsFkWayxddFLIq6iyqsiLrN7hZgMSFiFlkRZUYscc8DFFRkWWVViliFWUsRazCKu
qEUVFItZT/dVFyKosWVizLjMjLFcyVRmXYkKrJCy7O6quWWFLKhkhVPv5fRz37Z5+f0fZ9EutMsf
tex+uLSmTsaWs2v0ZKsyZn+WDPOzAjNghZgwWR9ay71LNi6vpZPcsxaX8GT9UNSND+Lcu0P7PM8W
D/Lg4NbW1LOVrWfsYtKPncVmTnYsH6NTY1Oc5EXZtLBZqYtTFixWZsGbA9je1PezV7kLs35slyI8
zc4ORddkycr+79G84OxscjajEu5lzY73gZMHFcyciy7ndrtdLlbWb53W/JgwVyPwWODpZN7QwVuV
1LORH9Xa63arA3ODmRdxbGxdWKoVmxYtZpRqdLlfwamCzEsaGpyI0IiI1sV1nU+Ta4OxZraHFtYG
h5nkbnQ9j2ultcHFVG8ij2Nyxc5F3U6HkeR5Gl+T7WpoaGhoaGs1M1UWVR6Wtra2tra2trZtZsZs
2bJizbPHv/S5nveqLq6FPWz8yPWyR0YPIweZhdk1MljJqWQ9Z4tBzOZvcjmbzi4tj3Pc2ldysGxW
xVnFxd7JWx6TJpZKVzPe6Fys2s7GhpYvYV1rI7nqel6zB7FZPYevlXB5VVUVCHKseD3OFYOpgwam
gvXczbmowhDqdDvWrnaupmVoWXe5wWXdK73us95yM3sanU6fe5XInBvcCy7VpYvBdm6nQs0OhyvV
6mp3sDNV0dzQ8zJk3MGSMmKsFymtsRY8zUs8qVTQusPr/noGRsPzQ71U7Cw737WPW/J5i74tjneZ
zKosssKeKI7jJkiIiIiIiIiIiIiIiIiLFlkRY5gxMGDqHUXcDBZHQOccXE8HlOsyNDQ4llkRERHl
a2CIswYPz/idp7ne4HaeRD+jyG8yZin9BVbW1EcDePQ+KI8W4siIqIusssuuZs3aWWWPOXXXFlm0
9hddc1neQh9hcxYsSyyIiIjoPcXXeU8pDysGC39/5HZX/SnE1ul+Z5jW1t5suuiOBYsd6yyI5xZZ
6l0QhGh2uUuXXXVgwWWWWLLIjJk6ldqoqK85gwdjequRoPU8Hi4mBuNTUiMH0Ii665wLrrmrcr7j
4HqOk0NC5Wwu1uR/Fi6GDkZszBuaVYsmlGDS0MzS0q0quWVZViyrKiIiIiIj6DMuuiLms0H4/8sm
SIiNR4l10REdh7jmMMNhZZEREREWNZ/g/o8G9WbNZ2oq66zodzUWMWKI5TA5hgwRERERUV2FlmLt
ZVJLHExYoiI/o7K7jd0tymbNuK5n0NKnOa3UPV8w1apJJEyPgfI5mhEYslyrLIjMssuf8tB9Vzme
5yOxa6y12QeBrLDwYvVX1nKMGBFldCrLiIRCOhkOPB+3Qwajg7iP8vKaXOiNzNm0ty7JkuwYsDA4
CrLPWZnn/B1mEbH0nnV8FcVIqysaylYmLJD9mxsRERERERwFlmZzDsYMERERERERERERERzqqyzu
OlddERERERHiWWRGwss5RZZEansb1nsXRdY6zWZs0RvfO0Ij5j9XcajwLOhkwWfWhXBBgwWXQwRs
bGo6nkFF/fj5KmojB+48TyjvRCIj0uelWVWef/wpZZERHKKWWRERm8SOUd49JkyR8xZwusiIiIiN
B2l1XVkWWRUVFRURERERERERFRW9534I7UIs0mTJ8W8uuiIj+7F6UYMF3Kuu1d179Rd8HqWWWfM9
pGbN5Gb2OpZZZd+8ZMkREREVRFUeX2ly5qLKosqjQWWWNRqbSIGLFYWWbX6kXXfONBdd5DoFOdDU
e98vYfB8hkdbFY7zZsSoiIiI1FlkRERERJEbjlOYwYIjBiq6qLLqVchUdY9DuffwYmgzIiIiIj3l
lnUVZVlRUVYqyrKior7Syz7eU5ylR0mJidRZZ9jjynYZHwPYd75KjxfULoiIs2cw0rNqzA6yx4K2
lOB9yve5X3tLA96zoFObYfE6pgV7mIvWJY2Ggv2FOVueh9CIs+81HpNI8D3nTkcBzVQcHxNJDAMm
o2nXn7+xRX2je6h/8MhVOo72lERERERER0e44g3HQLjMxHAgsPYFbMxDWcqnE/grEhCNzcsWWXNp
7D5IXIe0sMyt1KjzDe7nlGKFhZYdwgsegaiGRiLegz0qrLkOQ6iwyMiq3ipx0DZVQ8CrUU3WdZ8y
LM2JdZYsujBkYG0MDIxMDAwMLvQecqqcAeU6CqsMg0LaC53FVTNiRBA2EKpBkO39hHTw09dNb8UV
ZGxFkVdYzXaEGhiWb2tqaGCK0qgitD/SqMFZqxVrFhS40LKVmVqZMWhoUIhYyUZNC5khYsVpRaSD
Wg6WJFYmozEMy5gQQajQZGBgWKhgZGLNUQYoIqCEWsWIZCxUK8VsQ76VrPUfeMSnqMiy7uPsNzrR
EMTS8poNxsVCPUVtK/42HQioil4U6mw8TlK9o9LQiP/T9nE6C5Xa4kdsDeXp+H1J4OphGC7gbTiG
bAsQ4ijA1lcTEyYbm8wGuvUiIhG/qKqnhWxIiqqEQinMdaq0HkFfE9z6BpeDyrIs2m08TxwDoVCo
PtPYeXVBR7sdKKwexZF1l0U8hsDpMxgMSBFVSxc6DYVpMlMim46VHOK8WSyll111VoLlyEIfFyIi
IiIi5iZBXqH2XdSI/Ippcz4PIrJFEWXeRzoqIGDyqrzuZicxDEseJ5Tp+JidhXwVvRREFEPCxgd5
DoDnNA1nY0B7dx3ENJxQiMTmK+3Qd51spFUSKzNA9x6zlh1FV7NxW1T1DsDSOcqiO4dKLbCqTcdA
3lej06h3NKxYwRV1ly5BUEKsZHyPQd4MCup1IiIsN6KoiKQgPIQrVVUuWqroj8jqD7jE2HYMxip5
kRCjjjxIikRTg4Ij1lV7TmNgufIhDoFg8Hwa1kdba4NzBEZL5MmS91xkXCxzEOl0rDpH7n7ngYFZ
lYlbaVpQpEoLlJDgeD1G0bxoHQXpXEmolVWCKqNKzW7lizBgi6sErWZHwLkMiwyMCxyORYssiIiI
iIjEVpMWgb4VWjUL94uYENWQay1ysFVhVZIiEEIEUwaCwZHw+/a2tJ5tJo1sERCw1sAvQ+RuKyO7
5FeLvPwMMCG5ufcK5yu3qe8VFV5bDqe6CjaRTlIEG0uZhnDnoV3EIYHT7NLIp8xWk3syIDEuVZ4L
llnuOgr9uwuLj3jWZmJ4iuLYRDWVwHMWM+doRdm8iGpFRZiwYB8x4HY7EREaTIbCxmQgxYrmk9vp
PUVVO4+tsNSn3KioreNOQtT1/L9+09wOYc56SGr1jdTcQ+lZaIWRYQV6CKVTJ8xYrnVo2GZWsOo9
p6CqpcwyNBFVT5ymswILjyj6FmBiLEIQsVYyIe5jVVRvrQoseB8CvqIcB8TVTUVRrIQQWKsLHHVh
gK6PcbmO5ORus0LsFnwOlgXI3MlRd0HSszd7Q0KuMGSqNWkwQyYKUuzXZNDBoDgeYsaxC4QohBtO
gzNYxMTU2OQHz409BWs85YWK0lWFHibxkDNo5K3Dj9L6SxVUuV4upGpESkWRam4v+22hodBrVT0j
E0HYgzZrHVVba5Xa2rNKF0YoxYnauvMWCxdFkYpTFdiycSqOQ0Gg3CxYxLFPaZGkwNBmPaZmCVEo
5zSWNhpF8BiYVkUpCG0wFMTBXWiIOk3G8ajMK9Z4vFpMm87RyGxTTZTassssixFkRFWN5gN4hpLl
GItwG9gVrDFOKBZqPnMz5uQ0EMTlscDe1EcjkREREQhEWO31neVXnpXrK9A0m8fMekpsbHUcxVXX
RER3HWQgh0nQLlxixREIe4/1DyHOVpLDiefQ0IiIiIjiLLIixtK3NxYr5HeeB2DsuqvJ7NveOc3t
7YbTo7i5WRpz+/yNp5i/5grBgK95zkH8+Xkn25GJGg4OVxWLLLLFhD1KazlPtKqly50lUQ/Gn/4u
5IpwoSE3Z2LA
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
