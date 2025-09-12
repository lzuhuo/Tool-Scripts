#!/bin/bash

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_URL="https://pub-624c1898dc4040e2aa0cae1c31bfab7e.r2.dev/SimPlay-Win64-1.3.6.zip"
ZIP_FILE="$SCRIPT_DIR/SimPlay-Win64-1.3.6.zip"
EXTRACT_DIR="$SCRIPT_DIR/SimPlay"
WINEPREFIX="$HOME/SimPlayPrefix"
DESKTOP_FILE="$HOME/.local/share/applications/simplay.desktop"

# Detecta gerenciador de pacotes
detectar_gerenciador() {
  if command -v apt &> /dev/null; then
    echo "🔍 Distro baseada em Debian/Ubuntu detectada."
    GERENCIADOR="apt"
    INSTALAR="sudo apt update && sudo apt install -y"
  elif command -v dnf &> /dev/null; then
    echo "🔍 Distro baseada em Fedora/RHEL detectada."
    GERENCIADOR="dnf"
    INSTALAR="sudo dnf install -y"
  elif command -v pacman &> /dev/null; then
    echo "🔍 Distro baseada em Arch/Manjaro detectada."
    GERENCIADOR="pacman"
    INSTALAR="sudo pacman -S --noconfirm"
  elif command -v zypper &> /dev/null; then
    echo "🔍 Distro baseada em openSUSE detectada."
    GERENCIADOR="zypper"
    INSTALAR="sudo zypper install -y"
  else
    echo "❌ Gerenciador de pacotes não reconhecido. Instale Wine e Winetricks manualmente."
    exit 1
  fi
}

# Instala Wine e Winetricks
instalar_dependencias() {
  detectar_gerenciador

  if ! command -v wine &> /dev/null; then
    echo "🍷 Wine não encontrado. Instalando..."
    eval "$INSTALAR wine"
  else
    echo "✅ Wine já está instalado."
  fi

  if ! command -v winetricks &> /dev/null; then
    echo "🧰 Winetricks não encontrado. Instalando..."
    eval "$INSTALAR winetricks"
  else
    echo "✅ Winetricks já está instalado."
  fi
}

# Função de instalação
instalar() {
  instalar_dependencias

  echo "🌐 Verificando arquivo de instalação..."
  if [ -f "$ZIP_FILE" ]; then
    echo "📦 Arquivo já existe: $ZIP_FILE"
  else
    echo "🌐 Baixando Sim Play..."
    curl -L "$ZIP_URL" -o "$ZIP_FILE"
  fi

  echo "📦 Extraindo arquivos..."
  unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR"

  INSTALLER=$(find "$EXTRACT_DIR" -iname '*.exe' | head -n 1)
  if [ -z "$INSTALLER" ]; then
    echo "❌ Nenhum arquivo .exe encontrado após extração."
    exit 1
  fi

  echo "🔧 Criando prefixo Wine..."
  export WINEPREFIX
  wineboot

  echo "🛠️ Configurando Wine para Windows 7..."
  winetricks settings win7

  echo "📦 Instalando dependências do Sim Play..."
  winetricks -q dotnet48 vcrun2015 directx9 directplay dxvk

  echo "🖥️ Configurando área virtual do Wine..."
  RESOLUCAO=$(xrandr | grep '*' | awk '{print $1}' | head -n 1)

  if [ -n "$RESOLUCAO" ]; then
    echo "🖥️ Aplicando resolução detectada: $RESOLUCAO"
  else
    echo "⚠️ Não foi possível detectar a resolução automaticamente."
    echo "📋 Escolha uma resolução para a área virtual:"
    echo "1) 1920x1080"
    echo "2) 1600x900"
    echo "3) 1366x768"
    echo "4) 1280x720"
    echo "5) 1024x768"
    read -rp "Opção: " escolha

    case "$escolha" in
      1) RESOLUCAO="1920x1080" ;;
      2) RESOLUCAO="1600x900" ;;
      3) RESOLUCAO="1366x768" ;;
      4) RESOLUCAO="1280x720" ;;
      5) RESOLUCAO="1024x768" ;;
      *) echo "⚠️ Opção inválida. Usando padrão 1366x768."; RESOLUCAO="1366x768" ;;
    esac
  fi

  echo "🖥️ Aplicando área virtual com resolução: $RESOLUCAO"
  winetricks -q vd="$RESOLUCAO"

  echo "🚀 Iniciando instalação do Sim Play..."
  wine "$INSTALLER"

  EXECUTAVEL=$(find "$WINEPREFIX/drive_c" -iname 'SimPlay.exe' | head -n 1)
  if [ -f "$EXECUTAVEL" ]; then
    echo "📁 Criando atalho gráfico..."
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
    echo "✅ Atalho criado. Procure por 'Sim Play' no menu de aplicativos."
  else
    echo "⚠️ Instalação concluída, mas o executável final não foi localizado."
  fi
}

# Função de desinstalação
desinstalar() {
  echo "🧹 Removendo prefixo Wine..."
  rm -rf "$WINEPREFIX"

  echo "🗑️ Removendo atalho do menu..."
  rm -f "$DESKTOP_FILE"

  echo "🧼 Limpando arquivos baixados..."
  rm -rf "$ZIP_FILE" "$EXTRACT_DIR"

  echo "🔄 Atualizando banco de atalhos..."
  update-desktop-database ~/.local/share/applications

  echo "✅ Sim Play removido com sucesso."
}

# Menu interativo
echo "📦 Gerenciador do Sim Play"
echo "1) Instalar"
echo "2) Desinstalar"
echo "0) Sair"
read -rp "Escolha uma opção: " opcao

case "$opcao" in
  1) instalar ;;
  2) desinstalar ;;
  0) echo "👋 Saindo..." ;;
  *) echo "❌ Opção inválida." ;;
esac
