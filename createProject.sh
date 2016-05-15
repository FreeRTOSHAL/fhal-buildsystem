#!/bin/bash

function syntax() {
	echo "$0 <projektname> [<branchname / tagname>] [<repo>]"
}

function checkError() {
	if [ $? != 0 ]; then
		echo "Error while execution"
		exit 1
	fi
}

REPRO=git@scuderia.cs.hs-rm.de:fhal
PREFIX=fhal-
BRANCH=master

if [ -z "$1" ]; then
	syntax
	exit 1
fi

if [ "$1" == "--help" -o "$1" == "-?" -o "$1" == "-h" ]; then
	syntax
	exit 1
fi

if [ ! -z "$2" ]; then
	BRANCH=$2
fi
 
if [ ! -z "$3" ]; then
	REPRO=$3
fi

git init
checkError
git submodule init
checkError
#mkdir driver mach arch scripts src include
git submodule add $REPRO/${PREFIX}driver driver
checkError
git submodule add $REPRO/${PREFIX}arch arch
checkError
git submodule add $REPRO/${PREFIX}mach mach
checkError
git submodule add $REPRO/${PREFIX}buildsystem scripts
checkError
git submodule add $REPRO/${PREFIX}kernel freertos
checkError

git submodule foreach git checkout $BRANCH
checkError

mkdir src include configs

cat << EOF > Makefile
PROJECT_NAME    := $1
objs-y		:= src arch mach driver freertos
#libs-y          := libs

include scripts/Makefile.project
EOF

cat << EOF > Kconfig
#
# For a description of the syntax of this configuration file,
# see Documentation/kbuild/kconfig-language.txt.
#
mainmenu "FreeRTOS Configuration"
source scripts/Kconfig.projekt
source src/Kconfig
EOF

echo "" > src/Kconfig

cat << EOF > src/Makefile
obj-y = ${1}.o
EOF

cat << EOF > src/${1}.c
#include <stdio.h>
#include <stdint.h>

#include <FreeRTOS.h>
#include <task.h>
/* Include Unique Dev Names */
#include <devs.h>
#include <uart.h>
#include <newlib_stub.h>

int main() {
	int32_t ret;
	struct uart *uart = uart_init(LPUART1_ID, 115200);
	CONFIG_ASSERT(uart != NULL);
	ret = newlib_init(uart, uart);
	CONFIG_ASSERT(ret == 0);
	printf("Start Scheduler\n");
	vTaskStartScheduler ();
	for(;;);
	return 0;
}
EOF
cat << EOF > .config
CONFIG_ARCH_ARM=y
CONFIG_CPU_CLOCK_BY_INTERFACE=y
CONFIG_ARCH_ARM_CORTEX_M4F=y

CONFIG_MACH_VF610=y
CONFIG_VF610_UART=y
CONFIG_VF610_LPUART=y
CONFIG_VF610_LPUART01=y
CONFIG_BUFFER_UART=y
CONFIG_BUFFER_UART_WAIT_TO_TX=y
CONFIG_BUFFER_UART_MAX_TRYS=50
CONFIG_VF610_BUFFER=y
CONFIG_VF610_BUFFER_1=y

CONFIG_UART=y
CONFIG_UART_MULTI=y

CONFIG_NEWLIB=y
CONFIG_NEWLIB_UART=y
CONFIG_NEWLIB_UART_NEWLINE=y
CONFIG_NEWLIB_MALLOC=y
CONFIG_NEWLIB_MALLOC_THREAD_SAFE=y
CONFIG_MALLOC_3=y

CONFIG_BUFFER=y

CONFIG_HEAP_3=y
CONFIG_CROSS_COMPILE="arm-none-eabi-"
EOF
cat << EOF > .gitignore
**.cmd
**.o
**.a
.config*
**linux
include/config
include/generated
$1
${1}.bin
EOF

cat << EOF > configs/README.md

"This folder shall contais configs for build mutilbile targets

all configs shall the postfix _defconfig

call this command to init config: 

make <config_name>_defconfig
EOF

git add arch/ mach/ freertos/ driver/ scripts/ Kconfig Makefile src/${1}.c src/Kconfig src/Makefile configs/README.md .gitignore
make olddefconfig


echo ""

echo "You can now use the buildsystem"

echo "Call make to build the System"
