#!/bin/bash 
sudo apt update -y

sudo useradd -M -d /opt/nexus -s /bin/bash -r nexus

sudo apt install openjdk-8-jre-headless -y

cd /opt

sudo wget https://download.sonatype.com/nexus/3/nexus-3.38.1-01-unix.tar.gz

sudo tar -zxvf nexus-3.38.1-01-unix.tar.gz
sudo mv /opt/nexus-3.38.1-01 /opt/nexus

sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

sudo sed -i 's/^#run_as_user=".*"/run_as_user="nexus"/' /opt/nexus/bin/nexus.rc

sudo mkdir -p /etc/nexus/bin
sudo bash -c 'printf "%s\n%s\n%s\n" "-Xms1024m" "-Xmx1024m" "-XX:MaxDirectMemorySize=1024m" >/etc/nexus/bin/nexus.vmoptions'

sudo bash -c 'printf "[Unit]\nDescription=nexus service\nAfter=network.target\n[Service]\nType=forking\nLimitNOFILE=65536\nExecStart=/opt/nexus/bin/nexus start\nExecStop=/opt/nexus/bin/nexus stop\nUser=nexus\nRestart=on-abort\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/nexus.service'

sudo systemctl start nexus
sudo systemctl enable nexus
