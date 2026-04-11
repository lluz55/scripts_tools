# set-net.sh

This script is used to configure network interfaces with static IP addresses and manage network profiles.

## Usage

```bash
./set-net.sh <command> [arguments...]
```

### Commands

*   `set <profile>`: Applies a saved network profile.
*   `set <ip> <cidr> <gw> [-i <if>]`: Applies a manual network configuration.
*   `save <profile> <ip> <cidr> <gw> [-i <if>]`: Saves a new network profile.
*   `list`: Lists all saved profiles.
*   `delete <profile>`: Deletes a saved profile.
*   `help`: Shows the help menu.

### Examples

```bash
# Save a new profile named "home"
./set-net.sh save home 192.168.1.50 24 192.168.1.1

# Apply the "home" profile (requires sudo)
sudo ./set-net.sh set home

# Apply a manual configuration to the eth1 interface (requires sudo)
sudo ./set-net.sh set 10.0.0.99 8 10.0.0.1 -i eth1

# List all saved profiles
./set-net.sh list
```
