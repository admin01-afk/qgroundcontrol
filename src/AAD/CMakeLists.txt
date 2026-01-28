# ============================================================================
#
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        server/ServerManager.cc
        server/ServerManager.h
        server/TelemPlaneDataModel.cc
        server/TelemPlaneDataModel.h
        kamikaze/KamikazeLocManager.cc
        kamikaze/KamikazeLocManager.h
)

target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/server
        ${CMAKE_CURRENT_SOURCE_DIR}/kamikaze
)
