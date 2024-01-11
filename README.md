# ADS-SQL-2008-R2

wget https://www.openssl.org/source/openssl-1.1.1h.tar.gz
tar -zxfv openssl-1.1.1h.tar.gz
cd openssl-1.1.1h
./config

# install dependencies if you not did before
sudo apt-get install make gcc
sudo make install

#create symlink to new openssl (if already exists delete it)
sudo ln -s /usr/local/bin/openssl /usr/bin/openssl 

# update symlinks
sudo ldconfig

# run verification
openssl version

sed -i 's/DEFAULT@SECLEVEL=2/DEFAULT@SECLEVEL=1/g' /etc/ssl/openssl.cnf

