#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to log messages
log_message() {
  message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOG_FILE
}

# Function to create a group
create_group() {
  group_name=$1
  if ! grep -q "^$group_name:" /etc/group; then
    if groupadd $group_name; then
      log_message "Group $group_name created."
    else
      log_message "Error creating group $group_name."
    fi
  else
    log_message "Group $group_name already exists."
  fi
}

# Function to create a user and assign to a group
create_user() {
  username=$1
  group_name=$2
  if ! id -u $username >/dev/null 2>&1; then
    if useradd -m -g $group_name -s /bin/bash $username; then
      log_message "User $username created and added to group $group_name."
    else
      log_message "Error creating user $username."
    fi
  else
    log_message "User $username already exists."
  fi
}

# Function to set permissions and ownership for the home directory
set_permissions() {
  username=$1
  home_dir="/home/$username"
  if chown $username:$username $home_dir && chmod 700 $home_dir; then
    log_message "Permissions set for $home_dir."
  else
    log_message "Error setting permissions for $home_dir."
  fi
}

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Function to set the password for a user
set_password() {
  username=$1
  password=$(generate_password)
  if echo "$username:$password" | chpasswd; then
    log_message "Password set for user $username."
    echo "$username:$password" >> $PASSWORD_FILE
  else
    log_message "Error setting password for user $username."
  fi
}

# Ensure the password file exists and set appropriate permissions
if touch $PASSWORD_FILE && chmod 600 $PASSWORD_FILE && chown root:root $PASSWORD_FILE; then
  log_message "Password file created and secured."
else
  log_message "Error creating or securing the password file."
  exit 1
fi

# Prompt for groups
read -p "Enter the groups (separated by spaces): " -a groups

# Create groups
for group in "${groups[@]}"; do
  create_group $group
done

# Prompt for users and their groups
while true; do
  read -p "Enter username: " username
  read -p "Enter group for $username: " group
  create_user $username $group
  set_permissions $username
  set_password $username

  read -p "Do you want to add another user? (yes/no): " choice
  if [[ "$choice" != "yes" ]]; then
    break
  fi
done

log_message "Script completed."
