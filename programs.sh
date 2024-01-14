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
wget https://www.microsip.org/download/MicroSIP-Lite-3.21.3.exe
wget https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb
wget https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_120.0.2210.133-1_amd64.deb
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
wget https://cdn.zoom.us/prod/5.17.1.1840/zoom_amd64.deb
wget https://sqlopsbuilds.azureedge.net/stable/b6f7beb01f92adaa4b79b6b6f3ac704e95cafe6e/azuredatastudio-linux-1.47.1.deb
wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/0ee08df0cf4527e40edc9aa28f4b5bd38bbff2b2/code_1.85.1-1702462158_amd64.deb
wget https://download.dbeaver.com/community/23.3.2/dbeaver-ce_23.3.2_amd64.deb
wget https://download.anydesk.com/linux/anydesk_6.3.0-1_amd64.deb
wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.9.0-Linux-x64.deb
wget https://github.com/ferdium/ferdium-app/releases/download/v6.7.0/Ferdium-linux-6.7.0-amd64.deb

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