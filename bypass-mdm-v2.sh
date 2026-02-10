#!/bin/bash

# =========================
# Color codes
# =========================
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# =========================
# Helper functions
# =========================
error_exit() {
	echo -e "${RED}ERROR: $1${NC}" >&2
	exit 1
}

warn() {
	echo -e "${YEL}WARNING: $1${NC}"
}

success() {
	echo -e "${GRN}✓ $1${NC}"
}

info() {
	echo -e "${BLU}ℹ $1${NC}"
}

# =========================
# Validation functions
# =========================
validate_username() {
	local username="$1"

	[ -z "$username" ] && echo "Username cannot be empty" && return 1
	[ ${#username} -gt 31 ] && echo "Username too long (max 31 characters)" && return 1
	! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] && \
		echo "Username must start with letter/_ and contain only letters, numbers, _ or -" && return 1

	return 0
}

validate_password() {
	local password="$1"

	[ -z "$password" ] && echo "Password cannot be empty" && return 1
	[ ${#password} -lt 4 ] && echo "Password too short (minimum 4 characters)" && return 1

	return 0
}

check_user_exists() {
	dscl -f "$1" localhost -read "/Local/Default/Users/$2" &>/dev/null
}

find_available_uid() {
	local dscl_path="$1"
	local uid=501

	while [ $uid -lt 600 ]; do
		if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID "$uid" | grep -q "$uid"; then
			echo "$uid"
			return 0
		fi
		uid=$((uid + 1))
	done

	echo "501"
}

# =========================
# Fixed volumes
# =========================
system_volume="macOS"
data_volume="macOS - Dati"

info "Using system volume: $system_volume"
info "Using data volume: $data_volume"

[ ! -d "/Volumes/$system_volume" ] && error_exit "System volume '/Volumes/macOS' not found"
[ ! -d "/Volumes/$data_volume" ] && error_exit "Data volume '/Volumes/macOS - Dati' not found"

system_path="/Volumes/$system_volume"
data_path="/Volumes/$data_volume"
dscl_path="$data_path/private/var/db/dslocal/nodes/Default"

[ ! -d "$dscl_path" ] && error_exit "Directory Services path not found"

# =========================
# Header
# =========================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM By Assaf Dori (assafdori.com)   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
success "System Volume: $system_volume"
success "Data Volume: $data_volume"
echo ""

# =========================
# Menu
# =========================
PS3='Please enter your choice: '
options=("Bypass MDM from Recovery" "Reboot & Exit")

select opt in "${options[@]}"; do
	case $opt in

	"Bypass MDM from Recovery")
		echo ""
		info "Starting MDM Bypass Process"
		echo ""

		# -------------------------
		# User creation
		# -------------------------
		read -p "Enter Temporary Fullname (Default: Apple): " realName
		realName="${realName:=Apple}"

		while true; do
			read -p "Enter Temporary Username (Default: Apple): " username
			username="${username:=Apple}"
			validation_msg=$(validate_username "$username") && break
			warn "$validation_msg"
		done

		check_user_exists "$dscl_path" "$username" && warn "User already exists, continuing anyway"

		while true; do
			read -p "Enter Temporary Password (Default: 1234): " passw
			passw="${passw:=1234}"
			validation_msg=$(validate_password "$passw") && break
			warn "$validation_msg"
		done

		uid=$(find_available_uid "$dscl_path")
		info "Using UID: $uid"

		info "Creating user account..."

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" || error_exit "Failed to create user"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$uid"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

		mkdir -p "$data_path/Users/$username"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
		dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
		dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

		success "User created successfully"
		echo ""

		# -------------------------
		# Block MDM domains
		# -------------------------
		info "Blocking MDM domains..."
		hosts="$system_path/etc/hosts"
		touch "$hosts"

		for domain in deviceenrollment.apple.com mdmenrollment.apple.com iprofiles.apple.com; do
			grep -q "$domain" "$hosts" || echo "0.0.0.0 $domain" >>"$hosts"
		done

		success "MDM domains blocked"
		echo ""

		# -------------------------
		# Configuration Profiles
		# -------------------------
		info "Applying MDM bypass markers..."

		config="$system_path/var/db/ConfigurationProfiles/Settings"
		mkdir -p "$config"

		touch "$data_path/private/var/db/.AppleSetupDone"
		rm -rf "$config/.cloudConfigHasActivationRecord"
		rm -rf "$config/.cloudConfigRecordFound"
		touch "$config/.cloudConfigProfileInstalled"
		touch "$config/.cloudConfigRecordNotFound"

		success "MDM bypass completed"
		echo ""

		echo -e "${GRN}Login after reboot with:${NC}"
		echo -e "User: ${YEL}$username${NC}"
		echo -e "Pass: ${YEL}$passw${NC}"
		echo ""
		break
		;;

	"Reboot & Exit")
		info "Rebooting system..."
		reboot
		break
		;;

	*)
		echo -e "${RED}Invalid option${NC}"
		;;
	esac
done

