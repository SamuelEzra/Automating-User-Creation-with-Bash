#!/bin/bash

# Variables
user_file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.csv"

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if user file is available
if [[ -z "$1" ]]; then
    echo "Use: $0 users.txt file"
    exit 1
fi

# Function to generate a random password
generate_password() {
    local length=12
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c ${length} || return 1
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

# Create password folder
mkdir -p /var/secure
chmod 700 /var/secure

# Create password file
touch "$password_file"
chmod 600 "$password_file"

# Create logging file
touch "$log_file"
chmod 600 "$log_file"

# Read each line from input file and process
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs) # Remove leading/trailing whitespace
    groups=$(echo "$groups" | xargs)     # Remove leading/trailing whitespace

    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_message "User $username already exists."
        continue
    fi

    # Create user
    useradd -m "$username"
    log_message "User $username created."

    # Generate and set password for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> "$password_file" 
    log_message "Password set for user $username."


    # Check and create groups
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        # Create the group if it doesn't exist
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            log_message "Group $group created."
        fi


        # Add the user to the group
        usermod -aG "$group" "$username"
        log_message "User $username added to group $group."

    done

done < "$user_file"

#Log the completion of the user creation process
echo "User creation process completed." | tee -a $log_file