## Kernel 6.6

This kernel is fully self-sufficient with all onboard peripheral drivers and firmware built-in, including PCI-e Ethernet (atl1c), 802.11 stack, Wifi (ath6k), BT (ath3k) and USB Realtek Ethernet (r8150/1/2/3).

This kernel is "dirty" as it uses a custom ifc6410 dtsi file with the following changes:

1) Lowered voltages for cpu
2) New regulators added for "tabla" (but audio still won't work) and HPLL for armv7a boards
3) 3.3v fixed voltage property fix

The custom dtsi file will get replaced when yocto git pull and/or resync of kernel source is performed and must be replaced just before the step of compiling kernel. An accompanying kernel patch file is provided with the changes for such cases.
