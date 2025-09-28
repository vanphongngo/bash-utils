#!/bin/bash

sudo apt update;
sudo apt install mariadb-server mariadb-client;
sudo mysql_secure_installation;
sudo systemctl start mariadb;
sudo systemctl enable mariadb;