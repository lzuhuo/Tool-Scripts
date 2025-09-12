#!/bin/bash

# Atualização de Pacotes
sudo pacman -Syu

# Instalação de Programas via terminal
sudo pacman -S git curl wget flameshot gnome-tweaks gnome-browser-connector firefox inetutils

# Instalação do PipeWire
sudo pacman -S pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber

# Instalação de Programas para OpenVPN
sudo pacman -S openvpn networkmanager-openvpn network-manager-applet

# Instalação de Requisitos
sudo pacman -S ttf-liberation xcb-util-cursor qt5-remoteobjects qt5-webengine

# Instalação do ame - Amethyst
sudo pacman -S --needed base-devel pacman-contrib cargo
git clone https://gitlab.com/crystal-linux/pkgbuilds/ame.git
cd ame
makepkg -si
cd ..

# Instalação de extensões GNOME
ame -S \
  gnome-shell-extension-all-windows-srwp \
  gnome-shell-extension-blur-my-shell \
  gnome-shell-extension-magic-lamp \
  gnome-shell-extension-compiz-windows-effect \
  gnome-shell-extension-dash-to-dock \
  gnome-shell-extension-show-desktop-button \
  gnome-shell-extension-vitals \
  --noconfirm

# Ativação das extensões GNOME
gnome-extensions enable all-windows-srwp@jakavery.github.io
gnome-extensions enable blur-my-shell@aunetx
gnome-extensions enable compiz-alike-magic-lamp-effect@hermes83.github.com
gnome-extensions enable compiz-windows-effect@hermes83.github.com
gnome-extensions enable dash-to-dock@micxgx.gmail.com
gnome-extensions enable show-desktop-button@amivaleo
gnome-extensions enable Vitals@CoreCoding.com

# Download de Programas Padrão
ame -S google-chrome microsoft-edge-stable-bin zoom --noconfirm

# Download de Programas de Desenvolvimento
ame -S visual-studio-code-bin azuredatastudio-bin dbeaver-ce-bin postman-bin --noconfirm

# Instalação do Node Version Manager (NVM)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts

# Download de Programas de Infraestrutura
ame -S realvnc-vnc-viewer ferdium-bin winbox inetutils extension-manager keepassxc --noconfirm

# Download de Programas Utilitários
ame -S wine-mono microsip realvnc-vnc-viewer gtkglext anydesk-bin ulauncher --noconfirm

# Download de Programas Específicos
ame -S gtkd --noconfirm
ame -S tilix --noconfirm
