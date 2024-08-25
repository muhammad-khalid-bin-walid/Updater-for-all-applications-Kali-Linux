 #!/bin/bash                                                               

sudo apt update
sudo apt upgrade -y
sudo apt full-upgrade -y
pip install --upgrade $(pip list --outdated | tail -n +3 | awk '{print $1}')
sudo apt autoremove -y
sudo apt clean

