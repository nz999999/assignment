#!/bin/bash
dpkg --configure -a
apt-get -y update

# install Apache2
apt-get -y install apache2

# modify permission
chmod o+w /var/www/html/index.html

# update html
echo \<center\>\<h1\>Hello Plexure\!\</h1\>\<br/\>\</center\> > /var/www/html/index.html

# roll back permission
chmod o-w /var/www/html/index.html

# restart Apache
apachectl restart