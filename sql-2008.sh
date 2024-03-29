sed -i 's/DEFAULT@SECLEVEL=2/DEFAULT@SECLEVEL=1/g' /etc/ssl/openssl.cnf

wget https://www.openssl.org/source/openssl-1.1.1h.tar.gz

tar -zxf openssl-1.1.1h.tar.gz

cd openssl-1.1.1h

./config

sudo apt-get install make gcc

sudo make install

sudo ln -s /usr/local/bin/openssl /usr/bin/openssl

sudo ldconfig

openssl version