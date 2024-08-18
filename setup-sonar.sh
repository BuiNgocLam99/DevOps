#!/bin/bash 
# Cần sửa lại mới chạy được .sh
# Script này chỉ chạy thủ công

sudo apt install default-jdk
java -version
wget -q https://www.postgresql.org/media/keys... -O - | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main"  /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install postgresql-13
sudo systemctl is-enabled postgresql
sudo systemctl status postgresql
sudo -u postgres psql
CREATE USER sonarqube WITH PASSWORD 'Password';
CREATE DATABASE sonarqube OWNER sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
\l
\du
\q
sudo useradd -b /opt/sonarqube -s /bin/bash sonarqube
sudo nano /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
sudo sysctl --system
ulimit -n 131072
ulimit -u 8192
sudo nano /etc/security/limits.d/99-sonarqube.conf
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
sudo apt install unzip software-properties-common wget
wget https://binaries.sonarsource.com/Dist...
unzip sonarqube-9.6.1.59531.zip
mv sonarqube-9.6.1.59531 /opt/sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube
nano /opt/sonarqube/conf/sonar.properties
sudo nano /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
sudo systemctl daemon-reload
sudo systemctl start sonarqube.service
sudo systemctl enable sonarqube.service
sudo systemctl status sonarqube.service
sudo apt install nginx
sudo systemctl is-enabled nginx
sudo systemctl status nginx
sudo nano /etc/nginx/sites-available/sonarqube.conf

server {

    listen 80;
    server_name sonar.hwdomain.io;
    access_log /var/log/nginx/sonar.access.log;
    error_log /var/log/nginx/sonar.error.log;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}

sudo ln -s /etc/nginx/sites-available/sonarqube.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
