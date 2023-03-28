# Port forwarding for ProtonVPN with Deluge in Docker

## Usage
1) Add https://github.com/jawilson/deluge-piaportplugin to your Deluge plugins
2) Expose `/pia/forwarded_port` in your Deluge container to the host
3) Add this container to your docker-compose.yml, and expose `/pia/forwarded_port` to this container
4) Set env var `VPN_CT_NAME` to the name of your ProtonVPN container
5) Set env var `VPN_IF_NAME` to the name of your ProtonVPN interface (usually `tun0`)
6) Set env var `VPN_GATEWAY` to the IP address of your `gluetun` container's gateway for the VPN. This is usually the endpoint itself.
7) Start up your containers

## Troubleshooting
Check the logs for this container: `docker logs -f <container name>`

If everything in there is fine, check `/pia/forwarded_port` on your Deluge container: `docker exec -it <container name> cat /pia/forwarded_port`

If you suspect a bug, open an issue on this repo.