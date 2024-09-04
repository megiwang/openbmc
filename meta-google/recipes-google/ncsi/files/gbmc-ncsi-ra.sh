#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RA_IF=$1
IP_OFFSET=1
# NCSI is known to be closer to the ToR than bridge routes. Prefer over bridge routes.
ROUTE_METRIC=900

has_bridge=1
# shellcheck source=meta-google/recipes-google/networking/gbmc-bridge/gbmc-br-lib.sh
source /usr/share/gbmc-br-lib.sh || has_bridge=

update_rtr() {
  busctl set-property xyz.openbmc_project.Network /xyz/openbmc_project/network/"$RA_IF" \
    xyz.openbmc_project.Network.EthernetInterface DefaultGateway6 s "" || true

  default_update_rtr "$@"
}

ncsi_is_active() {
  systemctl is-active -q nic-hostless@"$RA_IF".target && return
  systemctl is-active -q nic-hostful@"$RA_IF".target && return
  return 1
}

update_fqdn() {
  # We only do this for smartNICs (which don't use NCSI)
  ncsi_is_active && return

  default_update_fqdn "$@"
}

update_pfx() {
  local pfx="$1"

  # We only do this for smartNICs (which don't use NCSI)
  ncsi_is_active && return

  # Don't change anything for an empty prefix
  [ -z "$pfx" ] && return

  # We no longer need NCSId if we are in this configuration
  systemctl stop --no-block ncsid@"$RA_IF" || true

  # Save the IP address for the interface
  if [ -n "$has_bridge" ]; then
    gbmc_br_set_ip "$1" || true
    echo "IP $pfx set on $RA_IF" >&2
  fi

  # DHCP Relay workaround until alternate source port is supported
  # TODO: Remove this once internal relaying cleanups land
  gbmc-ncsi-smartnic-wa.sh || true
}

# shellcheck source=meta-google/recipes-google/networking/gbmc-net-common/gbmc-ra.sh
source /usr/share/gbmc-ra.sh || exit
