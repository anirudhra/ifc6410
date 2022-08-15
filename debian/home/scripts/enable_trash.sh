#!/bin/sh
sudo apt-get install trash-cli
mkdir --parents $HOME/.local/share/file-manager/actions
wget -O $HOME/.local/share/file-manager/actions/ask-trash-empty.desktop https://raw.githubusercontent.com/NicolasBernaerts/ubuntu-scripts/master/lubuntu/trash-empty/ask-trash-empty.desktop
sudo wget -O /usr/local/bin/ask-trash-empty https://raw.githubusercontent.com/NicolasBernaerts/ubuntu-scripts/master/lubuntu/trash-empty/ask-trash-empty.desktop
sudo chmod a+x /usr/local/bin/ask-trash-empty

