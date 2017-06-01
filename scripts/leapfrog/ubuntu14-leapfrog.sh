#!/usr/bin/env bash
# Copyright 2017, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

## Shell Opts ----------------------------------------------------------------
set -e -u -x
set -o pipefail

## Standard Vars --------------------------------------------------------------
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export OA_DEFAULTS='/etc/openstack_deploy/user_osa_variables_defaults.yml'
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_DEFAULTS='/etc/openstack_deploy/user_rpco_variables_defaults.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'
export RPCO_DEFAULT_FOLDER="/opt/rpc-openstack"

## Leapfrog Vars ----------------------------------------------------------------------
# BASE_DIR is where KILO is. It's the standard variable inherited from other jobs.
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
# Location of the leapfrog tooling (where we'll do our checkouts and move the
# code at the end)
export NEWTON_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"
# Temp location for the code and config files backups.
export LEAPFROG_DIR=${LEAPFROG_DIR:-"/opt/rpc-leapfrog"}
# OSA leapfrog tooling location
export OA_OPS_REPO=${OA_OPS_REPO:-'https://github.com/openstack/openstack-ansible-ops.git'}
# Please bump the following when a patch for leapfrog is merged into osa-ops
# If you are developping, just clone your ops repo into (by default)
# /opc/rpc-leapfrog/osa-ops-leapfrog
export OA_OPS_REPO_BRANCH=${OA_OPS_REPO_BRANCH:-'b95e3c55f5e4dab0dc17c2e62d27e9665724c6c4'}
# Instead of storing the debug's log of run in /tmp, we store it in an
# folder that will get archived for gating logs
export DEBUG_PATH="/var/log/osa-leapfrog-debug.log"
export UPGRADE_LEAP_MARKER_FOLDER="/etc/openstack_deploy/upgrade-leap"

### Gating vars
# In gates, force the skip of the input validation.
# export VALIDATE_UPGRADE_INPUT=False

# In gates, ensure the following variables are set:
# neutron_legacy_ha_tool_enabled: yes >> /etc/openstack_deploy/user_variables.yml
# lxc_container_backing_store: dir >> /etc/openstack_deploy/user_variables.yml

### Functions -----------------------------------------------------------------

function log {
    echo "Task: $1 status: $2" >> ${DEBUG_PATH}
    if [[ "$2" == "ok" ]]; then
      touch /etc/openstack_deploy/upgrade-leap/${1}.complete
    fi
}

### Main ----------------------------------------------------------------------

# Setup the base work folders
if [[ ! -d ${LEAPFROG_DIR} ]]; then
  mkdir -p ${LEAPFROG_DIR}
fi

if [[ ! -d "${UPGRADE_LEAP_MARKER_FOLDER}" ]]; then
    mkdir -p "${UPGRADE_LEAP_MARKER_FOLDER}"
fi

# Let's go
pushd ${LEAPFROG_DIR}

  # Get the OSA LEAPFROG
  if [[ ! -d "osa-ops-leapfrog" ]]; then
      git clone ${OA_OPS_REPO} osa-ops-leapfrog
      pushd osa-ops-leapfrog
          git checkout ${OA_OPS_REPO_BRANCH}
      popd
      log "clone" "ok"
  fi

  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/rpc-prep.complete" ]]; then
    if [[ ${NEWTON_BASE_DIR} != ${RPCO_DEFAULT_FOLDER} ]]; then
      # Cleanup existing RPC, replace with new RPC
      if [[ -d ${RPCO_DEFAULT_FOLDER} ]]; then
        mv ${RPCO_DEFAULT_FOLDER} ${LEAPFROG_DIR}/rpc-openstack.pre-newton
        cp -r ${NEWTON_BASE_DIR} ${RPCO_DEFAULT_FOLDER}
      fi
    fi
    log "rpc-prep" "ok"
  else
    log "rpc-prep" "skipped"
  fi

  if [[ ! -f "${UPGRADE_LEAP_MARKER_FOLDER}/osa-leap.complete" ]]; then
    pushd osa-ops-leapfrog/leap-upgrades/
      ./run-stages.sh
    popd
    log "osa-leap" "ok"
  else
    log "osa-leap" "skipped"
  fi
popd