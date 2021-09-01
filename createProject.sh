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

function addRepo() {
	subrepo=$1
	folder=$2
	git submodule add $REPRO/${PREFIX}${subrepo} ${folder}
	checkError
}

REPRO=https://github.com/FreeRTOSHAL/
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

if [ -e driver -o -e arch -o -e mach -o -e scripts -o -e freertos ]; then
	echo "folder must be empty!"
	exit 1
fi

if [ ! -e .git ]; then
	git init
	checkError
fi
git submodule init
checkError
addRepo driver driver
addRepo arch arch
addRepo mach mach
addRepo buildsystem scripts
addRepo kernel freertos

git submodule foreach git checkout $BRANCH
checkError

git submodule foreach git submodule update --init
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

echo << EOF > src/Kconfig
menu "Application Config"
config APP_INCLUDE
	string
	default "-Iinclude"
choice
	prompt "stdout UART"
	depends on UART
	config USE_SEMIHOSTING_AS_STDOUT
		bool "Semihosting UART"
		depends on SEMIHOSTING_UART
	config USE_SBI_AS_STDOUT
		bool "SBI UART"
		depends on ARCH_SBI
	#config USE_UART0_AS_STDOUT
	#	bool "Uart 0"
	#	depends on ...
endchoice
endmenu
EOF

cat << EOF > src/Makefile
obj-y = ${1}.o
EOF

cat << EOF > src/${1}.c
#include <stdio.h>
#include <stdint.h>

#include <FreeRTOS.h>
#include <task.h>
#ifndef CONFIG_ARCH_X86_LINUX
/* Include Unique Dev Names */
# include <devs.h>
#endif
#include <uart.h>
#include <newlib_stub.h>
#ifdef CONFIG_USE_SEMIHOSTING_AS_STDOUT
# include <semihosting.h>
#endif
#ifdef CONFIG_USE_SBI_AS_STDOUT
# include <sbi_uart.h>
#endif

int main() {
	int32_t ret;
#ifdef CONFIG_UART
# if defined(CONFIG_USE_SEMIHOSTING_AS_STDOUT)
	struct uart *uart = uart_init(SEMIHOSTING_UART_ID, 115200);
# elif defined(CONFIG_USE_SBI_AS_STDOUT)
	struct uart *uart = uart_init(SBI_UART_ID, 115200);
# elif defined(USE_UART0_AS_STDOUT)
	//struct uart *uart = uart_init(PUT_CORRECT_UART_HEAR_ID, 115200);
# else
#  error "uart for this mach not implement"
# endif
	CONFIG_ASSERT(uart != NULL);
# ifdef CONFIG_NEWLIB_UART
	ret = newlib_init(uart, uart);
	CONFIG_ASSERT(ret == 0);
# endif
# ifdef CONFIG_NLIBC_PRINTF
	ret = nlibc_init(uart, uart);
	CONFIG_ASSERT(ret == 0);
# endif
#endif
	printf("Start Scheduler\n");
	vTaskStartScheduler();
	for(;;);
	return 0;
}
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

# Copy default configs
cp scripts/configs/* configs/

git add arch/ mach/ freertos/ driver/ scripts/ Kconfig Makefile src/${1}.c src/Kconfig src/Makefile configs/* .gitignore

make x86_defconfig


echo ""

echo "You can now use the buildsystem"
echo ""
echo "Call make to build the System for x86"
echo "or call make <config name>_defconfig to change the system"
echo ""
echo "Following configs are available:"
pushd configs &> /dev/null
ls *_defconfig
popd configs &> /dev/null
