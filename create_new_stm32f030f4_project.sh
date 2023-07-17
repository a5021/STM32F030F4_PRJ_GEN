#!/bin/bash

function press_any_key {
    echo -n "Press any key to continue..."
    # read one character of input and discard it
    read -n 1 -s -r
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
#
#    https://raw.githubusercontent.com/posborne/cmsis-svd/master/data/STMicro/STM32F030.svd
#    https://raw.githubusercontent.com/posborne/cmsis-svd/master/data/STMicro/STM32F031x.svd

fname1=("system_stm32f0xx.c" "startup_stm32f030x6.s")
fname2=("system_stm32f0xx.h" "stm32f0xx.h" "stm32f030x6.h")
fname3=("cmsis_compiler.h" "cmsis_armclang.h" "cmsis_gcc.h" "cmsis_iccarm.h" "cmsis_version.h" "core_cm0.h" "cmsis_armcc.h")

raw_github="https://raw.githubusercontent.com/"

url1="${raw_github}STMicroelectronics/cmsis_device_f0/master"
url2="${raw_github}ARM-software/CMSIS_6/main/CMSIS/Core/Include/"
url3="${raw_github}posborne/cmsis-svd/master/data/STMicro/STM32F031x.svd"

op_counter=0

# Function to check for the existence of a directory and create it if it doesn't exist
create_directory() {
  if [ ! -d "$1" ]; then
    mkdir "$1"
    op_counter=$(expr $op_counter + 1)
    echo "Directory $1 created."
  fi
}


# Function to check for the existence of a file and create it if it doesn't exist
create_file() {
  if [ ! -f "$1" ]; then
    echo "$2" | base64 -d | tar xjf -
    op_counter=$(expr $op_counter + 1)
    echo "File $1 created."
  fi
}


# Function to check if a file exists and download it if it doesn't
download_file() {
  if [ ! -f "$2" ]; then
    curl -s "$1" | tr -cd '\11\12\15\40-\176' > "$2"
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

create_file "Makefile" "`cat << EOF
QlpoOTFBWSZTWaME7GcAA5D/kNgyEABe//+Wf//e8P////QEAAAIYAdfXtjzx5yS7wOu9vLcwtMZ
0XDQgIalP0NU3pTbSI/RM0TSbSfqmjRp4jSekPU8pkepoBppAAQlPaIR5Rk0NAAAAAAABoNNAVHq
U/VPJ6p+mlPU009RoGg00AA0BoAAAEiJKn6MQImNTCPUxoCaZNMgAAaANAaHGTJo0Bo0xGRoYhgT
RpiDEaDCAAwSRAjQEmBqSflT09SPQgNA9T0hoaPUaANNDR/277WrALJIRy/eSIIJgzjt4JpHfGwE
JLbjJxByftby2LVe6nv4u7W+nXGNrYIrr8d0IwLDryeTrU5cBggbi/Ah7kpTit0/zh6fneFx2xpO
142Y2Gp3sMpkbJYyoR9LP0bHC9g+/koHNetdzb5GbGuBmYcCbrxRHoxIBGEQcIOV86gwD3CYIb/C
Mz36uwDPj5NsmXolCjs6TUFBd/zqHLbb4GKmNbdv+KxImd1ESWZKBPEpjvSPZVXzxbr32qybGd7a
aab7GPLXtfPxY+rCFrRCBGRjlxYFrAzBE405OO7DlNnQ4zIGeiOPNdz87tVwFRKlVIO8t90xyDT5
Pn1YDEZF7GKvtsrRqZjNTwcqeedNt+1nvxnNrIwfYkDagWwtwdZksBKAtWbAycLqdxjm682R10nq
led1FvjuLWr1pTdxm2pGx7TA4rNhUNe105zb4tstrpMscrOYMT1wYZYsQYFwIUhsVfcKkxHNqvjp
4Y7xmOWZT1MdgDv7O4gB1NINvm8cDaUs1SIGmnPlciwRBkaCWKW/eKA9rihABDL0I3ZMr9aARq76
yacRw7HBKprUXJnr9dY3V1uFbk6BXGuSELcovmPa6YQXmQFMAAh3rQFBcJD0Yoqhky1Y7czrUC5m
w5swfvsgWyMhwGQQyBGPMbg0OTRpRIl8LXKzSa4WYN7dkxXy2clC5QajbjXiGcmxEMqt0eb7Wmjr
+9dHdHEsaeXjlkopVmqQtNtrUWiQyGC9nUCB6DLEpuXD919emTsCgvypj7WhzRmssEgjdkhuiQ1M
cobHSCmxO3AOeVsJro/XyfpouXJQKD0AJpVgMUtH1cJkNMY4I57sW0RWVZuOhcl37uniSvcNGzzg
3wzcQH3DS4RBj5D6XCqUYspjblCAzMF1pKKByhKWB6gF5RxmAVEHoC5Dq5LtHjhNXvD0uit6Lyyw
POyZ1AvSf+mNgUlsztLQF3E5xMQF8qKkw1kKUZtwCzUUoxwLE7X9xFpSNZJH7UB6hgMbuES0tN+k
IBaSV2gzHBR7aUCqU5B48AFmuCNEsGNWpnC+84Bc5J4wdbq1GKu7KAnecxWhFUw30c4CFGosbhg6
7LVgAvRVW9lPOohvh29x9+EVorpDB0uuCNbCLUTvUQijpfYkQChJQGwYwwFcY/76/emSxp8XkU5l
JJWHlgVUg14uLXjjdkEGGFU6iYzvo3rG1zG+6CqbFWWC4KxY9XTyF2hMUfkmFGhGJZpuXmKWru2R
QkDxnvYZGdJohMkKJiqVME6iygO4w4+ZGkl0tLZRSXYZ5GoYwbG1OqUVs2wk+5wO0cRcaGLDXulY
5YUgkJYUdTxuZGpASeSDlIDDUy5XV5aymCgsYiUjKwqDLJab7hlhWExcV3gjUJLzTrdl1UK2eLYi
1wGgHFZNq6bUTSSM7I1BMJWjFKbNGGlUedAAiOGc2JCkA0om2uk3qeBR8ZFXYix3BgjNZ1oOLBDl
bPijYl1NwWNpjSO3CFCWeoIRpDDUczuPOweeG6KB7psRWLIsbBM2lmXhmF0Rg3HSmNHT/MwkXsc6
tAaHM5v6szqhu4+GXOfsXnDPbDejJNeZDIwZDpgMVlRtg7OH66R7aJDnRvtOk0eDl3znVSxTozJm
SZiG5BFMdHjKRgz3rQtGbVxZYkcUPQCTe03ZtqBsmuXJhFz0ogbTbbaNbleGbmVNtLbFoFSIaLLY
cDKcoWAojpgZcieu7wwlldxl87vS+CDoCUWxyTsVCWhSU64HEJt5XLxUJnnm/mojfdywqLyCAcCK
3IDEsQ1NLsuG3aVlaLC/fJcypvOg+vYmgtesba668CRw9mBSKNKp2fbBU7wyyBX2uiC8FQieSJZx
qytZQgRoriaLJTfltv1m3rJ2LvxUOpDY7ByLHW21SYjW4UCCYGRq0B1JkrzGAmnPdYrc1Q6FkEEB
wHeZNCIxJeQX6kzDcEiUKGKKkseDk1uOJks7ujRyqVyDnue1zjtdHCEXoySKk7T1ypawXDPwu2my
QNSBlIvVdCX8xhG0K2BxntvCkFG7OaupmGn1xrd0MdGQdaLaf5Q5oUiF1a2AoGglb1e4KiGKOAHE
alKvREEnrnLeS1ISFiSSUeWuYIgKqqCgalVcjoUIKyim+Ak4c07E0UwaqDjwuwUsspPZLfC4lE1p
hU5kvBYqeIEJuYVhoGic8OqhZgOzi69MwUB4Rf8XckU4UJCjBOxn
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

create_file "project.jdebug" "`cat << EOF
QlpoOTFBWSZTWT2Fk5UAAeLfkNwQdGf/Hj/m34D/9d/6BAAACEACNUpEUEkiBoFNqemTVG2knijy
janqMmmmmI0NNHlAkhCIMhTxJmmkep6Go0ephpGQZNGjT9UY5gTE0GEyZMmRhME00yMTAEMBzAmJ
oMJkyZMjCYJppkYmAIYMXzaq7/omhMyW94TCBkyCiOM01r/J3d0FrjpmBye5UmdiCCMQtW7MvqvF
juao7x/k1mvYQuuqsrKGKkPfrZxDvOHYll/Utkyaul4xJRrMrBAtYwxG/i4dXv1379pcXUIJBUpa
szOTpMhsImBuhk/YWBKKCCcdR0URRswuLEEedhe9BHt7P5bgeDrHlMrIq43EN1Mvr6dM6tg8mN0k
83g6N/bBQx2HNG/hrwDUxzszcMTlBY4uFb1Fq69SMQeeGidKQPF60jKQabKd5acrw0kXOppSb0sf
f1jsO2Il0tNaiZ5jBx6KTNtpNBFQbtH0w4FrpXeYa81BeC3v4Wq/jNS3LBiIm3qqwzpa15lbLOuo
1bbCxpoOi08VcV5v70whEyAcOZOGx1nRPhQXQE1aXX4GY9k6IDyWHUqaaj16Iak0ZXyVHWLy0Oc5
zDMjtheVKFZlMLCQ5kDKYswxAnMSxST6g5pZU1BkFKZokBVYMjgmyfsoLWef29QONi3k6JZ6+Fd4
GbPlQG4YlTuF9YZ7eTDa6/Xe0CZ2ZZlJA3JjSMjIyGedXoM1jX5xwKjGTQcKpIKq3gyGYYYGGBgx
dE9D1KaDkpN0ZVBQIK0vKyQLFxY6Z1IpvM/zfALou7sLTnrSmBlil/xdyRThQkD2Fk5U
EOF
`"

create_file "inc/main.h" "`cat << EOF
QlpoOTFBWSZTWRB5QQ8ACER/kNiaKeB5f//fP+//4P/v//4EAAgIYAefdehkGjrqgB1WgAAGGopk
AAGgaDagAAAAAAAAAAOBo0Yg0aZMIMQGIxNGjRoA000AAAASkZKaNEyaADEMmjQAAAyBpoYgAAAS
JSQ9TQD1A0YgANAAAAAAAABoOBo0Yg0aZMIMQGIxNGjRoA000AAAASJEyExNDRMkPRPVMjU9TQPF
PTUaaD0mGoNBpjKekzU6/U9fuRbYCOk0B9bCTBtNg0qIgMECSHEilxVnph9f0z2sPeOEZyM4SKzF
IVzPCFLsLld8AjpDt6CbBtNh9kzZ/GcrCWWq0u/ZAl+FXahGbXxkZ9rGnq5tlOuaztqefnZ6NSnP
QTMVhMpGre+BYrQDw2QgSViLKjHB3T0EJHBcuJB6TbZFnTuc69ZBiYt5BENVIj5TVEmOIBEM8heh
FJwtWGOJiJfe0UxTWAB0EjtwcjZ+AVMDEPe1Xna9Jefmbb/DJ0tttdOMD3z+eCGkfA0djA2902l6
mwLDojLtPHuE+n5wMwgNnEYwwUCdlm+c4t6ZRVfRoYrJwDpg51QbEejDA2iTKlWUQmyX4jspYxyL
MwqgKs1RVWQLPRRkhVQyIhz+C/jxNtkqwEQ9yF5D7eykz5mSPHM8so9lx+rGw2V9Z4DVeU7GZkyc
RaksJESTV1hRhQtkfdmWHg6GJsKG8tLi3HprlTT7Cs0Zm81TlI3flPzGhLvZ08a6hgeEDHoHitcI
ovOc1GThJMRYUPHSnfc/O7LolUICd+GGFhQ5dWSQfCNCPKIaiIaQMZWttIKsgoYNjYYwkNJG+y2u
7SH4fXJ6/Z2V9vauzxWn/bYxPCA9IAOxCkm2ZYMzNVIgGyRKOYB6PCyAR30f0J/iVVgUiiQYQNiX
MgGhM9Ov0k0iaPlaXzMIaIfmoLp4zaWCKACkIeUAEpoIHnS0QyRiIpGfGXmMpKElxwWqk1CaCAOy
CDQGQBuCQvfYmwGhAxkw80fkkand5Xm3JchaipqMkt4JEPuOT1aFy6P0iTCCMF1ww3QvOSYQe//h
/X6ok5WTdCR1moL5rgGU6nXgPXb9DO/W1o4p8X6RjQYUcYfbrDBWqhYsBalPRA5BVWjJAsjD9AHU
eg/aE8prvnmPpO0TCmR0LiXThFnW39ySvPeEFomH2AfuAtM/rJC2F2bdovWZmjL74PYEpM3bt7Q0
oUCxBC9oKyk7G5Fx9TBJ7SwnS0X3DJcKsbhLr4Fi0PYWXaCEZC9Qv9GircK+664gLgNYxiFadRrN
gdQbTeKojiDFUW+gjeZr2GZWQtEsGNpCGVBeH1bef2wl/sZQwGtgJs3hPKBQd8GTN4uIi2dXoJ9g
sxM3HIDEXIpb2G8CxhadhU58Rcy++QqAiUmuxgpg1DbBfEZm0TLCAReIrRsY2/abAN5JeIAg0AlS
wjDtNQbtG+hS3eeiXP2QtTTmEiwSpl2LmF9QxttvKmpRNkRf5FKunTu2IcksSyxZbbWc/L5L5/rd
kWWT1lRZneWYoXg5JuQpCKEBrXFKOiUFvUWNwEg1pTyAagCCi4OhUTUIknAwTHZB8Z4vp+AaqF+N
ZOq+ZfvKsU5MY/UYXn4zGIejzugW7bokviXzCKnTLhXmszM05knDSkBL8SAIun65SwdgaVsNxFCU
IW00UCaBZkAiCC22FsBFltp8594l1gjFcqXcAtAW+8Mcam7PqgqkG+bunOALGJ/USZL6ioSSZNoo
cuUDuClxKVwCtojKBCOAaFTnJ6aTsSRPjcOa1a75ZBizzd0U0SK4nkN0cOHUAuoeiZANAd4+iDkW
0Egttsmj+eHckbQ72g2QX6rO3MxxzMO3QaQcjxEkF/UDIJTPbIsbvvkIoMBiXc1AI/G8NqQc2DUN
IK6PNm9e6xIOdBJsBW9Rt46hJNo2m8wBh4Odi+g94vkNIVCR0kLDLjxgWtd1NMXeGAM2bxWcbDQg
2nM4ieIVy2zvStUi8KE8DWEwRwFM3MuoO7gGBqOeh3Nk6jLbtU4k38JBKQI8/xWmVN7SRWoCIYTJ
EISqmptDJPWBI28cJG44GsUzmAi9kYlFU3sjVwLSiJyClx3S6ZUyNKC1B1nAa1J9dnvu3XwDTSfB
rJd2wByDEeJOtJkgy1bJ/wYrysXaGTnMMTVheEzI3O32mtXYkQaGNKAFhUgtkPEJwGhcbCfpFnnJ
a1dGoqmgs70oq4ISZ2Yq4e14xrCSBSkQZSKNcv7SCwuQayJkyBVqgZqwie8sC5ButOvXWpLQEe7I
5ZmwLFnnkSXutkhdxi/OCGrDLuN7dRYcDAvHh4zcu27wHE+EA5IXkMxZC7BKqEB+t35plrICoJf4
u5IpwoSAg8oIeA==
EOF
`"

create_file "inc/gpio.h" "`cat << EOF
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
nEYxoAsZZf8XckU4UJAhUnKx
EOF
`"

create_file "inc/rcc.h" "`cat << EOF
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
eS+8WA==
EOF
`"

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
