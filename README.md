# 🛠️ Tool-Scripts

Coleção de scripts utilitários para automatizar instalação, configuração e manutenção de ambientes em **Linux**, **macOS** e **Windows**.  
Este projeto foi criado para facilitar o setup inicial de máquinas novas e padronizar ambientes de trabalho.

---

## 📑 Índice
- [Visão Geral](#-visão-geral)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Instalação](#-instalação)
- [Scripts Disponíveis](#-scripts-disponíveis)
- [Compatibilidade](#-compatibilidade)
- [Contribuição](#-contribuição)
- [Licença](#-licença)

---

## 🚀 Visão Geral
Os scripts foram desenvolvidos para:
- Automatizar instalação de pacotes essenciais.
- Configurar ambientes de desenvolvimento.
- Realizar limpeza e manutenção do sistema.
- Garantir consistência entre diferentes sistemas operacionais.

---

## 📂 Estrutura do Projeto

```plaintext
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


## ⚙️ Instalação

```bash
# Linux
chmod +x fedora-install.sh
./fedora-install.sh


# macOS
chmod +x brew-install.sh
./brew-install.sh


Obs: O script já instala o Homebrew automaticamente caso não esteja presente.


# Windows (PowerShell)
.\install.ps1


:: Windows (Batch)
setup.bat



Assim, toda a parte de instalação está encapsulada em blocos de código Markdown, sem nada fora.
