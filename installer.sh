#!/bin/bash

# Frappe Installation Script
# This script is intended for Ubuntu and Debian systems only.
# It will install Frappe Bench, MariaDB, Redis.

# Function to check if the OS is Linux
check_os() {
  if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script is intended for Linux systems only."
    exit 1
  fi
}

# Function to check if the Linux distribution is Ubuntu or Debian
check_distro() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
      echo "This script is intended for Ubuntu and Debian systems only."
      exit 1
    fi
  else
    echo "Unable to determine the Linux distribution."
    exit 1
  fi
}

# Function to update the system packages
update_system() {
  echo "Updating system packages..."
  if ! sudo apt update -y && sudo apt upgrade -y; then
    echo "Failed to update system packages."
    exit 1
  fi
}

# Function to check if the MariaDB repository version is 10.6 or higher
check_mariadb_repo_version() {
  mariadb_version=$(apt-cache policy mariadb-server | awk '/Candidate:/ {print $2}')
  if [[ "$mariadb_version" < "10.6" ]]; then
    echo "MariaDB version 10.6 or higher is required."
    exit 1
  fi
}

# Function to install MariaDB
install_mariadb() {
  echo "Installing MariaDB ..."
  if ! sudo apt install -y libmariadb-dev mariadb-server mariadb-client; then
    echo "Failed to install MariaDB."
    exit 1
  fi
  local passwd="$1"
  if ! sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$passwd';" ||
       ! sudo mysql -u root -p"$passwd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$passwd';" ||
       ! sudo mysql -u root -p"$passwd" -e "DELETE FROM mysql.user WHERE User='';" ||
       ! sudo mysql -u root -p"$passwd" -e "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" ||
       ! sudo mysql -u root -p"$passwd" -e "FLUSH PRIVILEGES;"; then
    echo "Failed to configure MariaDB."
    exit 1
  fi
}

# Function to install necessary dependencies
install_dependencies() {
  echo "Installing dependencies..."
  if ! sudo apt install -y cron git micro pkg-config python-is-python3 python3-dev python3-pip python3-venv redis-server; then
    echo "Failed to install dependencies."
    exit 1
  fi
}

# Function to install nvm (Node Version Manager) and Node.js
install_nvm() {
  echo "Installing nvm and Node.js..."
  if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; then
    echo "Failed to install nvm."
    exit 1
  fi
  export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  local node_version="22.16" # ***CHANGE IF NEEDED***
  if ! nvm install "$node_version" || ! nvm use ${node_version}; then
    echo "Failed to install Node.js."
    exit 1
  fi
  if ! npm install -g yarn npm@latest; then
    echo "Failed to install npm or yarn."
    exit 1
  fi
}

# Function to install lazygit
install_lazygit() {
  echo "Installing lazygit..."
  if ! which lazygit > /dev/null; then
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')

    # Determine the architecture and download the appropriate package
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_arm64.tar.gz"
    else
      curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    fi

    tar xf lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin
    rm lazygit.tar.gz lazygit
  else
    echo "lazygit is already installed."
  fi
}

# Function to install Frappe dependencies
install_frappe_dependencies() {
  echo "Installing Frappe dependencies..."
  if ! sudo apt install -y xvfb libfontconfig wkhtmltopdf; then
    echo "Failed to install Frappe dependencies."
    exit 1
  fi
}

# Function to install Frappe Bench
install_frappe_bench() {
  echo "Installing Frappe Bench..."
  if ! sudo pip install frappe-bench --break-system-packages; then
    echo "Failed to install Frappe Bench."
    exit 1
  fi
}

# Function to set up a new Frappe instance
setup_new_instance() {
  local instance_path="$1"
  local frappe_version="$2"
  local repo_addr="$3"

  if ! bench init "$instance_path" \
              --frappe-branch "$frappe_version" \
              --frappe-path "$repo_addr/frappe" \
              --verbose; then
    echo "Failed to initialize Frappe instance."
    exit 1
  fi
  cd "$instance_path" &&
  chmod -R o+rx "$instance_path"
}

# Function to set up a new Frappe site
setup_new_site() {
  local instance_path="$1"
  local site_name="$2"
  local root_password="$3"
  local db_name="$4"
  local db_password="$5"
  local admin_password="$6"


  cd "$instance_path" &&
  redis-server config/redis_queue.conf &
  redis-server config/redis_cache.conf &
  if ! bench new-site "$site_name" \
    --db-root-username "root" \
    --db-root-password "$root_password" \
    --db-name "$db_name" \
    --db-password "$db_password" \
    --admin-password "$admin_password" \
    --mariadb-user-host-login-scope='%' \
    --set-default \
    --verbose; then
    echo "Failed to set up new Frappe site."
    exit 1
  fi
  if ! bench --site "$site_name" add-to-hosts || ! bench use "$site_name"; then
    echo "Failed to configure the new Frappe site."
    exit 1
  fi
}

# Function to enable developer mode for Frappe
enable_developer_mode() {
  local instance_path="$1"
  local site_name="$2"

  cd "$instance_path" &&
  if ! bench set-config -g developer_mode true || ! bench --site "$site_name" set-config developer_mode true; then
    echo "Failed to enable developer mode."
    exit 1
  fi
}

# Function to update the .bashrc file
update_bashrc() {
  bashrc_file="${HOME}/.bashrc"
  # Unset the history
  if ! grep -q "unset HISTFILE" "$bashrc_file"; then
    echo "unset HISTFILE" >> "$bashrc_file"
  fi
  # Set TERM to xterm-256color
  if ! grep -q "export TERM=xterm-256color" "$bashrc_file"; then
    echo "export TERM=xterm-256color" >> "$bashrc_file"
  fi
}

# Main function to orchestrate the installation process
main() {
  echo "Starting Frappe installation..."
  update_bashrc
  update_system

  # Check the OS and distribution
  check_os
  check_distro
  check_mariadb_repo_version

  install_dependencies
  install_nvm
  install_lazygit
  install_frappe_dependencies

  local root_password="1234"  # MariaDB root password ***PLEASE CHANGE***
  install_mariadb "${root_password}"
  install_frappe_bench

  local install_dir="${HOME}/opt"
  local instance_name="frappe-dev"
  local frappe_instance="$install_dir/$instance_name"
  local frappe_version="develop" # Specify branch or tags
  local repo_addr="https://github.com/frappe" # Frappe repo location
  local site_name="dev.frappe.local" # Site Name
  local db_name="frappe-dev"
  local db_password=$(openssl rand -hex 12)
  local admin_password="1234" # Default administrator password ***PLEASE CHANGE***

  setup_new_instance "$frappe_instance" "$frappe_version" "$repo_addr"
  setup_new_site "$frappe_instance" "$site_name" "$root_password" "$db_name" "$db_password" "$admin_password"
  enable_developer_mode "$frappe_instance" "$site_name"

  echo "Frappe installation completed successfully."

  # if above script run successfully then reboot system
  echo "Rebooting system in 5 seconds ..."
  sleep 5 # Wait for 5 seconds before rebooting
  history -c && sudo reboot
}

main
