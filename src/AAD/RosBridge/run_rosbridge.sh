#!/usr/bin/env bash

set -e

# Adjust ROS_DISTRO and WORKSPACE_INSTALL if needed.
ROS_DISTRO="${ROS_DISTRO:-humble}"          # or set by cmake/config
WORKSPACE_INSTALL="$(dirname "$(realpath "$0")")/install"  # relative install from package source dir

# source global ROS
if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

# source workspace (if exists)
if [ -f "${WORKSPACE_INSTALL}/setup.bash" ]; then
  source "${WORKSPACE_INSTALL}/setup.bash"
fi

exec bash -lc "exec ros2 run rosbridge RosBridgeNode"
