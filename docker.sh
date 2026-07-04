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
# read the first argument as the command (build, run, clean, rebuild)
COMMAND=$1
# shift the arguments so that $@ contains only the options for the command
shift 

# start parsing the remaining arguments
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
            MOUNT_PATHS+=("$2") # append the mount path to the array
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

# combine image name and tag to form the full image identifier
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# ==============================================================================
# functions for each command
# ==============================================================================

# 1. Build Image 
build_image() {
    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" != "" ]; then
        echo "[info] Docker image '${FULL_IMAGE}' already exists!"
        echo "[info] if you want to delete it, run: $0 clean --image-name ${IMAGE_NAME} --cont-name ${CONTAINER_NAME}"
    else
        echo "[ongoing] Building image '${FULL_IMAGE}'..."
        # set the USERNAME argument for the Dockerfile
        docker build --build-arg USERNAME=${USERNAME} -t ${FULL_IMAGE} .
    fi
}

# 2. Run Container 
run_container() {
    # make sure the image exists, if not, build it
    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" == "" ]; then
        echo "[info] Docker image '${FULL_IMAGE}' not found, automatically starting build process..."
        build_image
    fi

    # check the status of the container: running, stopped, or not existed
    local status
    status=$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME} 2>/dev/null)

    if [ "$status" == "true" ]; then
        # status: running -> enter container
        echo "[info] Container '${CONTAINER_NAME}' is running. Logging in..."
        docker exec -it ${CONTAINER_NAME} //bin/bash

    elif [ "$status" == "false" ]; then
        # status: stopped -> start container and enter
        echo "[info] Container '${CONTAINER_NAME}' is stopped. Starting and logging in..."
        docker start ${CONTAINER_NAME}
        docker exec -it ${CONTAINER_NAME} //bin/bash
    else
        # status: not existed -> create container and enter
        echo "[info] Container '${CONTAINER_NAME}' does not exist. Dynamically configuring parameters and creating new container..."
        
        # create base command
        local run_cmd="docker run -it --name ${CONTAINER_NAME} --hostname ${HOSTNAME}"
        
        # configure mount points
        # put the mount paths into the container's home directory, using the folder name as the target
        for path in "${MOUNT_PATHS[@]}"; do
            # get the absolute path of the local folder
            local abs_path
            abs_path=$(cd "$path" 2>/dev/null && pwd || echo "$path")
            local folder_name=$(basename "$abs_path")
            
            run_cmd+=" -v ${abs_path}:/home/${USERNAME}/${folder_name}"
            echo "-> Configuring mount point: ${abs_path} -> /home/${USERNAME}/${folder_name}"
        done
        
        # add the image and command to run inside the container
        run_cmd+=" ${FULL_IMAGE} //bin/bash"
        # 執行最終組合出來的指令
        eval $run_cmd
    fi
}

# 3. Clean 功能
clean_all() {
    echo "[info] Starting to clean the specified environment..."
    if [ "$(docker ps -a -q -f name=${CONTAINER_NAME})" != "" ]; then
        echo "-> Stopping and removing container: ${CONTAINER_NAME}"
        docker stop ${CONTAINER_NAME} 2>/dev/null
        docker rm ${CONTAINER_NAME} 2>/dev/null
    fi

    if [ "$(docker images -q ${FULL_IMAGE} 2> /dev/null)" != "" ]; then
        echo "-> Removing image: ${FULL_IMAGE}"
        docker rmi ${FULL_IMAGE} 2>/dev/null
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