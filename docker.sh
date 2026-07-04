#!/bin/bash

# ==============================================================================
# set default values for variables
# ==============================================================================
IMAGE_NAME="aoc2026-env"
TAG="lab1"
CONTAINER_NAME="aoc2026-container-jane"
USERNAME="jane"
HOSTNAME="aislab-jane"

# array to hold multiple mount paths
MOUNT_PATHS=()

# ==============================================================================
# Helper function to display usage information
# ==============================================================================
show_help() {
    echo "help:"
    echo "  $0 run [OPTIONS]     - activate the container "
    echo "  $0 clean             - delete the container and image"
    echo "  $0 rebuild           - delete and rebuild the image"
    echo ""
    echo "[run] options:"
    echo "  --username <name>    - specify the username inside the container (default: jane)"
    echo "  --image-name <name>  - specify the Docker image name (default: aoc2026-env)"
    echo "  --cont-name <name>   - specify the Container name (default: aoc2026-container-jane)"
    echo "  --hostname <name>    - specify the container's hostname (default: aislab-jane)"
    echo "  --mount <path>       - specify the local path to bind mount into the container (can be used multiple times)"
}

# ==============================================================================
# read command line arguments
# ==============================================================================
COMMAND=$1
shift 

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --cont-name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --mount)
            MOUNT_PATHS+=("$2")
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# ==============================================================================
# functions for each command
# ==============================================================================

# 1. Build Image 
build_image() {
    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" != "" ]; then
        echo "[info] Docker image '${FULL_IMAGE}' already exists!"
        echo "[info] If you want to force rebuild, run: $0 rebuild"
    else
        echo "[ongoing] Building image '${FULL_IMAGE}' with username '${USERNAME}'..."
        docker build --build-arg USERNAME=${USERNAME} -t ${FULL_IMAGE} .
    fi
}

# 2. Run Container 
run_container() {
    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" == "" ]; then
        echo "[info] Docker image '${FULL_IMAGE}' not found, automatically starting build process..."
        build_image
    fi

    local status
    status=$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME} 2>/dev/null)

    if [ "$status" == "true" ]; then
        echo "[info] Container '${CONTAINER_NAME}' is running. Logging in..."
        docker exec -it ${CONTAINER_NAME} //bin/bash

    elif [ "$status" == "false" ]; then
        echo "[info] Container '${CONTAINER_NAME}' is stopped. Starting and logging in..."
        docker start ${CONTAINER_NAME}
        docker exec -it ${CONTAINER_NAME} //bin/bash
    else
        echo "[info] Container '${CONTAINER_NAME}' does not exist. Creating new container..."
        
        
        local run_cmd="docker run -it --name ${CONTAINER_NAME} --hostname ${HOSTNAME} -u ${USERNAME}"
        
        for path in "${MOUNT_PATHS[@]}"; do
            local abs_path
            abs_path=$(cd "$path" 2>/dev/null && pwd -W 2>/dev/null || (cd "$path" 2>/dev/null && pwd) || echo "$path")
            local folder_name=$(basename "$abs_path")
            
            run_cmd+=" -v ${abs_path}:/home/${USERNAME}/${folder_name}"
            echo "-> Configuring mount point: ${abs_path} -> /home/${USERNAME}/${folder_name}"
        done
        
        run_cmd+=" ${FULL_IMAGE} //bin/bash"
        eval $run_cmd
    fi
}

# 3. Clean 
clean_all() {
    echo "[info] Starting to clean the specified environment..."
    
    # 1. remove the container if it exists
    if [ "$(docker ps -a -q -f name=${CONTAINER_NAME})" != "" ]; then
        echo "-> Stopping and removing container: ${CONTAINER_NAME}"
        docker rm -f ${CONTAINER_NAME} 2>/dev/null
    fi
    if [ "$(docker ps -a -q -f name=aoc2026-container-myuser)" != "" ]; then
        echo "-> Removing old residual container: aoc2026-container-myuser"
        docker rm -f aoc2026-container-myuser 2>/dev/null
    fi

    # 2. remove the image if it exists
    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" != "" ]; then
        echo "-> Forcing removal of image: ${FULL_IMAGE}"
        docker rmi -f ${FULL_IMAGE} 2>/dev/null
    fi
    echo "[info] Cleanup completed!"
}

# ==============================================================================
# main logic to handle the command
# ==============================================================================
case "$COMMAND" in
    build)
        build_image
        ;;
    run)
        run_container
        ;;
    clean)
        clean_all
        ;;
    rebuild)
        clean_all
        build_image
        ;;
    *)
        show_help
        ;;
esac