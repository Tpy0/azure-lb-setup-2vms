#! /bin/bash
sudo apt-get update -y &&
sudo apt-get install -y apache2 &&
sudo systemctl start apache2 &&
sudo systemctl enable apache2 &&
echo "<INSERT YOUR PUBLIC KEY CONTENTS HERE IF YOU WANT TO SSH INTO YOUR BACKEND SERVERS ACROSS THE INTERNET>" | tee /home/alarm/.ssh/id_rsa.pub
chmod 600 /home/alarm/.ssh/id_rsa.pub
echo "Azure Linux VM with Web Server" | sudo tee /var/www/html/index.html
