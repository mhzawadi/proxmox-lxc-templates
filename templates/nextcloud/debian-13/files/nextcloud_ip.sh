#!/bin/sh

sed -i  "s/##HOSTIP##/$(hostname -I | awk '{print $1}')/g" /var/www/html/config/config.php
