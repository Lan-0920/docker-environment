# ==============================================================================
# 1. basic settings
# ==============================================================================
WORKSPACE_DIR="/home/jane/environment-Jane"
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
            echo "Usage example: eman change-verilator v5.028"
            exit 1
        fi
        
        echo "[INFO] Trying to switch default Verilator version to: $VERSION ..."
        
        # Implement version switching logic:
        # If the user specifies a system-installed apt version, point to /usr/bin/verilator
        # If it's a manually compiled version under /opt/, create a symbolic link
        if [ "$VERSION" == "apt" ] || [ "$VERSION" == "default" ]; then
            sudo ln -sf /usr/bin/verilator /usr/local/bin/verilator
            echo "[SUCCESS] Successfully switched Verilator back to the Ubuntu package version."
        elif [ -f "/opt/verilator/${VERSION}/bin/verilator" ]; then
            sudo ln -sf /opt/verilator/${VERSION}/bin/verilator /usr/local/bin/verilator
            echo "[SUCCESS] Successfully switched! Current default Verilator points to: /opt/verilator/${VERSION}"
        elif [ -f "/opt/verilator/bin/verilator" ] && [ "$VERSION" == "v5.028" ]; then
            sudo ln -sf /opt/verilator/bin/verilator /usr/local/bin/verilator
            echo "[SUCCESS] Successfully switched! Current default Verilator points to: /opt/verilator (v5.028)"
        else
            echo "[WARNING] Version [${VERSION}] not found in /opt/verilator/."
            echo "[INFO] Trying to check or install the specified version via apt..."
            # Attempt to install the version using the package manager
            sudo apt-get update && sudo apt-get install -y --no-install-recommends verilator
            sudo ln -sf /usr/bin/verilator /usr/local/bin/verilator
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



