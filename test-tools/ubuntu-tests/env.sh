IMAGE="$URCHIN_IMG_ID"
TESTENV="./.current-run.env.sh"
FLAVOR_STD="n1.cw.standard-1"
FLAVOR_ALT="n1.cw.standard-2"
NETWORK="a8816f03-cace-4c39-904e-d3fafdbfbe86"
FLOATING_IP_POOL="6ea98324-0f14-49f6-97c0-885d1b8dc517"
KEYPAIR="jenkins-ci"
PRIVATE_KEY="/var/lib/jenkins/.ssh/jenkins-ci.pem"
SSH_USER="cloud"
HOST="google.com"
LOG_FILE="/dev/null"
USER_DATA_FILE="./userdata.txt"

if [ -f "$TESTENV" ]; then
    . $TESTENV
fi
