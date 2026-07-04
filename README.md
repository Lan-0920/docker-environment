# Environment 
The environment is structured to separate host-side source editing from container-side compilation and simulation execution. Source code directories are mirrored directly into the container instance to guarantee continuous persistence and modular separation.


## File Architecture

```
.
├── docker.sh               # Host-side: Intelligent container life-cycle manager
├── Dockerfile              # Host-side: Architecture-aware multi-stage build blueprint
├── eman.sh                 # Internal: Tooling automation manager script
├── .gitignore                 
└── lab-0-tutorial/         # Mounted development workspace
    ├── c_cpp/              
    ├── python/             
    └── verilog/     
```


## Docker Container Management Script

The `docker.sh` provides  CLI-based management of a development container environment, including build, run, mount, rebuild, and cleanup operations for user-specific development sessions.

`$./docker.sh <command> [options...]`
### Available Commands:
| Command           | Description                                                        |
|------------------|--------------------------------------------------------------------|
| `build`    | Build the specialized Docker image with host UID/GID arguments  |
| `run`    | Build the image if not present and start/attach to the user container environment|
| `clean`    | Remove the specified container, old residual container, and force-delete the image               |
| `rebuild`     | Run `clean` and `build` sequentially to refresh the image from scratch          |
| `help`| Show usage instructions |




### Options:
| Option           | Description                                                        |
|------------------|--------------------------------------------------------------------|
| `--username`     | Specify the username inside the container (default: `jane`)|
| `--image-name`   | Specify a custom Docker image name (default: `aoc2026-env`)|
| `--cont-name`    | Specify a custom Container name override                 |
| `--hostname`     | Specify a custom Container hostname override             |
| `--mount <path>` | Specify a local path to bind mount into the container |



## Examples

### Build image without running

```bash
$./docker.sh build
```

### Run container with default config

```bash
$./docker.sh run
```

### Run container with custom user, custom image, and multiple mounts:

```bash
$./docker.sh run --username jane --image-name my-hdl-env --mount ./lab-0-tutorial --mount ./projects
```

### Rebuild environment from scratch

```bash
$./docker.sh rebuild
```

### Clean up specified user layers and container

```bash
$./docker.sh clean --username jane
```

---

##  Features

- **Automated Dependency Build**:
 Automatically triggers the Docker image compilation process if the target image is missing during a `run` command.
- **Smart Container Re-use**: 
Automatically detects container status. If it is already `running`, it logs in via `exec`; if `stopped/exited`, it executes `start` before logging in; if non-existent, it creates a new one.
- **Dynamic Multi-Mount Resolution**: 
Supports passing the `--mount` flag multiple times. It automatically resolves relative paths to absolute paths and links them to `/home/${USERNAME}/${folder_name}` inside the environment.
- **Host-Container Permission Alignment**: 
Pass host user’s UID and GID (`id -u` / `id -g`) during build and run phases to prevent workspace root file permission conflicts.
- **Residual Cleanup**: 
The `clean` command automatically flushes out the main user container and wipes away any old residual `aoc2026-container-myuser` containers .

---

## How To Test

1. make sure clean up the image and container
```
$./docker.sh clean
```
2. run the following command
```
$./docker.sh run --mount ./lab-0-tutorial
```
>the docker will build default image and container,then mount file folder
3. you can test verilator/c-compiler by following commands

- print the version of the first found Verilator 
    ```
    $eman check-verilator            
    ```
- compile and run the Verilator example
    ```
    $eman verilator-example          
    ```
- change default Verilator to different version. If not installed, install it.
    ```
    $eman change-verilator <VERSION> 
    ```
 - print the version of default C compiler and the version of GNU Make
    ```
    $eman c-compiler-version        
    ```
- compile and run the C/C++ example
    ```
    $eman c-compiler-example         
    ```



