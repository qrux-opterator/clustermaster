#!/bin/bash

SETTINGS_FILE="/root/cm_settings.txt"
SOURCE_CONFIG_FILE="/root/ceremonyclient/node/.config/config.yml"
BACKUP_DIR="/root/MasterCluster_BackupFiles"
SERVICE_FILE="/etc/systemd/system/para.service"

# Function to install functions from GitHub if they're not present
install_functions_from_github() {
    echo "Downloading functions from GitHub..."
    curl -o /root/functions.sh https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/functions.sh
    if [ -f /root/functions.sh ]; then
        echo "Functions successfully installed."
        source /root/functions.sh
    else
        echo "Failed to download functions. Please check your connection."
        exit 1
    fi
}

# Source the functions from /root/functions.sh if they exist
if [ -f /root/functions.sh ]; then
    source /root/functions.sh
else
    echo "Functions file not found! Please install the functions first."
fi

# Function for QuickSetup (runs steps 3-7 sequentially)
quick_setup() {
    echo "Starting Quick Setup..."
    create_ip_block
    backup_and_setconfig
    stop_node_tasks_and_services
    replace_config_in_ceremonyclient
    setup_master
    echo "Quick Setup completed."
}

# Function for AdvancedSetup (shows a submenu to run individual steps)
advanced_setup() {
    while true; do
        echo "Advanced Setup Menu:"
        echo "1. Create IP-Block for config"
        echo "2. Backup and SetConfig"
        echo "3. Stop Node Tasks and Services"
        echo "4. Replace Config in ceremonyclient"
        echo "5. Setup Master"
        echo "6. Back to Main Menu"
        
        read -p "Choose an option: " option

        case $option in
            1) create_ip_block ;;
            2) backup_and_setconfig ;;
            3) stop_node_tasks_and_services ;;
            4) replace_config_in_ceremonyclient ;;
            5) setup_master ;;
            6) break ;;
            *) echo "Invalid option. Please choose again." ;;
        esac
    done
}

# Function placeholder for generating the client-script install one-liner
generate_client_script_install_oneliner() {
    echo "Generating Client-Script Install One-Liner..."
    create_client_installers
}

# Function placeholder for generating the client-config install one-liner
generate_client_config_install_oneliner() {
    echo "Generating Client-Config Install One-Liner..."
    # Assuming you have a function to generate the config install command
    generate_client_config_install_command
}

# Main Menu
while true; do
    echo "Main Menu:"
    echo "1. Install Functions"
    echo "2. Set your Cluster"
    echo "3. QuickSetup"
    echo "4. Generate Client-Script Install-1liner"
    echo "5. Generate Client-Config Install-1liner"
    echo "6. AdvancedSetup [...]"
    echo "7. Exit"
    
    read -p "Choose an option: " main_option
    
    case $main_option in
        1) install_functions_from_github ;;  # Download functions if missing
        2) set_cluster ;;  # Function to set up the cluster
        3) quick_setup ;;  # Runs the QuickSetup function
        4) generate_client_script_install_oneliner ;;  # Calls the client script install generator
        5) generate_client_config_install_oneliner ;;  # Calls the client config install generator
        6) advanced_setup ;;  # Shows the advanced setup submenu
        7) exit 0 ;;  # Exit the script
        *) echo "Invalid option. Please choose again." ;;
    esac
done
