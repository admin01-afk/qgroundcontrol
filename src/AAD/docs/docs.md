# Docs
## QGroundControl dev aliases 
### put in your ~/.bashrc
```
# -------------------------------
# QGroundControl dev aliases
# -------------------------------

# ⚠️ Set your Qt path here (recommended version 6.10.1)
QGC_QT_DIR="$HOME/Qt/6.10.0/gcc_64/lib/cmake/Qt6"

# Configure project (Debug/RelWithDebInfo)
qgc-configure() {
    cd ~/qgroundcontrol || return

    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DQt6_DIR="$QGC_QT_DIR"
}

# Clean + configure + build
qgc-clean-build() {
    JOBS=$(( $(nproc) > 4 ? $(nproc) - 4 : 1 ))
    cd ~/qgroundcontrol || return
    rm -rf build

    qgc-configure || return
    ninja -C build -j $JOBS
}

# Build only (assumes already configured)
qgc-build() {
    JOBS=$(( $(nproc) > 4 ? $(nproc) - 4 : 1 ))
    ninja -C ~/qgroundcontrol/build -j $JOBS
}

# Run
alias qgc-run='~/qgroundcontrol/build/RelWithDebInfo/QGroundControl'

# Release configure (separate build type)
qgc-configure-release() {
    cd ~/qgroundcontrol || return

    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DQt6_DIR="$QGC_QT_DIR"
}

# AppImage generation
qgc-release() {
    JOBS=$(( $(nproc) > 4 ? $(nproc) - 4 : 1 ))
    cd ~/qgroundcontrol/build || return

    # Configure if needed
    if [ ! -f CMakeCache.txt ]; then
        echo "Configuring build..."
        qgc-configure-release || return
    else
        echo "Build already configured, skipping configure step."
    fi

    # Build
    echo "Building QGroundControl..."
    if ! ninja -j $JOBS; then
        echo "Build failed! Aborting AppImage generation."
        return 1
    fi

    # Generate AppImage
    echo "Generating AppImage..."
    cmake --install . --config Release
}
```

## AppImage
### QGC.desktop file to put in ~/.local/share/applications
#### then Log out or run -> update-desktop-database ~/.local/share/applications
```
[Desktop Entry]
Name=QGroundControl
Type=Application
Categories=Utility;Development;
Icon=/home/mehmet/qgroundcontrol/build/AppDir/QGroundControl.svg
StartupNotify=true

# have one of the Exec uncommented

# ==============================
# Production Exec (no terminal)
# Use this for normal usage
# ==============================
#Exec=bash -c "source /opt/ros/jazzy/setup.bash; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/ros/jazzy/lib:~/ros2_ws/install/lib; export QT_QPA_PLATFORM=xcb; /home/mehmet/qgroundcontrol/build/QGroundControl-x86_64.AppImage;"

# ==============================
# Debug Exec (with terminal)
# Uncomment this if you want logs
# ==============================
Exec=gnome-terminal -- bash -c "source /opt/ros/jazzy/setup.bash; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/ros/jazzy/lib:~/ros2_ws/install/lib; export QT_QPA_PLATFORM=xcb; /home/mehmet/qgroundcontrol/build/QGroundControl-x86_64.AppImage "$@"; echo 'App exited, press Enter'; read"
```
### then you can search for 'QGroundControl' right-click > Pin to Dash