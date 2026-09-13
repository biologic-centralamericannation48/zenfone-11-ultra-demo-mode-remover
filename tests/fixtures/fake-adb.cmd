@echo off
if "%1"=="devices" (
  echo List of devices attached
  echo FAKE123 device
  exit /b 0
)

if "%1"=="-s" (
  shift
  shift
)

if "%1"=="reboot" exit /b 0
if "%1"=="shell" shift

if "%1"=="getprop" if "%2"=="ro.product.model" (
  echo ASUS_AI2401_H
  exit /b 0
)
if "%1"=="getprop" if "%2"=="ro.product.device" (
  echo ASUS_AI2401
  exit /b 0
)
if "%1"=="getprop" if "%2"=="ro.boot.product.hardware.sku" (
  echo WW
  exit /b 0
)
if "%1"=="settings" if "%2"=="get" if "%3"=="global" if "%4"=="device_demo_mode" (
  echo 0
  exit /b 0
)
if "%1"=="settings" if "%2"=="get" if "%3"=="global" if "%4"=="retail_demo_mode" (
  echo 0
  exit /b 0
)
if "%1"=="settings" if "%2"=="put" exit /b 0
if "%1"=="dpm" if "%2"=="list-owners" (
  echo no owners
  exit /b 0
)
if "%1"=="ls" if "%3"=="/dev/block/by-name/ADF" (
  echo lrwxrwxrwx ADF -^> /dev/block/sda12
  exit /b 0
)
if "%1"=="pm" if "%2"=="list" if "%3"=="packages" if "%4"=="com.asus.dm" (
  echo package:com.asus.dm
  exit /b 0
)

echo Unsupported fake adb arguments: %* 1>&2
exit /b 2
