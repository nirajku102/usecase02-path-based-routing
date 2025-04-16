#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
mkdir -p /usr/share/nginx/html/images
echo "Welcome to the Images Page" > /usr/share/nginx/html/images/index.html