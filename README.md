# 🛠️ Tool-Scripts
[![Ask DeepWiki](https://devin.ai/assets/askdeepwiki.png)](https://deepwiki.com/lzuhuo/Tool-Scripts)

A collection of utility scripts to automate the installation, configuration, and maintenance of development and personal environments across various Linux distributions and macOS. These scripts are designed to streamline the setup of new machines and ensure a consistent user experience.

---

## 📜 Scripts Available

This repository contains a variety of scripts, each tailored for a specific operating system or task.

### 🐧 Linux

#### **Debian / Ubuntu**
*   `instalar-ubuntu-26-04.sh`: A comprehensive setup script for Ubuntu 20.04+ environments. It automates the installation of essential applications, development tools, and utilities using `apt` and `flatpak`. Includes detailed logging for each step.
*   `programs.sh`: A general-purpose script for Debian-based systems to install common applications via `apt` and `flatpak`.
*   `lvm-free-ubuntu-server.sh`: A utility for Ubuntu Server administrators to resize an LVM partition, extending it to use all available free space in the volume group. **Warning:** Run with caution and ensure you have backups.

#### **Fedora**
*   `instalar-fedora.sh`: Sets up a Fedora workstation by installing common software packages using the `dnf` package manager and `flatpak`.

#### **Arch Linux & Derivatives**
*   `programs-arch-linux.sh`: An extensive setup script for Arch Linux. It installs the `yay` AUR helper, PipeWire audio, development tools, a set of useful GNOME extensions, and other common applications from both official repositories and the AUR.
*   `programs-crystal-linux.sh`: A setup script specifically for Crystal Linux (an Arch derivative). It uses `pacman` and Crystal's `ame` helper. **Note:** Requires manual editing of `/etc/pacman.conf` before execution.

#### **Special Purpose / Compatibility**
*   `instalar_simplay.sh`: A graphical (Zenity-based) installer that sets up the Windows application 'SimPlay' on Linux using Wine. It handles dependency installation (Wine, Winetricks), creates a dedicated Wine prefix, and adds a desktop shortcut.
*   `sql-2008.sh`: A workaround script that compiles and installs an older version of OpenSSL (1.1.1h) to enable connectivity with legacy systems like SQL Server 2008 that use outdated security protocols.

---

### 🍎 macOS
*   `install_macos.sh`: Sets up a macOS environment by first installing Homebrew (if not present) and then using it to install a suite of popular command-line tools and GUI applications.

---

## ⚙️ Usage

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/lzuhuo/Tool-Scripts.git
    cd Tool-Scripts
    ```

2.  **Review the script:**
    Before executing any script, it is highly recommended to read its contents to understand the changes it will make to your system.
    ```bash
    cat <script-name>.sh
    ```

3.  **Make the script executable:**
    ```bash
    chmod +x <script-name>.sh
    ```

4.  **Run the script:**
    Most scripts require `sudo` privileges to install software.
    ```bash
    ./<script-name>.sh
    ```

---

## ⚠️ Disclaimer

These scripts perform administrative tasks, install software, and modify system configurations. Run them at your own risk. The author is not responsible for any damage or data loss that may occur. Always back up your important data before running any system modification script.

## 🤝 Contributing

Contributions are welcome! If you have a script that could benefit others or an improvement to an existing one, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/my-new-script`).
3.  Commit your changes (`git commit -am 'Add some new script'`).
4.  Push to the branch (`git push origin feature/my-new-script`).
5.  Open a Pull Request.
