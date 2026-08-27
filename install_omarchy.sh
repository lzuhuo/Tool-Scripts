#!/bin/bash

# Atualização de Pacotes
sudo pacman -Syu

# Instalação de Programas via terminal (repositórios oficiais)
sudo pacman -S --noconfirm git curl wget flameshot inetutils
# Download de Programas Padrão (AUR)
yay -S --noconfirm microsoft-edge-stable-bin

# Download de Programas de Desenvolvimento (AUR)
yay -S --noconfirm dbeaver-ce-bin postman-bin

# Download de Programas de Infraestrutura (AUR)
yay -S --noconfirm ferdium-bin keepassxc

# Download de Programas Utilitários (AUR)
yay -S --noconfirm wine-mono microsip gtkglext anydesk-bin freedownloadmanager-bin
