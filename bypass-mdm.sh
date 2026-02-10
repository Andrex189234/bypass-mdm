# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Fixed volume names
SYSTEM_VOL="macOS"
DATA_VOL="Data"

# Validate volumes
if [ ! -d "/Volumes/$SYSTEM_VOL" ]; then
	echo -e "${RED}ERROR: System volume '/Volumes/$SYSTEM_VOL' not found${NC}"
	exit 1
fi

if [ -d "/Volumes/macOS - Data" ]; then
	diskutil rename "macOS - Dati" "Dati" 2>/dev/null
fi

if [ ! -d "/Volumes/$DATA_VOL" ]; then
	echo -e "${RED}ERROR: Data volume not found${NC}"
	exit 1
fi

# Display header
echo -e "${CYAN}Bypass MDM By Assaf Dori (assafdori.com) fixed${NC}"
echo ""

# Prompt user for choice
PS3='Please enter your choice: '
options=("Bypass MDM from Recovery" "Reboot & Exit")
select opt in "${options[@]}"; do
	case $opt in

	"Bypass MDM from Recovery")
		echo -e "${YEL}Bypass MDM from Recovery${NC}"

		# Create Temporary User
		echo -e "${NC}Create a Temporary User${NC}"
		read -p "Enter Temporary Fullname (Default is 'Apple'): " realName
		realName="${realName:=Apple}"
		read -p "Enter Temporary Username (Default is 'Apple'): " username
		username="${username:=Apple}"
		read -p "Enter Temporary Password (Default is '1234'): " passw
		passw="${passw:=1234}"

		# Create User
		dscl_path="/Volumes/$DATA_VOL/private/var/db/dslocal/nodes/Default"
		echo -e "${GRN}Creating Temporary User${NC}"

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
		mkdir -p "/Volumes/$DATA_VOL/Users/$username"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
		dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
		dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"

		# Block MDM domains
		HOSTS="/Volumes/$SYSTEM_VOL/etc/hosts"
		touch "$HOSTS"

		grep -q deviceenrollment.apple.com "$HOSTS" || echo "0.0.0.0 deviceenrollment.apple.com" >>"$HOSTS"
		grep -q mdmenrollment.apple.com "$HOSTS" || echo "0.0.0.0 mdmenrollment.apple.com" >>"$HOSTS"
		grep -q iprofiles.apple.com "$HOSTS" || echo "0.0.0.0 iprofiles.apple.com" >>"$HOSTS"

		echo -e "${GRN}Successfully blocked MDM & Profile Domains${NC}"

		# Remove configuration profiles
		touch "/Volumes/$DATA_VOL/private/var/db/.AppleSetupDone"

		CFG="/Volumes/$SYSTEM_VOL/var/db/ConfigurationProfiles/Settings"
		mkdir -p "$CFG"

		rm -rf "$CFG/.cloudConfigHasActivationRecord"
		rm -rf "$CFG/.cloudConfigRecordFound"
		touch "$CFG/.cloudConfigProfileInstalled"
		touch "$CFG/.cloudConfigRecordNotFound"

		echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
		echo -e "${NC}Exit terminal and reboot your Mac.${NC}"
		break
		;;

	"Reboot & Exit")
		echo "Rebooting..."
		reboot
		break
		;;

	*)
		echo "Invalid option $REPLY"
		;;
	esac
done

