# Disable NCQ

NCQ has been known to cause issues with IFC6410. There are multiple ways to disable it: kernel commandline, udev rules and crontab. Crontab is a an easy way to disable NCQ.

```
crontab -e
```

Add the following line:

```
@reboot echo 1 > /sys/block/sda/device/queue_depth
```

Reboot SBC for the commands to take effect.
