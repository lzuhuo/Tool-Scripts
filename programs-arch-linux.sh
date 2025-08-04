#Atualização de Pacotes
sudo pacman -Syu

#Instalação de Programas via terminal
sudo pacman -S git curl wget flameshot gnome-tweaks gnome-browser-connector firefox inetutils

#Instalação Pipeware
sudo pacman -S pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber

#Instalação de Programas para Openvpn
sudo pacman -S openvpn networkmanager-openvpn network-manager-applet

#Instalaćão de Requisitos
sudo pacman -S ttf-liberation  xcb-util-cursor  qt5-remoteobjects  qt5-webengine

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

#Node Version Manager
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
nvm install --lts

#Download de Programas Infra
ame -S realvnc-vnc-viewer ferdium-bin winbox inetutils extension-manager keepassxc --noconfirm

#Download de Programas Utilitarios
ame -S wine-mono microsip realvnc-vnc-viewer gtkglext anydesk-bin ulauncher --noconfirm

#Download de Programas Especificos
ame -S gtkd --noconfirm
ame -S tilix --noconfirm
