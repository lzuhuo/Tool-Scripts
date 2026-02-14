#Atualização de Pacotes
sudo apt update
sudo apt upgrade -y

#Instalação de Programas via terminal
sudo apt install tilix flameshot git curl gnome-tweaks chrome-gnome-shell inetutils-*  -y
sudo apt install flatpak -y
sudo apt install gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#Download de Programas
mkdir programas
cd programas
wget https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb
wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.15.1-Linux-x64.deb
wget https://download.microsoft.com/download/6b2bfeac-9c1b-4182-9a2f-ce86ff8cc371/azuredatastudio-linux-1.52.0.deb
wget https://desktop.wifiman.com/wifiman-desktop-1.2.8-amd64.deb

#Instalação de Programas baixados e reparos de instalação
sudo dpkg -i *.deb
sudo apt install -fy
cd ..

#Instalação de aplicativos Flatpak
flatpak install flathub com.mattjakeman.ExtensionManager
flatpak install flathub com.getpostman.Postman
flatpak install flathub com.mikrotik.WinBox
flatpak install flathub org.keepassxc.KeePassXC
flatpak install flathub us.zoom.Zoom
flatpak install flathub com.google.Chrome
flatpak install flathub org.freedownloadmanager.Manager
flatpak install flathub com.microsoft.Edge
flatpak install flathub io.dbeaver.DBeaverCommunity
flatpak install flathub com.anydesk.Anydesk
flatpak install flathub org.ferdium.Ferdium
flatpak install flathub com.visualstudio.code

sudo rm -r programas
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
