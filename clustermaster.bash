#!/bin/bash

# Define the URL and local path for the functions file
FUNCTIONS_URL="https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/functions.sh"
FUNCTIONS_PATH="/root/functions.sh"
SETTINGS_FILE="/root/cm_settings.txt"
CONFIG_BLOCK_FILE="/root/config_block.txt"

# Function to download and source the functions file
download_and_source_functions() {
    echo "Downloading functions from GitHub..."
    if curl -s -o "$FUNCTIONS_PATH" "$FUNCTIONS_URL"; then
        echo "Sourcing the functions..."
        source "$FUNCTIONS_PATH"
        echo "Functions sourced successfully from $FUNCTIONS_PATH."
    else
        echo "Failed to download functions from GitHub. Please check the URL or network connection."
        exit 1
    fi
}

# Source the functions file if it exists
if [ -f "$FUNCTIONS_PATH" ]; then
    source "$FUNCTIONS_PATH"
fi

# Function to show logs for para.service
show_logs() {
    echo "Showing logs for para.service..."
    journalctl -u para.service --no-hostname -f
}

# Function to restart the para service
restart_node() {
    echo "Restarting para service..."
    systemctl daemon-reload && service para restart && journalctl -u para.service --no-hostname -f
}

# Function to stop the para service and node-related processes
stop_node() {
    echo "Stopping para service and node-related processes..."
    service para stop
    pkill -f node-1.4.21.1-linux
    echo "para service stopped and node processes killed."
}

# Placeholder function: Edit Start Command
edit_start_command() {
    echo "Editing start command... (Placeholder)"
    # You can add the command editing functionality here
}

# Function to display install-related commands (nested menu)
install_commands_menu() {
    while true; do
        echo "Install Commands Menu:"
        echo "1. Install Functions from GitHub"
        echo "2. Set your Cluster (IP and Workers)"
        echo "3. Create IP-Block for config"
        echo "4. Backup and SetConfig"
        echo "5. Stop Node Tasks and Services"
        echo "6. Replace Config in ceremonyclient"
        echo "7. Setup Master"
        echo "8. Create Client Installers"
        echo "9. Generate Client Config Install Command"
        echo "10. Back to Main Menu"
        
        read -p "Choose an option: " install_choice
        case $install_choice in
            1)
                download_and_source_functions
                ;;
            2)
                if declare -f set_cluster > /dev/null; then
                    set_cluster
                else
                    echo "Invalid option."
                fi
                ;;
            3)
                if declare -f create_ip_block > /dev/null; then
                    create_ip_block
                else
                    echo "Invalid option."
                fi
                ;;
            4)
                if declare -f backup_and_setconfig > /dev/null; then
                    backup_and_setconfig
                else
                    echo "Invalid option."
                fi
                ;;
            5)
                if declare -f stop_node_tasks_and_services > /dev/null; then
                    stop_node_tasks_and_services
                else
                    echo "Invalid option."
                fi
                ;;
            6)
                if declare -f replace_config_in_ceremonyclient > /dev/null; then
                    replace_config_in_ceremonyclient
                else
                    echo "Invalid option."
                fi
                ;;
            7)
                if declare -f setup_master > /dev/null; then
                    setup_master
                else
                    echo "Invalid option."
                fi
                ;;
            8)
                if declare -f create_client_installers > /dev/null; then
                    create_client_installers
                else
                    echo "Invalid option."
                fi
                ;;
            9)
                if declare -f generate_simple_client_config_install_command > /dev/null; then
                    generate_simple_client_config_install_command
                else
                    echo "Invalid option."
                fi
                ;;
            10)
                return
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
    done
}

# Main program loop (Default menu)
while true; do
    echo "1. Show Logs"
    echo "2. Restart Node"
    echo "3. Stop Node"
    echo "4. Edit Start Command"
    echo "_________________________"
    echo "5. Install Commands"
    echo "6. Exit"

    read -p "Choose an option: " choice

    case $choice in
        1)
            show_logs
            ;;
        2)
            restart_node
            ;;
        3)
            stop_node
            ;;
        4)
            edit_start_command
            ;;
        5)
            install_commands_menu
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option, please try again."
            ;;
    esac
done
