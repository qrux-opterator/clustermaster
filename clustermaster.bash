#!/bin/bash

SETTINGS_FILE="$HOME/cm_settings.txt"
SOURCE_CONFIG_FILE="$HOME/ceremonyclient/node/.config/config.yml"
BACKUP_DIR="$HOME/MasterCluster_BackupFiles"
SERVICE_FILE="/etc/systemd/system/para.service"
VERSION_FILE="$HOME/cm_nodeversion.txt"
DEFAULT_CONFIG_FILE="/root/cm_default.txt"

# Function to install functions from GitHub if they're not present
install_functions_from_github() {
    echo "Downloading functions from GitHub..."
    curl -o "$HOME/functions.sh" https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/functions.sh
    if [ -f "$HOME/functions.sh" ]; then
        echo "Functions successfully installed."
        source "$HOME/functions.sh"
    else
        echo "Failed to download functions. Please check your connection."
        exit 1
    fi
}

# Source the functions from $HOME/functions.sh if they exist
if [ -f "$HOME/functions.sh" ]; then
    source "$HOME/functions.sh"
else
    echo "Functions file not found! Please install the functions first."
    echo "Use option 1 in the 'Install Cluster Menu' to download functions."
fi

# Function to set the node version
set_version() {
    echo "Set Version Menu:"
    echo "1. 2.0.2.4 (Default)"
    echo "2. 2.0.3 (Next Update)"
    echo "3. 2.0.3-testnet (Testnet)"
    echo "4. Custom Version"
    
    read -p "Choose a version option: " version_option

    case $version_option in
        1)
            echo "2.0.2.4" > "$VERSION_FILE"
            echo "Version set to 2.0.2.4 (Default)."
            ;;
        2)
            echo "2.0.3" > "$VERSION_FILE"
            echo "Version set to 2.0.3 (Next Update)."
            ;;
        3)
            echo "2.0.3-testnet" > "$VERSION_FILE"
            echo "Version set to 2.0.3-testnet (Testnet)."
            ;;
        4)
            read -p "Enter custom version: " custom_version
            echo "$custom_version" > "$VERSION_FILE"
            echo "Version set to custom version: $custom_version."
            ;;
        *)
            echo "Invalid option. Returning to main menu."
            ;;
    esac
}

# Function for QuickSetup (runs steps sequentially with conditional stopping)
quick_setup() {
    echo "Starting Quick Setup..."
    create_ip_block
    backup_and_setconfig

    # Add condition here for stop_node_tasks_and_services
    if [ -f "$DEFAULT_CONFIG_FILE" ]; then
        # Read the variable value, default to lowercase
        restart_var=$(grep '^restart_after_config_change=' "$DEFAULT_CONFIG_FILE" | cut -d '=' -f2 | tr '[:upper:]' '[:lower:]')
        if [ "$restart_var" = "yes" ]; then
            echo "Configuration specifies to restart after config change. Stopping node tasks and services..."
            stop_node_tasks_and_services
        elif [ "$restart_var" = "no" ]; then
            echo "Configuration specifies not to restart after config change. Skipping stopping node tasks and services."
        else
            echo "Variable 'restart_after_config_change' is set to '$restart_var', which is invalid."
            read -p "Do you want to stop node tasks and services? (y/n): " choice
            case "$choice" in
                y|Y ) 
                    stop_node_tasks_and_services 
                    ;;
                * ) 
                    echo "Skipping stopping node tasks and services."
                    ;;
            esac
        fi
    else
        echo "Configuration file $DEFAULT_CONFIG_FILE not found."
        read -p "Do you want to stop node tasks and services? (y/n): " choice
        case "$choice" in
            y|Y ) 
                stop_node_tasks_and_services 
                ;;
            * ) 
                echo "Skipping stopping node tasks and services."
                ;;
        esac
    fi

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

# Function to generate the client-script install one-liner
generate_client_script_install_oneliner() {
    echo "Generating Client-Script Install One-Liner..."
    create_client_installers
}

# Function to generate the client-config install one-liner
generate_client_config_install_oneliner() {
    echo "Generating Client-Config Install One-Liner..."
    generate_simple_client_config_install_command
}

# Menu for Install Cluster
install_cluster() {
    while true; do
        echo "Install Cluster Menu:"
        echo "1. Download Functions"
        echo "2. Input IPs and Threads"
        echo "3. QuickSetup"
        echo "4. Install - Slaves"
        echo "5. AdvancedSetup [...]"
        echo "6. Back to Main Menu"
        
        read -p "Choose an option: " cluster_option
        
        case $cluster_option in
            1) install_functions_from_github ;;   # Download functions
            2) set_cluster ;;                    # Input IPs and Threads (renamed)
            3) quick_setup ;;                    # Run QuickSetup
            4) 
                generate_client_script_install_oneliner
                generate_client_config_install_oneliner 
                ;;  # Combined Install - Slaves
            5) advanced_setup ;;                 # Advanced setup submenu
            6) break ;;                          # Go back to main menu
            *) echo "Invalid option. Please choose again." ;;
        esac
    done
}

# Function to show logs
show_logs() {
    echo "Showing logs for para.service..."
    journalctl -u para.service --no-hostname -f
}

# Function to start or restart the node
start_or_restart_node() {
    echo "Starting or Restarting the para service..."
    systemctl daemon-reload && sudo systemctl restart para
    echo "Node started/restarted."
}

# Function to stop the node
stop_node() {
    echo "Stopping the para service..."
    sudo systemctl stop para
    echo "Node stopped."
}

# Main Menu
main_menu() {
    while true; do
        # Display the current version at the top of the menu
        if [ -f "$VERSION_FILE" ]; then
            current_version=$(cat "$VERSION_FILE")
        else
            current_version="Not Set"
        fi
        echo "Current Node Version: $current_version"
        
        echo "Main Menu:"
        echo "1. Show Logs"
        echo "2. Start / Restart Node"
        echo "3. Stop Node"
        echo "4. Install Cluster [...]"
        echo "5. Set Version"
        echo "6. Exit"
        
        read -p "Choose an option: " main_option
        
        case $main_option in
            1) show_logs ;;                      # Show logs
            2) start_or_restart_node ;;          # Start/Restart the node
            3) stop_node ;;                      # Stop the node
            4) install_cluster ;;                # Install Cluster Menu
            5) set_version ;;                    # Set Version
            6) exit 0 ;;                         # Exit the script
            *) echo "Invalid option. Please choose again." ;;
        esac
    done
}

# Start the script with the main menu
main_menu
