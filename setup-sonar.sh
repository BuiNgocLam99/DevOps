#!/bin/bash 
sudo apt update -y
sudo apt install unzip openjdk-11-jdk -y

# Install PostgreSql
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt update -y
sudo apt install postgresql postgresql-contrib -y

sudo -u postgres psql
postgres=# CREATE ROLE sonaruser WITH LOGIN ENCRYPTED PASSWORD 'admin123';
postgres=# CREATE DATABASE sonarqube;
postgres=# GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonaruser;
postgres=# \q
exit

sudo systemctl enable postgresql.service
sudo systemctl start  postgresql.service

sudo echo "postgres:admin123" | chpasswd
sudo runuser -l postgres -c "createuser sonar"
sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"

sudo systemctl restart  postgresql

# Install Sonarqube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.6.1.59531.zip
unzip -q sonarqube-9.6.1.59531.zip
sudo mv sonarqube-9.6.1.59531 /opt/sonarqube
rm sonarqube-9.6.1.59531.zip

sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube/ -R
sudo cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
sudo bash -c 'cat <<EOT> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT'

sudo adduser --system --no-create-home --group --disabled-login sonarqube
sudo chown sonarqube:sonarqube /opt/sonarqube -R
sudo chmod -R 755 /opt/sonarqube

sudo sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=sonaruser/' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=admin123/' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube?currentSchema=my_schema|sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube|' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's/#sonar.web.javaAdditionalOpts=-server/sonar.web.javaAdditionalOpts=-server/' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's/#sonar.web.host=0.0.0.0/sonar.web.host=127.0.0.1/' /opt/sonarqube/conf/sonar.properties

sudo bash -c 'cat <<EOT>> /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
EOT'

sudo bash -c 'cat <<EOT> /etc/security/limits.d/99-sonarqube.conf
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOT'

sudo bash -c 'cat <<EOT> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonarqube
Group=sonarqube
PermissionsStartOnly=true
Restart=always

StandardOutput=syslog
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOT'

sudo mkdir -p /opt/sonarqube/logs
sudo chown sonarqube:sonarqube /opt/sonarqube/logs
sudo chmod 755 /opt/sonarqube/logs
sudo chown -R sonarqube:sonarqube /opt/sonarqube
sudo chmod -R 755 /opt/sonarqube

sudo systemctl daemon-reload
sudo systemctl start sonarqube.service
sudo systemctl enable sonarqube

# Install Nginx
sudo apt install nginx -y
sudo rm -rf /etc/nginx/sites-enabled/default
sudo rm -rf /etc/nginx/sites-available/default
sudo bash -c 'cat <<EOT> /etc/nginx/sites-available/sonarqube
server{
    listen      80;
    server_name sonarqube.groophy.in;

    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
              
        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT'

ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube

sudo systemctl restart nginx.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

sudo ufw allow 80/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 9001/tcp
sudo ufw allow 22/tcp

echo "System reboot in 30 sec"
sleep 30
reboot
