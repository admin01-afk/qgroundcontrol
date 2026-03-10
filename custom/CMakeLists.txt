# ============================================================================
# QGroundControl Custom Plugin Example
# Template for building custom QGroundControl plugins
# ============================================================================

message(STATUS "QGC: Adding Custom Plugin")

# ============================================================================
# Custom Resources and Import Paths
# ============================================================================

# Add custom Qt resources
list(APPEND CUSTOM_RESOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc
)
set(QGC_RESOURCES ${QGC_RESOURCES} ${CUSTOM_RESOURCES} CACHE STRING "Paths to .qrc Resources" FORCE)

# Add custom QML import path
set(QML_IMPORT_PATH ${QML_IMPORT_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/res" CACHE STRING "Extra qml import paths" FORCE)

# ============================================================================
# Custom QML Module
# ============================================================================

qt_add_library(CustomModule STATIC)

# Set resource aliases for custom widgets
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomArtificialHorizon.qml PROPERTIES QT_RESOURCE_ALIAS CustomArtificialHorizon.qml)
qgc_set_qt_resource_alias(
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomAttitudeWidget.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomIconButton.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomOnOffSwitch.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomQuickButton.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomSignalStrength.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomToolBarButton.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomVehicleButton.qml
)

qt_add_qml_module(CustomModule
    URI Custom.Widgets
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomArtificialHorizon.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomAttitudeWidget.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomIconButton.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomOnOffSwitch.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomQuickButton.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomSignalStrength.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomToolBarButton.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/res/Custom/Widgets/CustomVehicleButton.qml
    NO_PLUGIN
)

# ============================================================================
# Custom Plugin Sources
# ============================================================================

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    CACHE INTERNAL "" FORCE
)

# ============================================================================
# Custom Build Configuration
# ============================================================================

# Custom libraries to link
set(CUSTOM_LIBRARIES
    CustomModule
    CACHE INTERNAL "" FORCE
)

# Custom include directories
set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    CACHE INTERNAL "" FORCE
)

# Custom compiler definitions
set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
    CACHE INTERNAL "" FORCE
)

# Custom Qt components required
set(CUSTOM_QT_COMPONENTS
    Core
    CACHE INTERNAL "" FORCE
)
