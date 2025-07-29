#Atualização de Pacotes
sudo apt update
sudo apt upgrade -y

#Instalação de Programas via terminal
sudo apt install tilix flameshot git curl gnome-tweaks wireshark chrome-gnome-shell thunderbird inetutils-*  -y
sudo apt install flatpak -y
sudo apt install gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#Download de Programas
mkdir programas
cd programas
wget https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb
wget https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb
wget http://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_122.0.2365.63-1_amd64.deb
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
wget https://cdn.zoom.us/prod/6.5.7.3298/zoom_amd64.deb
wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/c306e94f98122556ca081f527b466015e1bc37b0/code_1.102.2-1753187809_amd64.deb
wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
wget https://download.anydesk.com/linux/anydesk_7.0.0-1_amd64.deb
wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.13.1-Linux-x64.deb
wget https://github.com/ferdium/ferdium-app/releases/download/v7.1.0/Ferdium-linux-7.1.0-amd64.deb
wget https://github.com/Ulauncher/Ulauncher/releases/download/5.15.7/ulauncher_5.15.7_all.deb

#Instalação de Programas baixados e reparos de instalação
sudo dpkg -i *.deb
sudo apt install -fy
cd ..

#Instalação de aplicativos Flatpak
flatpak run com.mattjakeman.ExtensionManager
flatpak install flathub com.mattjakeman.ExtensionManager
flatpak run com.mattjakeman.ExtensionManager

sudo rm -r programas
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
