@echo off
if "%1"=="devices" (
  echo FAKE123 fastboot
  exit /b 0
)

if "%1"=="-s" (
  shift
  shift
)

if "%1"=="getvar" if "%2"=="is-userspace" (
  echo is-userspace: no
  exit /b 0
)
if "%1"=="getvar" if "%2"=="product" (
  echo product: pineapple
  exit /b 0
)
if "%1"=="getvar" if "%2"=="partition-type:ADF" (
  echo partition-type:ADF: ext4
  exit /b 0
)
if "%1"=="getvar" if "%2"=="partition-size:ADF" (
  echo partition-size:ADF: 0x2000000
  exit /b 0
)
if "%1"=="erase" if "%2"=="ADF" (
  echo Erasing 'ADF' OKAY
  exit /b 0
)
if "%1"=="reboot" exit /b 0

echo Unsupported fake fastboot arguments: %* 1>&2
exit /b 2
