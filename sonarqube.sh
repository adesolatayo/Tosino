#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

###############################################
# Step 1: Update system packages
###############################################
sudo apt-get update -y

###############################################
# Step 2a: Install Java 11
###############################################
sudo apt-get install -y openjdk-11-jdk wget nano tree unzip git-all

###############################################
# Step 2b: Install and setup PostgreSQL
###############################################
# Add PostgreSQL repository and install PostgreSQL
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql

# Set password for postgres user and configure PostgreSQL
echo "Setting up PostgreSQL..."
sudo passwd postgres
sudo echo "postgres ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/postgres
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'admin';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl status postgresql

###############################################
# Step 3: Install net-tools
###############################################
sudo apt install -y net-tools

###############################################
# Step 4: Update sysctl.conf
###############################################
sudo cp /etc/sysctl.conf /root/sysctl.conf_backup
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | sudo tee -a /etc/sysctl.conf
echo "ulimit -n 131072" | sudo tee -a /etc/sysctl.conf
echo "ulimit -u 8192" | sudo tee -a /etc/sysctl.conf

###############################################
# Step 5: Update limits.conf
###############################################
sudo cp /etc/security/limits.conf /root/sec_limit.conf_backup
echo "sonarqube   -   nofile   131072" | sudo tee -a /etc/security/limits.conf
echo "sonarqube   -   nproc    8192" | sudo tee -a /etc/security/limits.conf

###############################################
# Step 6: Install SonarQube
###############################################
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.6.0.59041.zip
sudo unzip sonarqube-9.6.0.59041.zip
sudo rm -rf sonarqube-9.6.0.59041.zip
sudo mv sonarqube-9.6.0.59041 sonarqube

###############################################
# Step 7: Create SonarQube user and group
###############################################
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar

###############################################
# Step 8: Update sonar.properties
###############################################
sudo cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
sudo bash -c 'cat << EOF >> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError
EOF'

###############################################
# Step 9: Create SonarQube systemd service file
###############################################
sudo bash -c 'cat << EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
User=sonar
Group=sonar
PermissionsStartOnly=true
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
StandardOutput=syslog
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

###############################################
# Step 10: Set permissions and ownership
###############################################
sudo useradd -d /opt/sonarqube sonar
sudo chown -R sonar:sonar /opt/sonarqube

###############################################
# Step 11: Reload systemd and start SonarQube service
###############################################
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

###############################################
# Step 12: Reboot system to apply all changes
###############################################
sudo reboot

# Instructions to the user after reboot
echo "SonarQube installation complete. Please ensure that port 9000 is open in your security group settings."
echo "After reboot, access SonarQube at http://<your-ec2-instance-ip>:9000"

