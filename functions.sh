set_cluster() {
    echo "Enter your cluster details (IP and threads per IP), one per line."
    echo "Format: <IP> <Threads>"
    echo "When you are done, press Enter on an empty line."

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

# Function to back up and set the config
backup_and_setconfig() {
    echo "Backing up and setting config..."

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

    # Print debug information
    echo "DEBUG: Contents of config_block.txt:"
    echo "$config_block"
    echo "DEBUG: Replacing dataWorkerMultiaddrs block in config.yml..."

    # Build the new dataWorkerMultiaddrs block
    data_worker_multiaddrs_block="  dataWorkerMultiaddrs: [\n${config_block}\n  ]"

    # Use awk to replace the block
    awk -v new_block="$data_worker_multiaddrs_block" '
        BEGIN { found = 0 }
        /dataWorkerMultiaddrs:/ { found = 1 }
        found && /\]/ { found = 0; print new_block; next }
        !found { print }
    ' "$BACKUP_CONFIG_FILE" > "$ALTERED_CONFIG_FILE"

    # Print debug info showing the result of the change
    echo "DEBUG: Showing the relevant section of the altered config.yml:"
    sed -n '/dataWorkerMultiaddrs:/,/provingKeyId/p' "$ALTERED_CONFIG_FILE"

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

    # Step 1: Run the install_service script from GitHub
    echo "Running the install_service script..."
    curl -s https://raw.githubusercontent.com/qrux-opterator/clustermaster/main/install_service | sudo bash

    # Step 2: Read the first line of cm_settings.txt to extract the second value (thread count)
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Error: $SETTINGS_FILE not found."
        return
    fi

    # Read the first line and extract the second value (thread count)
    first_line=$(head -n 1 "$SETTINGS_FILE")
    master_ip=$(echo "$first_line" | awk '{print $1}')
    thread_count=$(echo "$first_line" | awk '{print $2}')

    echo "Master IP: $master_ip, Thread Count: $thread_count"

    # Step 3: Modify the ExecStart line in the service file
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Error: $SERVICE_FILE not found."
        return
    fi

    # Find and echo the original ExecStart line
    original_execstart=$(grep '^ExecStart=' "$SERVICE_FILE")
    echo "Original ExecStart line: $original_execstart"

    # Modify the ExecStart line with the new thread count
    sudo sed -i "s|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 0 [0-9]* 1.4.21.1|ExecStart=/bin/bash /root/ceremonyclient/node/para.sh linux amd64 0 $thread_count 1.4.21.1|" "$SERVICE_FILE"

    # Find and echo the modified ExecStart line
    modified_execstart=$(grep '^ExecStart=' "$SERVICE_FILE")
    echo "Modified ExecStart line: $modified_execstart"

    # Step 4: Reload the systemd daemon to apply changes
    sudo systemctl daemon-reload
    echo "Service file updated and systemd daemon reloaded."
}
