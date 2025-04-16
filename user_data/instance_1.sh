#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
echo "Welcome to the Homepage" > /usr/share/nginx/html/index.html