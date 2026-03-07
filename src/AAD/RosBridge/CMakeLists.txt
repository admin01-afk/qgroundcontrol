cmake_minimum_required(VERSION 4.1.2)
project(rosbridge)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_srvs REQUIRED)

# main executable
add_executable(RosBridgeNode src/RosBridgeNode.cc)
ament_target_dependencies(RosBridgeNode rclcpp std_srvs)

install(TARGETS
    RosBridgeNode
    DESTINATION lib/rosbridge
)

ament_package()
