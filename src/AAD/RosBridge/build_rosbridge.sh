#!/bin/bash
set -e  # stop on first error
source /opt/ros/humble/setup.bash
rm -rf build/ install/ log/
colcon build --packages-select rosbridge --merge-install
