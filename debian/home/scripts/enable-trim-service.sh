#!/bin/sh
sudo cp /usr/share/doc/util-linux/examples/fstrim.service /etc/systemd/system
sudo cp /usr/share/doc/util-linux/examples/fstrim.timer /etc/systemd/system
sudo systemctl enable fstrim.timer

