#!/bin/bash
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}
sudo apt update && sudo apt upgrade -y && sudo apt install curl vim wget gnupg apt-transport-https lsb-release ca-certificates socat unzip -y
sudo apt autoremove -y
sudo curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
systemctl enable docker
mkdir -p data/docker_data/uptimekuma && cd data/docker_data/uptimekuma && touch docker-compose.yml
cat >> ~/data/docker_data/uptimekuma/docker-compose.yml << EOF
version: '3.3'

services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    volumes:
      - ./uptime-kuma-data:/app/data
    ports:
      - 3001:3001  # <Host Port>:<Container Port>
    restart: always
EOF
docker-compose up -d
mkdir -p ~/data/docker_data/nginxproxymanager && cd ~/data/docker_data/nginxproxymanager && touch docker-compose.yml
cat >> ~/data/docker_data/nginxproxymanager/docker-compose.yml << EOF
version: "3"
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80' 
      - '443:443' 
      - '81:81' 
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
docker-compose up -d
mkdir -p ~/data/docker_data/umami && cd ~/data/docker_data/umami
git clone https://github.com/umami-software/umami.git
cd umami
docker-compose up -d
mkdir -p ~/data/docker_data/halo && cd ~/data/docker_data/halo
read -p "请输入数据库密码:" pwd
green "已输入的密码：$pwd"
read -p "请输入你的域名:" domain
green "已输入的域名：$domain"
read -p "请输入halo用户名:" haloname
green "已输入的用户名：$haloname"
read -p "请输入halo用户名密码:" halopwd
green "已输入的halo用户名密码：$halopwd"
cat >> ~/data/docker_data/halo/docker-compose.yml << EOF
version: "3"

services:
  halo:
    image: halohub/halo:2.4
    container_name: halo
    restart: on-failure:3
    depends_on:
      halodb:
        condition: service_healthy
    networks:
      halo_network:
    volumes:
      - ./:/root/.halo2
    ports:
      - "8090:8090"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090/actuator/health/readiness"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s
    command:
      - --spring.r2dbc.url=r2dbc:pool:mysql://halodb:3306/halo
      - --spring.r2dbc.username=root
      # MySQL 的密码，请保证与下方 MYSQL_ROOT_PASSWORD 的变量值一致。
      - --spring.r2dbc.password=$pwd
      - --spring.sql.init.platform=mysql
      # 外部访问地址，请根据实际需要修改
      - --halo.external-url=$domain
      # 初始化的超级管理员用户名
      - --halo.security.initializer.superadminusername=$haloname
      # 初始化的超级管理员密码
      - --halo.security.initializer.superadminpassword=$halopwd

  halodb:
    image: mysql:8.0.31
    container_name: halodb
    restart: on-failure:3
    networks:
      halo_network:
    command: 
      - --default-authentication-plugin=mysql_native_password
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_general_ci
      - --explicit_defaults_for_timestamp=true
    volumes:
      - ./mysql:/var/lib/mysql
      - ./mysqlBackup:/data/mysqlBackup
    ports:
      - "3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "--silent"]
      interval: 3s
      retries: 5
      start_period: 30s
    environment:
      # 请修改此密码，并对应修改上方 Halo 服务的 SPRING_R2DBC_PASSWORD 变量值
      - MYSQL_ROOT_PASSWORD=$pwd
      - MYSQL_DATABASE=halo

networks:
  halo_network:
EOF
docker-compose up -d
