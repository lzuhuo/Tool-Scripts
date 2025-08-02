#Atualização de Pacotes
sudo pacman -Syu

#Instalação de Programas via terminal
sudo pacman -S flameshot gnome-tweaks gnome-browser-connector firefox inetutils

#Instalação de Programas para Openvpn
sudo pacman -S openvpn networkmanager-openvpn network-manager-applet

#Instalação do ame - Amethyst
sudo pacman -S --needed base-devel pacman-contrib cargo
git clone https://gitlab.com/crystal-linux/pkgbuilds/ame.git
cd ame
makepkg -si
cd ..

#Download de Programas Padrão
ame -S google-chrome microsoft-edge-stable-bin zoom --noconfirm

#Download de Programas Desenv
ame -S visual-studio-code-bin azuredatastudio-bin dbeaver-ce-bin postman-bin --noconfirm

#Download de Programas Infra
ame -S realvnc-vnc-viewer ferdium-bin winbox inetutils extension-manager keepassxc --noconfirm

#Download de Programas Utilitarios
ame -S wine-mono microsip realvnc-vnc-viewer gtkglext anydesk-bin ulauncher --noconfirm
