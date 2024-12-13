install_slaves_via_ssh() {
    INPUT_FILE="/root/cm_ip_pw.txt"

    # Check if the input file exists
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file $INPUT_FILE does not exist."
        return 1
    fi

    # Capture the output from the Install - Slaves steps.
    # We reuse the existing functions that print out the commands:
    script_install_cmds="$(generate_client_script_install_oneliner)"
    config_install_cmds="$(generate_simple_client_config_install_command)"

    # Combine both sets of commands into a single block
    combined_cmds="$script_install_cmds
$config_install_cmds"

    # Read the IP, username, and password from each line of INPUT_FILE
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines or commented lines
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi

        ip=$(echo "$line" | awk '{print $1}')
        username=$(echo "$line" | awk '{print $2}')
        password=$(echo "$line" | awk '{print $3}')

        echo "----------------------------------------"
        echo "Connecting to $ip as $username..."

        # Use sshpass and pipe the combined commands into ssh
        echo "$combined_cmds" | sshpass -p "$password" ssh -n -o StrictHostKeyChecking=no "$username@$ip" 'bash -s'

        if [ $? -eq 0 ]; then
            echo "✅ Successfully executed commands on $ip."
        else
            echo "❌ Failed to execute commands on $ip."
        fi

        echo "----------------------------------------"
        echo ""
    done < "$INPUT_FILE"
}
