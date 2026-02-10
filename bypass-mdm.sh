#!/bin/bash

# =========================
# Color codes
# =========================
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# =========================
# Fixed volume names
# =========================
SYSTEM_VOL="macOS"
DATA_VOL="macOS - Dati"

# =========================
# Validate volumes
# =========================
if [ ! -d "/Volumes/$SYSTEM_VOL" ]; then
	echo -e "${RED}ERROR: System volume '/Volumes/$SYSTEM_VOL' not found${NC}"
	exit 1
fi

if [ ! -d "/Volumes/$DATA_VOL" ]; then
	echo -e "${RED}ERROR: Data volume '/Volumes/$DATA_VOL' not found${NC}"
	exit 1
fi

SYSTEM_PATH="/Volumes/$SYSTEM_VOL"
DATA_PATH="/Volumes/$DATA_VOL"
DSCL_PATH="$DATA_PATH/private/var/db/dslocal/nodes/Default"

if [ ! -d "$DSCL_PATH" ]; then
	echo -e "${RED}ERROR: Directory Services path not found${NC}"
	exit 1
fi

# =========================
# Header
# =========================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM By Assaf Dori (assafdori.com)   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GRN}System Volume:${NC} $SYSTEM_VOL"
echo -e "${GRN}Data Volume:${NC}   $DATA_VOL"
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
		echo -e "${YEL}Bypass MDM from Recovery${NC}"
		echo ""

		# -------------------------
		# Temporary user creation
		# -------------------------
		read -p "Enter Temporary Fullname (Default: Apple): " realName
		realName="${realName:=Apple}"

		read -p "Enter Temporary Username (Default: Apple): " username
		username="${username:=Apple}"

		read -p "Enter Temporary Password (Default: 1234): " passw
		passw="${passw:=1234}"

		echo ""
		echo -e "${GRN}Creating Temporary User${NC}"

		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username"
		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username" RealName "$realName"
		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username" UniqueID "501"
		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"

		mkdir -p "$DATA_PATH/Users/$username"
		dscl -f "$DSCL_PATH" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
		dscl -f "$DSCL_PATH" localhost -passwd "/Local/Default/Users/$username" "$passw"
		dscl -f "$DSCL_PATH" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

		echo -e "${GRN}Temporary user created successfully${NC}"
		echo ""

		# -------------------------
		# Block MDM domains
		# -------------------------
		echo -e "${BLU}Blocking MDM domains...${NC}"

		HOSTS="$SYSTEM_PATH/etc/hosts"
		touch "$HOSTS"

		for domain in deviceenrollment.apple.com mdmenrollment.apple.com iprofiles.apple.com; do
			grep -q "$domain" "$HOSTS" || echo "0.0.0.0 $domain" >>"$HOSTS"
		done

		echo -e "${GRN}Successfully blocked MDM & Profile Domains${NC}"
		echo ""

		# -------------------------
		# Configuration Profiles
		# -------------------------
		touch "$DATA_PATH/private/var/db/.AppleSetupDone"

		CFG="$SYSTEM_PATH/var/db/ConfigurationProfiles/Settings"
		mkdir -p "$CFG"

		rm -rf "$CFG/.cloudConfigHasActivationRecord"
		rm -rf "$CFG/.cloudConfigRecordFound"
		touch "$CFG/.cloudConfigProfileInstalled"
		touch "$CFG/.cloudConfigRecordNotFound"

		echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
		echo ""
		echo -e "${YEL}Login after reboot with:${NC}"
		echo -e "User: ${PUR}$username${NC}"
		echo -e "Pass: ${PUR}$passw${NC}"
		echo ""
		break
		;;

	"Reboot & Exit")
		echo -e "${BLU}Rebooting...${NC}"
		reboot
		break
		;;

	*)
		echo -e "${RED}Invalid option${NC}"
		;;
	esac
done
