# ============================================================================
# ROS 2 Support (REQUIRED)
# ============================================================================

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)
find_package(rclcpp REQUIRED)
find_package(std_srvs REQUIRED)
find_package(rcl_interfaces REQUIRED)

message(STATUS "✓ ROS 2 packages found - RosBridgeNode has full ROS 2 support")

# Use direct path to ROS installation
set(ROS_ROOT "/opt/ros/humble")
set(RCLCPP_LIBRARY "${ROS_ROOT}/lib/librclcpp.so")

if(EXISTS "${RCLCPP_LIBRARY}")
    message(STATUS "  Found rclcpp library: ${RCLCPP_LIBRARY}")
else()
    message(FATAL_ERROR "  FATAL: rclcpp library not found at ${RCLCPP_LIBRARY}")
endif()

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
)

target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/server
        ${CMAKE_CURRENT_SOURCE_DIR}/kamikaze
        ${CMAKE_CURRENT_SOURCE_DIR}/RosBridge/src
)

# ============================================================================
# RosBridgeNode Implementation - ROS 2 Required
# ============================================================================

if(TRUE)
    message(STATUS "Setting up ROS build for RosBridgeNode...")

    # Create object library isolated from MOC
    add_library(RosBridgeNode_impl OBJECT
        RosBridge/src/RosBridgeNode.cc
    )

    # Disable MOC for this object library - we don't want Qt MOC processing
    set_target_properties(RosBridgeNode_impl PROPERTIES
        AUTOMOC OFF
        AUTORCC OFF
        AUTOUIC OFF
    )

    # Include paths for ROS headers and Qt headers
    # Must include /opt/ros/humble/include directly to resolve inter-package dependencies
    target_include_directories(RosBridgeNode_impl
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/RosBridge/src
            ${rclcpp_INCLUDE_DIRS}
            ${std_srvs_INCLUDE_DIRS}
            /opt/ros/humble/include
            /opt/ros/humble/include/rcl_interfaces
            /opt/ros/humble/include/rcl_interfaces/rcl_interfaces
            ${Qt6Core_INCLUDE_DIRS}
    )

    # Compile with ROS enabled
    target_compile_definitions(RosBridgeNode_impl
        PRIVATE
            ROSBRIDGE_ENABLE_ROS=1
    )

    # Set C++ standard
    set_target_properties(RosBridgeNode_impl PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
    )

    # Find all ROS libraries needed by rclcpp
    set(ROS_ROOT "/opt/ros/humble")
    find_library(RCUTILS_LIB rcutils PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(RCL_LIB rcl PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(RCPPUTILS_LIB rcpputils PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(ROSIDL_TYPESUPPORT_CPP_LIB rosidl_typesupport_cpp PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(ROSIDL_TYPESUPPORT_FASTRTPS_CPP_LIB rosidl_typesupport_fastrtps_cpp PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(RMW_IMPLEMENTATION_LIB rmw_implementation PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(AMENT_INDEX_CPP_LIB ament_index_cpp PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(STATISTICS_COLLECTOR_LIB libstatistics_collector PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(RCL_YAML_PARAM_PARSER_LIB rcl_yaml_param_parser PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(TRACETOOLS_LIB tracetools PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(RMW_LIB rmw PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)

    # Find std_srvs type support libraries
    find_library(STD_SRVS_TYPESUPPORT_CPP_LIB std_srvs__rosidl_typesupport_cpp PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)
    find_library(STD_SRVS_TYPESUPPORT_FASTRTPS_CPP_LIB std_srvs__rosidl_typesupport_fastrtps_cpp PATHS ${ROS_ROOT}/lib NO_DEFAULT_PATH)

    # Build list of found libraries
    set(ROS_LIBS_TO_LINK ${RCLCPP_LIBRARY})
    if(RCUTILS_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RCUTILS_LIB})
    endif()
    if(RCL_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RCL_LIB})
    endif()
    if(RCPPUTILS_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RCPPUTILS_LIB})
    endif()
    if(ROSIDL_TYPESUPPORT_CPP_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${ROSIDL_TYPESUPPORT_CPP_LIB})
    endif()
    if(ROSIDL_TYPESUPPORT_FASTRTPS_CPP_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${ROSIDL_TYPESUPPORT_FASTRTPS_CPP_LIB})
    endif()
    if(RMW_IMPLEMENTATION_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RMW_IMPLEMENTATION_LIB})
    endif()
    if(AMENT_INDEX_CPP_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${AMENT_INDEX_CPP_LIB})
    endif()
    if(STATISTICS_COLLECTOR_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${STATISTICS_COLLECTOR_LIB})
    endif()
    if(RCL_YAML_PARAM_PARSER_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RCL_YAML_PARAM_PARSER_LIB})
    endif()
    if(TRACETOOLS_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${TRACETOOLS_LIB})
    endif()
    if(RMW_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${RMW_LIB})
    endif()
    if(STD_SRVS_TYPESUPPORT_CPP_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${STD_SRVS_TYPESUPPORT_CPP_LIB})
    endif()
    if(STD_SRVS_TYPESUPPORT_FASTRTPS_CPP_LIB)
        list(APPEND ROS_LIBS_TO_LINK ${STD_SRVS_TYPESUPPORT_FASTRTPS_CPP_LIB})
    endif()

    # Link libraries to object library
    if(RCLCPP_LIBRARY AND RCUTILS_LIB AND RCL_LIB)
        target_link_libraries(RosBridgeNode_impl
            PRIVATE
                ${ROS_LIBS_TO_LINK}
        )
        message(STATUS "✓ Linked ROS libraries to RosBridgeNode_impl")
    endif()

    # Add the compiled object files to main target
    target_sources(${CMAKE_PROJECT_NAME}
        PRIVATE
            $<TARGET_OBJECTS:RosBridgeNode_impl>
    )

    # Also link libraries to main executable for final linking
    target_link_libraries(${CMAKE_PROJECT_NAME}
        PRIVATE
            ${ROS_LIBS_TO_LINK}
    )

    message(STATUS "✓ ROS 2 object library configured with full dependencies")
endif()
