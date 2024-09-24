# Function to generate a one-liner to copy the content of config.yml from master to client
generate_simple_client_config_install_command() {
     MASTER_CONFIG_FILE="/root/MasterCluster_BackupFiles/config.yml"; if [ ! -f "$MASTER_CONFIG_FILE" ]; then echo "Master config file not found at $MASTER_CONFIG_FILE"; return; fi; config_content=$(cat "$MASTER_CONFIG_FILE")
     echo "##################################################################################"
     echo "################👇 COPY THIS COMMAND AND RUN ON CLIENT MACHINE 👇################"
     echo -e "\e[34m mkdir -p /root/ClusterMaster_Backup && [ -f /root/ceremonyclient/node/.config/config.yml ] && mv /root/ceremonyclient/node/.config/config.yml /root/ClusterMaster_Backup/config_backup.yml && echo 'Backup created at /root/ClusterMaster_Backup/config_backup.yml' || echo 'No existing config.yml found, proceeding with installation' && cat << 'EOF' > /root/ceremonyclient/node/.config/config.yml $config_content EOF && [ -f /root/ceremonyclient/node/.config/config.yml ] && echo 'config.yml successfully installed' || { echo 'Failed to install config.yml!'; exit 1; } && [ -f /root/clustermaster.bash ] && /root/clustermaster.bash && echo 'Installation Complete! You can start your Slave now, and your Master after it is listening.' || echo 'Make sure you run the first Client Installer! clustermaster.bash was not found!'"
     echo -e "\e[0m"
     echo "#######################👆  END - DONT COPY THIS LINE  👆######################"
     echo "##################################################################################"
    
}

set_cluster() {
    echo -e "Enter your cluster details (IP and threads per IP), one per line."
    set +H
    echo -e "Format: IP Threads - \e[32mFirst IP is your Master!\e[0m - example:"
    set -H
    echo "192.168.0.1 32"
    echo "192.168.0.2 32"
    echo "192.168.0.3 48"
    echo -e "\e[32m"
    echo "When you are done, press Enter on an empty line!"
    echo -e "\e[0m"
    # Initialize an empty variable to store the input
    user_input=""

    # Read user input line by line
    while true; do
        # Read a line from the user
        read -p "> " input

        # Check if the user pressed Enter on an empty line (signals the end of input)
        if [ -z "$input" ]; then
            break
        fi

        # Append the input to the user_input variable
        user_input+="$input"$'\n'
    done

    # Save the collected input to the settings file
    echo -n "$user_input" > "$SETTINGS_FILE"
    
    echo "Cluster settings saved to $SETTINGS_FILE."
}

