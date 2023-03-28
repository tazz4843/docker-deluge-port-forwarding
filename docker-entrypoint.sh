#!/bin/bash

# timestamp function
timestamp() {
  date "+%D %T"
}

pre_reqs() {
  while read -r var; do
    [ -z "${!var}" ] && { echo "$(timestamp) | ${var} is empty or not set."; exit 1; }
  done << EOF
VPN_CT_NAME
VPN_IF_NAME
EOF

  [ ! -S /var/run/docker.sock ] && { echo "$(timestamp) | Docker socket doesn't exist or is inaccessible"; exit 2; }

  return 0
}

# Function to add firewall rules allowing P2P traffic on the VPN interface through the port we forwarded
add_rules() {
  if ! (docker exec "${VPN_CT_NAME}" /sbin/iptables -L INPUT -n | grep -qP "^ACCEPT.*${active_port}.*"); then
    docker exec "${VPN_CT_NAME}" /sbin/iptables -A INPUT -i "${VPN_IF_NAME}" -p tcp --dport "${active_port}" -j ACCEPT
    docker exec "${VPN_CT_NAME}" /sbin/iptables -A INPUT -i "${VPN_IF_NAME}" -p udp --dport "${active_port}" -j ACCEPT
    return 0
  else
    return 1
  fi
}

# Remove the above rules
# Takes one argument, the port to remove
delete_rules() {
  if (docker exec "${VPN_CT_NAME}" /sbin/iptables -L INPUT -n | grep -qP "^ACCEPT.*${configured_port}.*"); then
    docker exec "${VPN_CT_NAME}" /sbin/iptables -D INPUT -i "${VPN_IF_NAME}" -p tcp --dport "${configured_port}" -j ACCEPT
    docker exec "${VPN_CT_NAME}" /sbin/iptables -D INPUT -i "${VPN_IF_NAME}" -p udp --dport "${configured_port}" -j ACCEPT
  fi
}

# Renew or create the port forwarding rule, and set the active_port variable
renew_port() {
  # Renew the port
  natpmpc -g "${vpn_gateway}" -a 0 0 udp 60 | grep "public port" | awk '{print $4}' > /tmp/active_port || {
    echo "$(timestamp) | Failed to renew port, trying again next round"
    return 1
  }
  # A TCP port assignment will assign the same port as UDP, so we can just use the same file
  natpmpc -g "${vpn_gateway}" -a 0 0 tcp 60

  active_port=$(cat /tmp/active_port)
  configured_port=$(cat /pia/forwarded_port 2>/dev/null || echo "0")
  echo "$(timestamp) | Active port: ${active_port}, Configured port: ${configured_port}"

  if [ "${active_port}" != "${configured_port}" ]; then
    echo "${active_port}" > /pia/forwarded_port
    echo "$(timestamp) | Port changed from ${configured_port} to ${active_port}"
    # Delete the old rules
    delete_rules "${configured_port}"
    # Add the new rules
    add_rules
  fi
}

# Get the port for the first time
get_port() {
    # Gateway may be randomly assigned, so we need to try to get it every time
  for i in {0..256} ; do
    vpn_gateway="10.$i.0.1"
    # natpmpc does not return a non-zero exit code on failure, so we need to check the output
    # if it does not contain "FAILED", then we can assume it worked
    # it also hangs randomly, so we need to timeout after 10 seconds
    cmd="natpmpc -g ${vpn_gateway} -a 0 0 udp 60 2>&1 | grep -q \"FAILED\""
    if ! timeout 10 bash -c "${cmd}"; then
      break
    fi
  done
  if [ "${i}" -eq 256 ]; then
    echo "$(timestamp) | Failed to get VPN gateway"
    exit 3
  fi
  echo "$(timestamp) | VPN gateway: ${vpn_gateway}"
  natpmpc -g "${vpn_gateway}" -a 0 0 tcp 60
}

# Wrap all of this up
main() {
  echo "$(timestamp) | Starting port forwarding script"
  pre_reqs
  get_port
  # Port forwarding rules expire after 60 seconds, so try to renew every 30 seconds
  while true; do
    renew_port
    sleep 30
  done
}

main
