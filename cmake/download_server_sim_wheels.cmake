if(NOT DEFINED SERVER_SIM_DIR OR NOT DEFINED SERVER_SIM_WHEELHOUSE OR NOT DEFINED Python3_EXECUTABLE)
    message(FATAL_ERROR "Missing required variables for server_sim wheel download")
endif()

file(GLOB existing_wheels "${SERVER_SIM_WHEELHOUSE}/*.whl")

if(existing_wheels)
    message(STATUS "Wheelhouse already populated, skipping download.")
    return()
endif()

message(STATUS "Downloading Python wheels...")

execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pip download
            -r "${SERVER_SIM_DIR}/requirements.txt"
            -d "${SERVER_SIM_WHEELHOUSE}"
    WORKING_DIRECTORY "${SERVER_SIM_DIR}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
)

message(STATUS "=== pip output ===\n${out}")
message(STATUS "=== pip errors ===\n${err}")

if(NOT result EQUAL 0)
    message(FATAL_ERROR "Failed to download server_sim wheels (see above pip errors)")
endif()