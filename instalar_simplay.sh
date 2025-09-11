#!/bin/bash

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_URL="https://pub-624c1898dc4040e2aa0cae1c31bfab7e.r2.dev/SimPlay-Win64-1.3.6.zip"
ZIP_FILE="$SCRIPT_DIR/SimPlay-Win64-1.3.6.zip"
EXTRACT_DIR="$SCRIPT_DIR/SimPlay"
WINEPREFIX="$HOME/SimPlayPrefix"
DESKTOP_FILE="$HOME/.local/share/applications/simplay.desktop"

# Função de instalação
instalar() {
  echo "🌐 Baixando Sim Play..."
  curl -L "$ZIP_URL" -o "$ZIP_FILE"

  echo "📦 Extraindo arquivos..."
  unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR"

  # Detecta o primeiro .exe encontrado
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

  echo "📦 Instalando dependências..."
  winetricks -q dotnet48 vcrun2015 directx9 directplay dxvk

  # Detecta resolução atual do monitor
  RESOLUCAO=$(xrandr | grep '*' | awk '{print $1}' | head -n 1)
  if [ -n "$RESOLUCAO" ]; then
    echo "🖥️ Aplicando resolução dinâmica: $RESOLUCAO"
    winetricks -q vd="$RESOLUCAO"
  else
    echo "⚠️ Não foi possível detectar a resolução. Usando padrão 1366x768."
    winetricks -q vd=1366x768
  fi

  echo "🚀 Iniciando instalação do Sim Play..."
  wine "$INSTALLER"

  # Detecta o executável instalado
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
