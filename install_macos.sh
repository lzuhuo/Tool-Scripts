#!/bin/bash

# Instalação do Homebrew (se não estiver instalado)
if ! command -v brew &> /dev/null
then
    echo "Homebrew não encontrado. Instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Atualizando o ambiente do terminal para carregar o brew imediatamente
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Atualização do Homebrew
brew update
brew upgrade

# Instalação de Programas via Homebrew (CLI)
brew install flameshot git curl

# Instalação de aplicativos via Homebrew Cask (GUI apps)
brew install --cask google-chrome
brew install --cask microsoft-edge
brew install --cask visual-studio-code
brew install --cask zoom
brew install --cask anydesk
brew install --cask vnc-viewer
brew install --cask azure-data-studio
brew install --cask postman
brew install --cask dbeaver-community
brew install --cask keepassxc
brew install --cask ferdium

# Observação: Zoiper e WiFiman não possuem fórmulas oficiais no Homebrew.
# Para esses, o ideal é baixar manualmente do site oficial:
# Zoiper: https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/macos
# WiFiman: https://wifiman.com/

# Limpeza Final
brew cleanup

echo "Instalação concluída com sucesso!"
