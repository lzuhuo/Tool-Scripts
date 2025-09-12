#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_URL="https://pub-624c1898dc4040e2aa0cae1c31bfab7e.r2.dev/SimPlay-Win64-1.3.6.zip"
ZIP_FILE="$SCRIPT_DIR/SimPlay-Win64-1.3.6.zip"
EXTRACT_DIR="$SCRIPT_DIR/SimPlay"
WINEPREFIX="$HOME/SimPlayPrefix"
DESKTOP_FILE="$HOME/.local/share/applications/simplay.desktop"

# Detecta gerenciador de pacotes
detectar_gerenciador() {
  if command -v apt &> /dev/null; then
    GERENCIADOR="apt"
    INSTALAR="sudo apt update && sudo apt install -y"
  elif command -v dnf &> /dev/null; then
    GERENCIADOR="dnf"
    INSTALAR="sudo dnf install -y"
  elif command -v pacman &> /dev/null; then
    GERENCIADOR="pacman"
    INSTALAR="sudo pacman -S --noconfirm"
  elif command -v zypper &> /dev/null; then
    GERENCIADOR="zypper"
    INSTALAR="sudo zypper install -y"
  else
    echo "❌ Gerenciador de pacotes não reconhecido. Instale Wine, Winetricks e Zenity manualmente."
    exit 1
  fi
}

# Instala Wine, Winetricks e Zenity
instalar_dependencias() {
  detectar_gerenciador

  if ! command -v wine &> /dev/null; then
    echo "🍷 Instalando Wine..."
    eval "$INSTALAR wine"
  fi

  if ! command -v winetricks &> /dev/null; then
    echo "🧰 Instalando Winetricks..."
    eval "$INSTALAR winetricks"
  fi

  if ! command -v zenity &> /dev/null; then
    echo "🖼️ Instalando Zenity..."
    eval "$INSTALAR zenity"
  fi
}

# Escolha de resolução via Zenity
escolher_resolucao() {
  RESOLUCAO=$(zenity --list --title="Escolha a resolução" \
    --column="Resolução" "1920x1080" "1600x900" "1366x768" "1280x720" "1024x768" \
    --height=250 --width=300)

  if [ -z "$RESOLUCAO" ]; then
    RESOLUCAO="1366x768"
  fi
}

# Instalação
instalar() {
  if [ -f "$ZIP_FILE" ]; then
    zenity --info --text="Arquivo já existe: $ZIP_FILE"
  else
    zenity --info --text="Baixando Sim Play..."
    curl -L "$ZIP_URL" -o "$ZIP_FILE"
  fi

  unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR"

  INSTALLER=$(find "$EXTRACT_DIR" -iname '*.exe' | head -n 1)
  if [ -z "$INSTALLER" ]; then
    zenity --error --text="Nenhum arquivo .exe encontrado após extração."
    exit 1
  fi

  export WINEPREFIX
  wineboot
  winetricks settings win7
  winetricks -q dotnet48 vcrun2015 directx9 directplay dxvk

  RESOLUCAO=$(xrandr | grep '*' | awk '{print $1}' | head -n 1)
  if [ -z "$RESOLUCAO" ]; then
    escolher_resolucao
  fi

  winetricks -q vd="$RESOLUCAO"

  zenity --info --text="Iniciando instalação do Sim Play..."
  wine "$INSTALLER"

  EXECUTAVEL=$(find "$WINEPREFIX/drive_c" -iname 'SimPlay.exe' | head -n 1)
  if [ -f "$EXECUTAVEL" ]; then
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Sim Play
Exec=env WINEPREFIX=$WINEPREFIX wine "$EXECUTAVEL"
Type=Application
StartupNotify=true
Icon=wine
Categories=Utility;Video;
EOF
    update-desktop-database ~/.local/share/applications
    zenity --info --text="Atalho criado. Procure por 'Sim Play' no menu de aplicativos."
  else
    zenity --warning --text="Instalação concluída, mas o executável final não foi localizado."
  fi
}

# Desinstalação
desinstalar() {
  rm -rf "$WINEPREFIX"
  rm -f "$DESKTOP_FILE"
  rm -rf "$ZIP_FILE" "$EXTRACT_DIR"
  update-desktop-database ~/.local/share/applications
  zenity --info --text="Sim Play removido com sucesso."
}

# Instala dependências antes de qualquer uso do Zenity
instalar_dependencias

# Menu gráfico
opcao=$(zenity --list --title="Gerenciador do Sim Play" \
  --column="Ação" "Instalar" "Desinstalar" "Sair" \
  --height=200 --width=300)

case "$opcao" in
  "Instalar") instalar ;;
  "Desinstalar") desinstalar ;;
  "Sair") exit 0 ;;
  *) zenity --error --text="Opção inválida ou cancelada." ;;
esac
