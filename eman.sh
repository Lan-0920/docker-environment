# ==============================================================================
# 1. basic settings
# ==============================================================================
WORKSPACE_DIR="/home/jane"
LAB_DIR="${WORKSPACE_DIR}/lab-0-tutorial"

# C/C++ root path for example programs
C_EXAMPLE_DIR="${LAB_DIR}/c_cpp/arrays/multidim_array"
# Verilog root path for example programs
VERILOG_DIR="${LAB_DIR}/verilog"

# ==============================================================================
# 2. helper functions
# ==============================================================================
help() {
    cat <<EOF
command line tool (eman) - for managing the development environment
Usage: eman <command> [options]

    eman check-verilator            : print the version of the first found Verilator (if there are multiple version of Verilator installed)
    eman verilator-example          : compile and run the Verilator example(s)
    eman change-verilator <VERSION> : change default Verilator to different version. If not installed, install it.

    eman c-compiler-version         : print the version of default C compiler and the version of GNU Make
    eman c-compiler-example         : compile and run the C/C++ example(s)

EOF
}

# ==============================================================================
# 3. core functions for Docker management
# ==============================================================================
case "$1" in
    check-verilator)
        echo "[INFO] Checking Verilator version ..."
        if command -v verilator &> /dev/null; then
            verilator --version
        else
            echo "[ERROR] Verilator executable not found!"
            exit 1
        fi
        ;;

    verilator-example)
        echo "[INFO] Preparing to compile and run Verilator hardware simulation examples..."
        if [ -d "$VERILOG_DIR" ]; then
            cd "$VERILOG_DIR"
            echo "-> Executing clean to remove old compilation artifacts and waveform files..."
            make clean
            echo "-> Executing run to start simulation of all sub-modules (hello, counter, adder, trafficlight)..."
            make run
            echo "[SUCCESS] Verilator examples simulation completed!"
        else
            echo "[ERROR] Verilator example directory not found, please ensure the repository is correctly cloned!"
            echo "Expected path: $VERILOG_DIR"
            exit 1
        fi
        ;;

    change-verilator)
        VERSION=$2
        if [ -z "$VERSION" ]; then
            echo "[ERROR] Syntax error! Please specify the version number to switch to."
            echo "Usage example: eman change-verilator v5.034"
            exit 1
        fi

        # normalize the version string to ensure it starts with 'v'
        if [[ ! "$VERSION" =~ ^v[0-9] ]]; then
            TARGET_VERSION="v${VERSION}"
        else
            TARGET_VERSION="${VERSION}"
        fi
        
        echo "[INFO] Trying to switch default Verilator version to: $TARGET_VERSION ..."
        TARGET_DIR="/opt/verilator/${TARGET_VERSION}"
        
        # Check if the target version is already installed
        if [ ! -f "${TARGET_DIR}/bin/verilator" ]; then
            echo "[WARNING] Version [${TARGET_VERSION}] is not installed in /opt/verilator/."
            echo "[INFO] Automatically starting download and compilation process for ${TARGET_VERSION}..."
            
            # build directory for Verilator compilation
            BUILD_DIR="/tmp/verilator_build_${TARGET_VERSION}"
            sudo rm -rf "$BUILD_DIR"
            mkdir -p "$BUILD_DIR"
            
            # copy the source code of Verilator from GitHub
            echo "-> Cloning Verilator repository (${TARGET_VERSION})..."
            git clone https://github.com/verilator/verilator.git "$BUILD_DIR/verilator"
            
            if [ $? -ne 0 ] || [ ! -d "$BUILD_DIR/verilator" ]; then
                echo "[ERROR] Failed to clone Verilator repository. Check internet connection."
                exit 1
            fi
            
            cd "$BUILD_DIR/verilator"
            echo "-> Checking out tag ${TARGET_VERSION}..."
            git checkout "$TARGET_VERSION" 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "[ERROR] Version [${TARGET_VERSION}] does not exist on Verilator GitHub tags!"
                echo "Please check the version number (e.g., v5.034, v5.028)."
                exit 1
            fi
            
            # start the compilation and installation process
            echo "-> Running autoconf & configure..."
            unset VERILATOR_ROOT
            autoconf
            
            # avoid using -Werror to prevent compilation errors due to warnings
            ./configure --prefix="$TARGET_DIR" CXXFLAGS="-std=c++17 -fpermissive -Wno-error"
            
            echo "-> Compiling Verilator using $(nproc) cores (this may take a few minutes)..."
            make -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "[ERROR] Compilation failed during 'make'."
                exit 1
            fi
            
            echo "-> Installing into ${TARGET_DIR}..."
            sudo make install
            if [ $? -ne 0 ]; then
                echo "[ERROR] Installation failed during 'make install'."
                exit 1
            fi
            
            # clean up the build directory after successful installation
            sudo rm -rf "$BUILD_DIR"
            echo "[SUCCESS] ${TARGET_VERSION} has been successfully compiled and installed!"
        fi
        
        # create symbolic link to switch default Verilator version
        if [ -f "${TARGET_DIR}/bin/verilator" ]; then
            sudo ln -sf "${TARGET_DIR}/bin/verilator" /usr/local/bin/verilator
            echo "[SUCCESS] Successfully switched! Current default Verilator points to: ${TARGET_DIR}"
        else
            echo "[ERROR] Critical error: Installation verified but binary still missing."
            exit 1
        fi
        
        echo -n "-> Current default version is: "
        verilator --version
        ;;

    c-compiler-version)
        echo "[INFO] Checking C compiler and GNU Make versions..."
        if command -v gcc &> /dev/null && command -v make &> /dev/null; then
            echo "C Compiler: $(gcc --version | head -n 1)"
            echo "GNU Make  : $(make --version | head -n 1)"
        else
            echo "[ERROR] System missing core compilation tools gcc or make!"
            exit 1
        fi
        ;;

    c-compiler-example)
        echo "[INFO] Preparing to compile and run C/C++ multi-dimensional array examples..."
        if [ -d "$C_EXAMPLE_DIR" ]; then
            cd "$C_EXAMPLE_DIR"
            echo "-> Executing make clean to remove old compilation artifacts..."
            make clean
            echo "-> Executing make run to start compilation and print memory addresses..."
            make run
            echo "[SUCCESS] C language examples compilation and execution test completed!"
        else
            echo "[ERROR] C example directory not found, please ensure the repository is correctly cloned!"
            echo "Expected path: $C_EXAMPLE_DIR"
            exit 1
        fi
        ;;

    help|*)
        help
        ;;
esac