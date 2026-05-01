# ============================================================================
# ROS 2 Support (REQUIRED)
# ============================================================================

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)
find_package(Qt6 REQUIRED COMPONENTS Core Positioning Network)
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_srvs REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(rcl_interfaces REQUIRED)
find_package(type_description_interfaces REQUIRED)
find_package(rosidl_runtime_cpp REQUIRED)
find_package(mavros_msgs REQUIRED)
find_package(savasan_general REQUIRED)

message(STATUS "✓ ROS 2 packages found - RosBridgeNode has full ROS 2 support")

# ============================================================================
# Core AAD sources
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        server/ServerManager.cc
        server/ServerManager.h
        server/TelemPlaneDataModel.cc
        server/TelemPlaneDataModel.h
        kamikaze/KamikazeLocManager.cc
        kamikaze/KamikazeLocManager.h
        RosBridge/src/RosBridgeNode.h
        RosBridge/src/RosImageProvider.cc
        RosBridge/src/RosImageProvider.h
)

target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/server
        ${CMAKE_CURRENT_SOURCE_DIR}/kamikaze
        ${CMAKE_CURRENT_SOURCE_DIR}/RosBridge/src
)

# Copy server_sim folder next to the binary
install(DIRECTORY
    ${CMAKE_SOURCE_DIR}/src/AAD/server_sim
    DESTINATION bin
)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(SERVER_SIM_DIR ${CMAKE_SOURCE_DIR}/src/AAD/server_sim)
set(SERVER_SIM_WHEELHOUSE ${SERVER_SIM_DIR}/wheelhouse)
set(SERVER_SIM_WHEEL_STAMP ${SERVER_SIM_WHEELHOUSE}/.wheels_ready)

add_custom_command(
    OUTPUT ${SERVER_SIM_WHEEL_STAMP}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${SERVER_SIM_WHEELHOUSE}
    COMMAND ${CMAKE_COMMAND}
            -DSERVER_SIM_DIR=${SERVER_SIM_DIR}
            -DSERVER_SIM_WHEELHOUSE=${SERVER_SIM_WHEELHOUSE}
            -DPython3_EXECUTABLE=${Python3_EXECUTABLE}
            -P ${CMAKE_SOURCE_DIR}/cmake/download_server_sim_wheels.cmake
    COMMAND ${CMAKE_COMMAND} -E touch ${SERVER_SIM_WHEEL_STAMP}
    WORKING_DIRECTORY ${SERVER_SIM_DIR}
    COMMENT "Downloading Python wheels for offline server_sim"
)

add_custom_target(server_sim_wheels DEPENDS ${SERVER_SIM_WHEEL_STAMP})
add_dependencies(${CMAKE_PROJECT_NAME} server_sim_wheels)

# ============================================================================
# RosBridgeNode Implementation - ROS 2 Required
# ============================================================================

add_library(RosBridgeNode_impl STATIC
    RosBridge/src/RosBridgeNode.cc
)

set_target_properties(RosBridgeNode_impl PROPERTIES
    AUTOMOC OFF
    AUTORCC OFF
    AUTOUIC OFF
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
)

target_compile_definitions(RosBridgeNode_impl
    PRIVATE
        ROSBRIDGE_ENABLE_ROS=1
)

target_include_directories(RosBridgeNode_impl
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/RosBridge/src
        ${rclcpp_INCLUDE_DIRS}
        ${std_srvs_INCLUDE_DIRS}
        ${sensor_msgs_INCLUDE_DIRS}
        ${rcl_interfaces_INCLUDE_DIRS}
        ${type_description_interfaces_INCLUDE_DIRS}
        ${rosidl_runtime_cpp_INCLUDE_DIRS}
        ${savasan_general_INCLUDE_DIRS}
)

ament_target_dependencies(RosBridgeNode_impl
    rclcpp
    std_srvs
    sensor_msgs
    rcl_interfaces
    type_description_interfaces
    rosidl_runtime_cpp
    mavros_msgs
    savasan_general
)

# rclcpp carries the ROS runtime link requirements; the interface packages are
# used for headers and generated service types.
target_link_libraries(RosBridgeNode_impl
    ${rclcpp_LIBRARIES}
    ${std_srvs_LIBRARIES}
    ${sensor_msgs_LIBRARIES}
    ${rcl_interfaces_LIBRARIES}
    ${type_description_interfaces_LIBRARIES}
    rosidl_runtime_cpp::rosidl_runtime_cpp
    Qt6::Core
    Qt6::Positioning
    Qt6::Network
)

# Final link against rclcpp for the main executable.
target_link_libraries(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${rclcpp_LIBRARIES}
        ${std_srvs_LIBRARIES}
        ${sensor_msgs_LIBRARIES}
        ${rcl_interfaces_LIBRARIES}
        ${type_description_interfaces_LIBRARIES}
        rosidl_runtime_cpp::rosidl_runtime_cpp
)

# Add the compiled object files to the main target.
target_link_libraries(${CMAKE_PROJECT_NAME}
    PRIVATE
        RosBridgeNode_impl
)
