# QCOM IFC6410 SBC with APQ8064 SoC

Repo for IFC6410 single-board-computer (SBC) and custom kernel compile using Yocto/OpenEmbedded. See .../docs/img-*pins*.png files for pins to be used for fastboot and UART/Serial connection on the board. Most, if not all, kernel versions in the repo are LTS versions.

## UART/Serial connection

Set the following options:

* Configure the serial line:
* Speed (baud): 115200
* Data bits: 8
* Stop bits: 1
* Parity: none
* Flow control: none

## Kernel

Look within the kernel directory for README.md for more details.

## Rootfs Bootstrapping with rsync

To bootstrap a new rootfs mounted at /mnt/rootfs from the currently booted system, use the bootstrap_rootfs.sh script under .../linux/common directory in the current repo.

## Prioritizing LAN over WLAN/WiFi

The WiFi firmware in the repo (latest available) lacks RSN override capability. As a result 802.11n (HT mode) cannot be enabled. WiFi is limited to 54Mbps (802.11g). Prioritizing LAN over WiFi still allows the WiFi to be connected all the time for a fallback (but slower) network.

Use nmcli to set connection priorities

```
# List of connections
# You need to get the connection name (first column)
nmcli c

# Set the `ipv4.route-metric` of each required network
# Change the `$con_name_x` and integer as required
nmcli c mod "$con_name_1" ipv4.route-metric 20  # More preferred connection
nmcli c mod "$con_name_1" ipv6.route-metric 20  # More preferred connection
nmcli c mod "$con_name_2" ipv4.route-metric 40  # Less preferred connection
nmcli c mod "$con_name_2" ipv6.route-metric 40  # Less preferred connection

# Disconnect and reconnect the networks to make the changes effective
nmcli c down "$con_name_1"
nmcli c down "$con_name_2"
nmcli c up "$con_name_1"
nmcli c up "$con_name_2"

# Show connection priorities: example
nmcli -f ipv4.route-metric c show "$con_name_1"

# Check priorities in use: higher is listed on top for each direction
ip r
route -n #alternate command
```

References for WiFi firmware limitation:

* <https://www.spinics.net/lists/ath6kl/msg00111.html>
* <https://www.spinics.net/lists/ath6kl/msg00112.html>
* <https://lists.infradead.org/pipermail/ath6kl/2015-July/000106.html>
* <https://www.spinics.net/lists/ath6kl/msg00091.html>
* <https://www.spinics.net/lists/linux-wireless/msg115085.html>
* <https://www.spinics.net/lists/linux-wireless/msg87931.html>

## Wifi CLI connect

To connect to wifi from commandline, install NetworkManager package and run:

```
nmcli dev wifi connect <mySSID> password <myPassword>
```

## Onboard Ethernet

If ethernet/LAN is unstable, dropping down speed to 100mbps instead of 1000mbps may sometimes help. Install NetworkManager package for nmcli/nmtui utilties. Use following commands to reduce ethernet speed. If you have multiple ethernet adapters, make sure you are picking the correct connection. It's best to use an external USB LAN for stability.

```
nmcli c show
nmcli c edit "Wired connection 1"      # replace with the correct connection
goto ethernet
set auto-negotiate no
set speed 100
set duplex full
back
save persistent
quit
```
## SATA: Hard drive

Onboard SATA controller is known to be buggy. It's best to disable it and use USB HDD. If you do manage to make any SSD/HDD work, disable ncq and force 1.5Gbps negotiation in kernel cmdline "libata.force=1.5Gbps,noncq".

Below are known issues.

### SATA NCQ Errors in dmesg

Could be due to several causes including known offending SSDs like Samsung EVO or aggressive power management being enabled. Disable aggressive power management. Try "medium_power" for /sys/class/scsi_host/host0/link_power_management_policy to resolve the issue. If so, use the udev rule to set it on boot, available in <repo>/linux/common/etc/udev.