create_client_installers() {
    # Path to the settings file on the master
    SETTINGS_FILE="/root/cm_settings.txt"
    
    # Read the IPs and workers from cm_settings.txt into an array
    mapfile -t settings < "$SETTINGS_FILE"

    echo "Cluster Overview:"
    echo "------------------------------------"

    # Display all IPs and workers but mark the first one (master) as not selectable
    for i in "${!settings[@]}"; do
        ip=$(echo "${settings[$i]}" | awk '{print $1}')
        workers=$(echo "${settings[$i]}" | awk '{print $2}')
        if [ $i -eq 0 ]; then
            echo "$((i+1)). $ip (Master, $workers workers)"
        else
            echo "$((i+1)). $ip ($workers workers)"
        fi
    done

    echo "------------------------------------"
    echo "Choose a client machine to create an installer for (Master cannot be selected):"
    
    # Read user selection (must be greater than 1, since Master is index 0)
    while true; do
        read -p "Enter the number of the client machine: " choice
        if ((choice > 1 && choice <= ${#settings[@]})); then
            break
        else
            echo "Invalid selection. Please choose a valid client machine."
        fi
    done

    # Get the selected client IP and workers
    selected_ip=$(echo "${settings[$((choice-1))]}" | awk '{print $1}')
    selected_workers=$(echo "${settings[$((choice-1))]}" | awk '{print $2}')

    # Calculate total workers for all preceding machines and subtract 1
    total_workers=0
    for ((j=0; j<choice-1; j++)); do
        prev_workers=$(echo "${settings[$j]}" | awk '{print $2}')
        total_workers=$((total_workers + prev_workers))
    done
    total_workers=$((total_workers - 1))

    # Calculate the port range for the selected machine
    start_port=40000
    end_port=$((start_port + selected_workers))

    # Create the one-liner with $SERVICE_FILE, firewall commands, and the dynamic port range
    echo "################👇  COPY THIS COMMAND AND RUN ON CLIENT MACHINE  👇################"
    echo -e "\e[34m"
    echo "SERVICE_FILE=/etc/systemd/system/para.service && \\"
    echo "curl -s https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/install_service | sudo bash && \\"
    echo "sudo sed -i 's|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 [0-9]* [0-9]* 1.4.21.1|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 $total_workers $selected_workers 1.4.21.1|' \$SERVICE_FILE && \\"
    echo "sudo systemctl daemon-reload && \\"
    echo "echo 'para.service has been updated with the new ExecStart line:' && \\"
    echo "grep 'ExecStart=' \$SERVICE_FILE && \\"
    echo "curl -s -o /root/ceremonyclient/node/para.sh https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/para.sh && \\"
    echo "if [ -f /root/ceremonyclient/node/para.sh ]; then echo '✅ para.sh created '; else echo 'Failed to create para.sh ❌'; fi && \\"
    echo "yes | sudo ufw enable && sudo ufw allow 22 && sudo ufw allow 443 && sudo ufw allow 8336 && \\"
    echo "sudo ufw allow $start_port:$end_port/tcp && \\"
    echo "echo '✅ Firewall rules 🌐 updated for ports 22, 443, 8336, and $start_port to $end_port/tcp' && \\"
    echo "echo '💻 Downloading clustermaster.bash...' && \\"
    echo "curl -s -o /root/clustermaster.bash https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/clustermaster.bash && \\"
    echo "if [ -f /root/clustermaster.bash ]; then chmod +x /root/clustermaster.bash; echo 'clustermaster.bash downloaded and made executable'; else echo 'Could not download clustermaster.bash ❌'; fi && \\"
    echo "if [ -x /root/clustermaster.bash ]; then echo '💻 clustermaster.bash is ready ✅'; else echo 'clustermaster.bash is not executable ❌'; fi"
    echo -e "\e[0m"
    echo "#######################👆  END - DONT COPY THIS LINE  👆########################"

}

# Function to create the IP-Block for config
create_ip_block() {
    # Define the necessary variables
    SETTINGS_FILE="/root/cm_settings.txt"
    CONFIG_BLOCK_FILE="/root/config_block.txt"

    # Check if the settings file exists
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Settings file not found! Please set your cluster first."
        return
    fi

    # Read the IPs and threads (workers) from cm_settings.txt into an array
    mapfile -t settings < "$SETTINGS_FILE"

    # Initialize the config block variable
    config_block=""

    # Loop through each IP and its corresponding worker count
    for i in "${!settings[@]}"; do
        ip=$(echo "${settings[$i]}" | awk '{print $1}')
        workers=$(echo "${settings[$i]}" | awk '{print $2}')
        
        # If this is the first IP, adjust the worker count by subtracting 1 for the first IP
        if [ "$i" -eq 0 ]; then
            workers=$((workers - 1))
        fi
        
        # Generate the config block lines for each worker/thread
        for port in $(seq 1 "$workers"); do
            config_block+="    '/ip4/$ip/tcp/4000$port',"$'\n'
        done
    done

    # Remove the trailing comma from the last entry
    config_block=$(echo "$config_block" | sed '$s/,$//')

    # Write the config block to the config_block.txt file
    echo -n "$config_block" > "$CONFIG_BLOCK_FILE"

    echo "Config block saved to $CONFIG_BLOCK_FILE."
}


# Function to back up and set the config
backup_and_setconfig() {
    echo "Backing up and setting config..."

    # Define paths for the source and backup config files
    SOURCE_CONFIG_FILE="/root/ceremonyclient/node/.config/config.yml"
    BACKUP_DIR="/root/MasterCluster_BackupFiles"
    BACKUP_CONFIG_FILE="$BACKUP_DIR/configbackup.yml"
    ALTERED_CONFIG_FILE="$BACKUP_DIR/config.yml"
    CONFIG_BLOCK_FILE="/root/config_block.txt"

    # Check if the source config file exists
    if [ ! -f "$SOURCE_CONFIG_FILE" ]; then
        echo "Source config file $SOURCE_CONFIG_FILE not found!"
        return
    fi

    # Check if the backup directory exists, if not, create it
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory not found, creating $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
    fi

    # Copy the original config file to the backup location as configbackup.yml
    cp "$SOURCE_CONFIG_FILE" "$BACKUP_CONFIG_FILE"
    
    # Copy the original config file to the backup location as config.yml (this will be altered)
    cp "$SOURCE_CONFIG_FILE" "$ALTERED_CONFIG_FILE"
    
    # Check if the config_block.txt exists
    if [ ! -f "$CONFIG_BLOCK_FILE" ]; then
        echo "Config block file $CONFIG_BLOCK_FILE not found! Please create the IP block first."
        return
    fi

    # Read the content of config_block.txt
    config_block=$(cat "$CONFIG_BLOCK_FILE")

    # Ensure correct formatting for newlines
    data_worker_multiaddrs_block="  dataWorkerMultiaddrs: [\n${config_block}\n  ]"

    # Check if dataWorkerMultiaddrs exists in the file
    if grep -q "dataWorkerMultiaddrs:" "$BACKUP_CONFIG_FILE"; then
        echo "DEBUG: dataWorkerMultiaddrs block exists, replacing it."
        # Use awk to replace the block
        awk -v new_block="$data_worker_multiaddrs_block" '
            BEGIN { found = 0 }
            /dataWorkerMultiaddrs:/ { found = 1 }
            found && /\]/ { found = 0; print new_block; next }
            { print }
        ' "$BACKUP_CONFIG_FILE" > "$ALTERED_CONFIG_FILE"
    else
        echo "DEBUG: dataWorkerMultiaddrs block does not exist, adding it under 'engine:'."
        # Insert the block under 'engine:'
        awk -v new_block="$data_worker_multiaddrs_block" '
            /engine:/ { print; print new_block; next }
            { print }
        ' "$BACKUP_CONFIG_FILE" > "$ALTERED_CONFIG_FILE"
    fi

    # Minimal debug: print the section containing dataWorkerMultiaddrs
    echo "DEBUG: Showing the relevant section of the altered $ALTERED_CONFIG_FILE:"
    sed -n '/engine:/,/provingKeyId/p' "$ALTERED_CONFIG_FILE"

    echo "Backup completed and config.yml altered with new IP block."
}




# Function to stop node tasks and services
stop_node_tasks_and_services() {
    echo "Stopping services..."
    
    # Stop ceremonyclient service and wait until it's stopped
    echo "Stopping ceremonyclient service..."
    service ceremonyclient stop
    sleep 3  # Wait for a few seconds to allow the service to stop
    systemctl is-active --quiet ceremonyclient
    if [ $? -eq 0 ]; then
        echo "ceremonyclient service is still running."
    else
        echo "ceremonyclient service stopped."
    fi

    # Disable ceremonyclient service
    echo "Disabling ceremonyclient service..."
    systemctl disable ceremonyclient

    # Stop para service
    echo "Stopping para service..."
    service para stop
    sleep 3  # Wait for a few seconds to allow the service to stop
    systemctl is-active --quiet para
    if [ $? -eq 0 ]; then
        echo "para service is still running."
    else
        echo "para service stopped."
    fi

    # Use pkill to terminate any node-related processes
    echo "Stopping node-related processes..."
    pkill -f node-1.4.21.1-linux
    sleep 2  # Wait for a couple of seconds after killing the processes

    # Check for any remaining processes with "-node" in the name
    node_processes=$(ps aux | grep -i -- '-node' | grep -v grep)
    if [ -n "$node_processes" ]; then
        echo "The following node-related processes are still running:"
        echo "$node_processes"
        echo "Not all node processes were stopped."
    else
        echo "All node processes were stopped successfully."
    fi
}

# Function to replace config in ceremonyclient
replace_config_in_ceremonyclient() {
    BACKUP_DIR="/root/MasterCluster_BackupFiles"
    BACKUP_CONFIG_FILE="$BACKUP_DIR/configbackup.yml"
    ALTERED_CONFIG_FILE="$BACKUP_DIR/config.yml"
    SOURCE_CONFIG_FILE="/root/ceremonyclient/node/.config/config.yml"
    echo "Replacing the config in ceremonyclient..."

    # Check if the backup config file and the current config file exist
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo "Backup config file not found: $BACKUP_CONFIG_FILE"
        return
    fi

    if [ ! -f "$SOURCE_CONFIG_FILE" ]; then
        echo "Source config file not found: $SOURCE_CONFIG_FILE"
        return
    fi

    # Compare the backup config file and the current config file
    echo "Comparing the backup and current config files..."
    if cmp -s "$BACKUP_CONFIG_FILE" "$SOURCE_CONFIG_FILE"; then
        echo "This config.yml is already saved in the Backup folder. Proceeding..."
    else
        # If the files are not identical, prompt the user
        echo "The files in the backup folder and node/.config folder are not the same."
        read -p "Are you sure you want to continue? Type 'yes' to continue or any key to stop: " user_input

        if [ "$user_input" != "yes" ]; then
            echo "Operation cancelled."
            return
        fi
    fi

    # Overwrite the config.yml in ceremonyclient/.config with the altered version
    echo "Overwriting the config file in ceremonyclient..."
    cp "$ALTERED_CONFIG_FILE" "$SOURCE_CONFIG_FILE"

    if [ $? -eq 0 ]; then
        echo "config.yml has been successfully replaced."
    else
        echo "Error: Could not overwrite config.yml."
    fi
}

# Function to set up the master and modify the service file
setup_master() {
    echo "Setting up the master node..."

    # Define variables
    SETTINGS_FILE="/root/cm_settings.txt"  # Path to the cluster settings
    SERVICE_FILE="/etc/systemd/system/para.service"  # Path to the para service file
    PARA_SCRIPT_PATH="/root/ceremonyclient/node/para.sh"  # Path to the para.sh script

    # Step 1: Run the install_service script from GitHub
    echo "Running the install_service script..."
    curl -s https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/install_service | sudo bash

    # Step 2: Download para.sh from GitHub and overwrite the existing file
    echo "Downloading para.sh script..."
    curl -s -o "$PARA_SCRIPT_PATH" https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/para.sh

    # Verify if the script was downloaded successfully
    if [ -f "$PARA_SCRIPT_PATH" ]; then
        echo "para.sh script downloaded successfully to $PARA_SCRIPT_PATH."
        chmod +x "$PARA_SCRIPT_PATH"  # Make the script executable
    else
        echo "Error: Failed to download para.sh script."
        return 1  # Return 1 to indicate failure
    fi

    # Step 3: Read the first line of cm_settings.txt to extract the second value (thread count)
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Error: $SETTINGS_FILE not found."
        return 1  # Return 1 to indicate failure
    fi

    # Read the first line and extract the IP and thread count
    first_line=$(head -n 1 "$SETTINGS_FILE")
    master_ip=$(echo "$first_line" | awk '{print $1}')
    thread_count=$(echo "$first_line" | awk '{print $2}')

    echo "Master IP: $master_ip, Thread Count: $thread_count"

    # Step 4: Modify the ExecStart line in the service file
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Error: $SERVICE_FILE not found."
        return 1  # Return 1 to indicate failure
    fi

    # Find and echo the original ExecStart line
    original_execstart=$(grep '^ExecStart=' "$SERVICE_FILE")
    echo "Original ExecStart line: $original_execstart"

    # Modify the ExecStart line with the new thread count
    sudo sed -i "s|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 0 [0-9]* 1.4.21.1|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 0 $thread_count 1.4.21.1|" "$SERVICE_FILE"

    # Find and echo the modified ExecStart line
    modified_execstart=$(grep '^ExecStart=' "$SERVICE_FILE")
    echo "Modified ExecStart line: $modified_execstart"

    # Step 5: Reload the systemd daemon to apply changes
    sudo systemctl daemon-reload
    echo "Service file updated and systemd daemon reloaded."
}

