echo 'Edit Mirror List'
echo 'And uncomment lines abouve'
echo '#[multilib]'
echo '#Include = /etc/pacman.d/mirrorlist'

#Edit Mirror List
sudo nano /etc/pacman.conf
#Uncomment lines above without #
#[multilib]
#Include = /etc/pacman.d/mirrorlist

#Atualização de Pacotes
sudo pacman -Syu

#Instalação de Programas via terminal
sudo pacman -S tilix flameshot gnome-tweaks gnome-browser-connector firefox inetutils

#Download de Programas Padrão
ame -S google-chrome microsoft-edge-stable-bin zoom --noconfirm

#Download de Programas Desenv
ame -S visual-studio-code-bin azuredatastudio-bin dbeaver-ce-bin postman-bin --noconfirm

#Download de Programas Infra
ame -S freedownloadmanager realvnc-vnc-viewer ferdium-bin winbox3 inetutils --noconfirm

#Download de Programas Utilitarios
ame -S wine-mono microsip realvnc-vnc-viewer gtkglext anydesk-bin --noconfirm

