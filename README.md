# 🛠️ Tool-Scripts

Coleção de scripts utilitários para automatizar instalação, configuração e manutenção de ambientes em **Linux**, **macOS** e **Windows**.  
Este projeto foi criado para facilitar o setup inicial de máquinas novas e padronizar ambientes de trabalho.

---

## 📑 Índice
- Visão Geral
- Estrutura do Projeto
- Instalação
- Scripts Disponíveis
- Compatibilidade
- Contribuição
- Licença

---

## 🚀 Visão Geral
Os scripts foram desenvolvidos para:
- Automatizar instalação de pacotes essenciais.
- Configurar ambientes de desenvolvimento.
- Realizar limpeza e manutenção do sistema.
- Garantir consistência entre diferentes sistemas operacionais.

---

## 📂 Estrutura do Projeto

Tool-Scripts/
├── Linux/
│   ├── fedora-install.sh
│   ├── ubuntu-install.sh
│   └── cleanup.sh
├── MacOS/
│   └── brew-install.sh
├── Windows/
│   ├── install.ps1
│   └── setup.bat
└── README.md

---

## ⚙️ Instalação

🐧 Linux
chmod +x fedora-install.sh
./fedora-install.sh

🍎 macOS
chmod +x brew-install.sh
./brew-install.sh

Obs: O script já instala o Homebrew automaticamente caso não esteja presente.

🪟 Windows (PowerShell)
.\install.ps1

🪟 Windows (Batch)
setup.bat

---

## 📜 Scripts Disponíveis

Linux:
- Instalação de pacotes via dnf ou apt
- Configuração de Flathub
- Scripts de limpeza e manutenção

macOS:
- Instalação automática do Homebrew
- Instalação de pacotes via brew e brew cask
- Configuração de ambiente de desenvolvimento

Windows:
- Instalação de programas via winget ou choco
- Automação de setup inicial
- Scripts de manutenção

---

## 💻 Compatibilidade

Linux: Fedora, Ubuntu, Debian  
macOS: Intel e Apple Silicon  
Windows: 10 e 11  

---

## 🤝 Contribuição

1. Faça um fork do repositório  
2. Crie uma branch (feature/nova-funcionalidade)  
3. Commit suas alterações  
4. Abra um Pull Request  

---

## 📜 Licença

Este projeto está sob a licença MIT.  
Você pode usar, modificar e distribuir livremente, desde que mantenha os créditos.

---

### ✨ Autor

Desenvolvido por Elizeu