```
$ cat /etc/udev/rules.d/10-ssd-power-mode.rules
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="medium_power"

$ cat /sys/class/scsi_host/host0/link_power_management_policy
medium_power
```

NCQ can be disabled with the kernel command line "libata.force=noncq", a version for 6.6.x kernel is available in the repo. Alternatively, use the follow command to limit NCQ queue size to 1 in crontab and increase the timeout to 180sec (related to the problem but independent to NCQ):

```
$ crontab -e
@reboot echo 1 > /sys/block/sda/device/queue_depth
@reboot echo 180 > /sys/block/sda/device/timeout
```

### fsck error checking

Use the following command to automate check after every 5 mounts/reboots. Change /dev/sda1 to the correct partition and -c 5 to tweak the number of mounts/reboots accordingly.

```
partition=/dev/sda1; LC_ALL=C tune2fs -i 3600s -c 5 $partition 2>&1 | grep Setting
```

### SATA Throughput

USB ports don't appear to share bandwidth as USB LAN adapter gets the same speed regardless of SSD being connected through USB or now.

```
$ iperf3 -Rc pve.local
Connecting to host 10.100.100.50, port 5201
Reverse mode, remote host 10.100.100.50 is sending
[  5] local 10.100.100.64 port 57984 connected to 10.100.100.50 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  24.2 MBytes   203 Mbits/sec                  
[  5]   1.00-2.00   sec  24.4 MBytes   205 Mbits/sec                  
[  5]   2.00-3.00   sec  24.2 MBytes   203 Mbits/sec                  
[  5]   3.00-4.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   4.00-5.00   sec  24.0 MBytes   201 Mbits/sec                  
[  5]   5.00-6.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   6.00-7.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   7.00-8.00   sec  24.3 MBytes   204 Mbits/sec                  
[  5]   8.00-9.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   9.00-10.00  sec  24.2 MBytes   203 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.01  sec   243 MBytes   204 Mbits/sec    0             sender
[  5]   0.00-10.00  sec   242 MBytes   203 Mbits/sec                  receiver
```

#### USB-SATA Adapter

```
$ hdparm -Tt /dev/sda
/dev/sda: USB to SATA adapter
 Timing cached reads:   674 MB in  2.00 seconds = 337.48 MB/sec
 Timing buffered disk reads:  66 MB in  3.05 seconds =  21.63 MB/sec
```

#### SATA Native

```
$ hdparm -Tt /dev/sda
/dev/sda: SATA
 Timing cached reads:   720 MB in  2.00 seconds = 359.76 MB/sec
 Timing buffered disk reads: 326 MB in  3.00 seconds = 108.60 MB/sec
```

## Disabling Onboard Ethernet and SATA

Recommend using USB versions for both functionality due to the various known issues for onboard versions. If you don't use onboard versions, you can disable them both with this service:

```
# LAN/SATA disable service: /etc/systemd/system/disable-onboard-eth-sata.service

[Unit]
Description=Disable unstable onboard SATA and atl1c Ethernet controllers as both are buggy by nature
DefaultDependencies=no
After=systemd-udev-settle.service
Before=sysinit.target shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c '\
  if [ -d /sys/bus/platform/drivers/ahci/29000000.sata ]; then \
    echo -n "29000000.sata" > /sys/bus/platform/drivers/ahci/unbind 2>/dev/null || true; \
    echo "auto" > /sys/devices/platform/soc/29000000.sata/power/control 2>/dev/null || true; \
  fi; \
  if [ -d /sys/bus/pci/drivers/atl1c/0000:01:00.0 ]; then \
    /sbin/ip link set dev enp1s0 down 2>/dev/null || true; \
    echo -n "0000:01:00.0" > /sys/bus/pci/drivers/atl1c/unbind 2>/dev/null || true; \
  fi; \
  if [ -d /sys/bus/pci/devices/0000:01:00.0 ]; then \
    echo -n 1 > /sys/bus/pci/devices/0000:01:00.0/remove 2>/dev/null || true; \
  fi'

[Install]
WantedBy=basic.target
```

