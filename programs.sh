#Atualização de Pacotes
sudo apt update
sudo apt upgrade -y

#Instalação de Programas via terminal
sudo apt install tilix flameshot gnome-tweaks wireshark chrome-gnome-shell thunderbird inetutils-*  -y

#Instalação do Winbox
git clone https://github.com/lzuhuo/winbox-installer.git
cd winbox-installer
sudo bash winbox-setup install
cd ..

#Download de Programas
mkdir programas
cd programas
wget https://www.microsip.org/download/MicroSIP-Lite-3.21.4.exe
wget https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb
wget https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_128.0.2739.79-1_amd64.deb
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
wget https://zoom.us/client/6.1.11.1545/zoom_amd64.deb
wget https://download.microsoft.com/download/7/8/3/783c2037-8607-43c4-a593-0936e965d38b/azuredatastudio-linux-1.49.1.deb
wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/38c31bc77e0dd6ae88a4e9cc93428cc27a56ba40/code_1.93.1-1726079302_amd64.deb
wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
wget https://download.anydesk.com/linux/anydesk_6.3.2-1_amd64.deb
wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.12.1-Linux-x64.deb
wget https://github.com/ferdium/ferdium-app/releases/download/v6.7.6/Ferdium-linux-6.7.6-amd64.deb

#Instalação de Programas baixados e reparos de instalação
sudo dpkg -i *.deb
sudo apt install -fy
wine *.exe
cd ..

#Instalação de aplicativos Snap
snap install postman

sudo rm -r programas
sudo rm -r winbox-installer

sudo apt autoremove -y
