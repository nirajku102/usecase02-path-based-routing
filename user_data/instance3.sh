#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
mkdir -p /usr/share/nginx/html/register
echo "Welcome to the Register Page" > /usr/share/nginx/html/register/index.html