Enable/activate the service:
```
sudo systemctl daemon-reload
sudo systemctl enable --now disable-onboard-eth-sata.service
```

## GPIO

* 90 GPIO pins (GPIO_0 to GPIO_89)
* Configurable pull-up/down
* Configurable output drive current
* Interruptable GPIOs
* GPIO manipulation
* GPIO manipulation is done through the standard gpiolib

Additional useful links:

* <http://elinux.org/GPIO>
* <https://developer.ridgerun.com/wiki/index.php/Gpio-int-test.c>
* <https://developer.ridgerun.com/wiki/index.php/How_to_use_GPIO_signals>
* <http://mondi.web.cs.unibo.it/gpio_control.html>

### PinMux configuration

In older kernels, GPIO mux configuration is done in kernel/arch/arm/mach-msm/board-8064-gpiomux.c At apq8064_init_gpiomux(void) there are several examples of pinmux configuration (example struct apq8064_gsbi2_UART2_configs configures GPIO pins 22,23,24 and 25 to serial port).

### Generic serial bus interface (GSBI)

The APQ8064 implements 12 Generic Serial Bus Interface (GSBI) ports. GSBI ports can be configured for:

* UART_DM
* I2C
* SPI
* General-purpose I/O (GPIO) bits

## Docker bridge/iptables error

If you see an error similar to this:

```
docker failed to register "bridge" driver: failed to add jump rules to ipv4 NAT tables
```

Run these these commands to switch from iptables-nft to iptables-legacy that docker wants and restart:

```
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

## Power and GPIO Pin Layout, SATA 5V power

Some images from following websites are in <current_repo>/doc directory (Power/GPIO/SATA).

## Links/References related to IFC6410/APQ8064/QS600 SBC

* <https://wiki.archlinux.org/title/Solid_state_drive#Resolving_NCQ_Errors> (SATA NCQ errors)
* <https://wiki.archlinux.org/title/Power_management#SATA_Active_Link_Power_Management>
* <https://awilby.gitbooks.io/cse-190-robotics/content/8_1_gpio.html>
* <https://www.hackster.io/inforce-ifc6410/projects>
* <https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus>
* <https://github.com/96boards/documentation/wiki/Dragonboard-Boot-Image>
* <https://releases.linaro.org/debian/boards/snapdragon/16.02/>
* <https://github.com/apq8064-mainline/linux>
* <http://pragmatux.com/docs/quick-start-ifc6410.html>
* <https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus>
* <https://www.spinics.net/lists/devicetree/msg473167.html>
* <https://www.compulab.com/products/computer-on-modules/cm-qs600/#devres>
* <https://www.compulab.com/products/sbcs/sbc-qs600/#devres>
* <https://www.compulab.com/cm-qs600-software-archive/>
* <https://mediawiki.compulab.com/w/index.php?title=CM-QS600_Qualcomm_Snapdragon_600_APQ8064_SW_Resources>
* <https://github.com/compulab/cm-qs600-kernel>
* <https://www.compulab.com/wp-content/uploads/2014/05/CM-QS600-Press-Release.pdf>
* <https://github.com/compulab/cm-qs600-android-device>
* <https://variwiki.com/index.php?title=VAR-SOM-SD600>
* <https://www.variscite.com/product/system-on-module-som/cortex-a53-krait/var-som-sd600-cpu-qualcomm-snapdragon600/#documentation>
* <https://variwiki.com/index.php?title=VAR-SOM-SD600_gpio>
* <https://github.com/compulab/eeprom-util>
* <https://mediawiki.compulab.com/w/index.php?title=Android:_Boot_image>
* <https://patchwork.ozlabs.org/project/openwrt/patch/1423622295-17130-1-git-send-email-mathieu@codeaurora.org/> (kpcc acc v1)
* <https://mediawiki.compulab.com/w/index.php?title=CM-QS600:_Linux:_Debian> (bluetooth, devices etc. config)
  
