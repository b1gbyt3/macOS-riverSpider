#!/bin/bash
# ======================================================================================================================================
# riverSpider macOS Setup Script
#
# Author: Ilya Babenko
# Last updated: 2025-05-03
# Version: 2.3.0
#
# What this script does:
# This script helps set up the riverSpider on your Mac automatically.
#   1. Checks System: Confirms macOS, detects chip type (Intel/Apple Silicon),
#      checks internet, and identifies your shell (Bash/Zsh).
#   2. Installs Tools: Uses Homebrew (a package manager) to install itself,
#      and required tools like mise, fd, wget, and coreutils.
#   3. Installs Java: Uses mise to install the correct Java version for Logisim.
#   4. Locates or downloads 'riverSpider'.
#   5. Updates paths inside the 'submit.sh' script so it works correctly
#      from anywhere.
#   6. Creates RIVER_SPIDER_DIR variable so your
#      terminal knows where the 'riverSpider' folder is.
#   7. Creates an easy command 'riverspider' you can type
#      in the terminal to run the submit script from anywhere.
#   8. Creates easy commands: 'logisim','logproc','logalu', and 'logreg' you can type
#      in the terminal to open Logisim from anywhere.
#   8. Shows instructions for the manual Google App Script setup.
#
# How to use it:
#   Open your Terminal app and run:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/b1gbyt3/macOS-riverSpider/HEAD/install.sh)"
# ======================================================================================================================================

# -e: Stop right away if any command fails (has an error).
# -u: Stop if the script tries to use a name (variable) that hasn't been given a value.
# -o pipefail: If commands are chained with '|' (like command A | command B),
#              stop if any command in the chain fails.
set -euo pipefail

# =========================== Global Variables ===========================

# ===========================   OK TO CHANGE   ===========================

#  show/hide detailed progress
readonly VERBOSE="false"

# --- Shell Settings Filenames ---
# Default names for the shell configuration files.
# You might need to change these if you use different filenames like '.zshrc' or '.bashrc'.
readonly ZSH_PROFILE_BASENAME=".zprofile"      # For Zsh shell
readonly BASH_PROFILE_BASENAME=".bash_profile" # For Bash shell

# --- Google Drive Info  ---
# Link and name used in the manual setup instructions for Google Sheets.
readonly GOOGLE_DRIVE_FOLDER_URL="https://drive.google.com/drive/folders/0BxsMACqxAFNwR1pCb2pPeE5Wb1E?resourcekey=0-fb_u058vHLwLSyiSaBKPoQ"
readonly GOOGLE_SHEETS_DOC_NAME="'Copy of assemblerStudent'" # The name of the sheet template
readonly TTPASM_APP_SCRIPT_DEFAULT_PASSWD="1234!@#\$qwerQWER"
# --- Download riverSpider from Google Drive ---
readonly RIVER_SPIDER_GOOGLE_DRIVE_FILE_ID="1g63nlTRa-Ibgj0ZUf3HX1fbdSrW90JBs"
readonly RIVER_SPIDER_ZIP_NAME="riverSpiderForMac.zip"
readonly RIVER_SPIDER_OUTPUT_FILE="${HOME}/${RIVER_SPIDER_ZIP_NAME}"
readonly RIVER_SPIDER_EXTRACT_DIRECTORY="$(mktemp -d)"
readonly RIVER_SPIDER_TARGET_DIRECTORY="${HOME}/riverSpider"

# --- Relative Paths in submit.sh ---
# These are the exact lines the script looks for in 'submit.sh'
# to replace them with the absolute paths.
# IF YOU MAKE ANY CHANGES HERE, MAKE SURE TO UPDATE "new_" in update_paths_in_riverspider_submit_script()
readonly OLD_SECRETS_PATH_LINE='secretPath=secretString.txt'
readonly OLD_WEBAPP_URL_PATH_LINE='webappUrlPath=webapp.url'
readonly OLD_LOGISIM_JAR_PATH_LINE='logisimPath=logisim310.jar'
readonly OLD_PROCESSOR_CIRC_PATH_LINE='processorCircPath=processor0004.circ'
readonly OLD_URLENCODE_SED_PATH_LINE='urlencodeSedPath=urlencode.sed'

# --- riverSpider Filenames ---
# Names of files inside the 'riverSpider' folder.
readonly SUBMIT_SCRIPT_NAME="submit.sh"
readonly SECRET_FILE_NAME="secretString.txt"
readonly WEBAPP_URL_FILE_NAME="webapp.url"
readonly LOGISIM_JAR_FILE_NAME="logisim310.jar"
readonly PROCESSOR_CIRC_FILE_NAME="processor0004.circ"
readonly URLENCODE_SED_FILE_NAME="urlencode.sed"
readonly TEST_FILE_NAME="test.ttpasm"

# =======================  END OK TO CHANGE  ========================

# ========================== DO NOT CHANGE ==========================

# --- Log File ---
# Creates a new log file with the date and time in its name each time the script runs.
readonly LOG_FILE="$(mktemp "/tmp/riverspider_setup_$(date +%Y%m%d_%H%M%S).log")"

# --- Homebrew Install Url ---
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# --- Homebrew Binary Location ---
readonly ARM_HOMEBREW_PATH="/opt/homebrew/bin/brew" # Usual place on Apple Silicon Macs
readonly INTEL_HOMEBREW_PATH="/usr/local/bin/brew"  # Usual place on Intel Macs

# --- Needed Commands & Tools ---
# Basic commands the script expects to find on the Mac.
readonly REQUIRED_SYSTEM_COMMANDS=("mkdir" "rm" "dirname" "basename" "realpath" "touch" "cat" "echo" "printf" "head" "ping" "curl" "unzip" "git" "uname" "sw_vers" "grep" "sed" "tr" "sleep")
# Java that WORKS with logisim
readonly JDK_MISE_NAME="java@openjdk"
readonly HOMEBREW_PACKAGES_TO_INSTALL=("coreutils" "wget" "mise" "fd")
# Ensure tools are working after installation.
readonly INSTALLED_TOOLS_TO_VERIFY=("timeout" "wget" "mise" "fd")

# --- Internet Test Domains ---
readonly CHECK_DOMAINS=("www.google.com" "www.apple.com" "github.com")

# ========================= END DO NOT CHANGE =======================

# ===================================================================
# These get their actual values while the script runs.
# Declaring them here makes it clear what information the script keeps track of.

declare CURRENT_SHELL=""          # Which shell is being used ("zsh" or "bash").
declare SHELL_PROFILE_FILE=""     # Full path to the shell's settings file (like ~/.zprofile).
declare HOMEBREW_PATH=""          # Where the Homebrew 'brew' command is located.
declare PROCESSOR_ARCHITECTURE="" # The computer's chip type ("arm64" or "x86_64").
declare CHIP_TYPE=""              # A friendly name for the chip ("Apple Silicon" or "Intel Processor").
declare MISE_SHELL_TYPE=""        # The shell name 'mise' needs ("zsh" or "bash").
declare RIVER_SPIDER_DIR=""       # Full path to where the 'riverSpider' folder was found.
# ===================================================================

# =========================== HELPER UTILITIES ===========================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_file_writable() {
  local file_path="$1"
  local file_description="${2:-"File"}"
  if [[ -z "$file_path" ]]; then
    echo "[ERROR] File path argument is missing." >>"$LOG_FILE"
    echo "[ERROR] File path argument is missing." >&2
    exit 1
  fi
  if [[ ! -e "$file_path" ]]; then
    local parent_dir
    parent_dir=$(dirname "$file_path")
    if [[ ! -d "$parent_dir" ]]; then
      echo "[ERROR] Parent directory does not exist: $parent_dir" >>"$LOG_FILE"
      echo "[ERROR] Parent directory does not exist: $parent_dir" >&2
      exit 1
    fi
    if [[ ! -w "$parent_dir" ]]; then
      echo "[ERROR] Parent directory is not writable: $parent_dir" >>"$LOG_FILE"
      echo "[ERROR] Parent directory is not writable: $parent_dir" >&2
      exit 1
    fi
    if ! touch "$file_path"; then
      echo "[ERROR] Failed to create $file_description: $file_path." >>"$LOG_FILE"
      echo "[ERROR] Failed to create $file_description: $file_path." >&2
      exit 1
    fi
  elif [[ ! -f "$file_path" ]]; then
    echo "[ERROR] Path exists but is not a regular file: $file_path" >>"$LOG_FILE"
    echo "[ERROR] Path exists but is not a regular file: $file_path" >&2
    exit 1
  fi
  if [[ ! -w "$file_path" ]]; then
    if ! chmod u+w "$file_path"; then
      echo "[ERROR] Failed to modify permissions for $file_description: $file_path. Check ownership and permissions." >>"$LOG_FILE"
      echo "[ERROR] Failed to modify permissions for $file_description: $file_path. Check ownership and permissions." >&2
      exit 1
    fi
    if [[ ! -w "$file_path" ]]; then
      echo "[ERROR] Still not writable after chmod (unexpected): $file_path." >>"$LOG_FILE"
      echo "[ERROR] Still not writable after chmod (unexpected): $file_path." >&2
      exit 1
    fi
  fi
}

ensure_shell_profile_exists_and_writable() {
  local msg="${1:-"shell profile file"}"
  if [[ -z "$SHELL_PROFILE_FILE" ]]; then
    log_error "Shell profile file path (SHELL_PROFILE_FILE) was not set. Cannot proceed."
  fi
  ensure_file_writable "$SHELL_PROFILE_FILE" "$msg"
}

add_line_if_missing() {
  local line="$1" # The text line to add.
  local file="$2" # The file to add the line to.

  if [[ -z "$line" || -z "$file" ]]; then
    echo "[ERROR] Cannot add line to file: one of the arguments is missing." >>"$LOG_FILE"
    echo "[ERROR] Cannot add line to file: one of the arguments is missing." >&2
    exit 1
  fi

  ensure_file_writable "$file"
  # Add the line if it's not already in the file.
  if ! grep -Fxq -- "$line" "$file"; then
    echo "[DEBUG] Adding line to $file: $line" >>"$LOG_FILE"
    echo "" >>"$file"
    echo "$line" >>"$file"
    echo "" >>"$file"
    return 0
  fi
  echo "[DEBUG] $line - already exists in $file" >>"$LOG_FILE"
}

# ========================================================================

# ==========================  MESSAGE HELPERS  ===========================

setup_terminal_colors() {
  if [[ -t 1 ]]; then
    tty_escape() { printf "\033[%sm" "$1"; }
  else
    tty_escape() { :; }
  fi

  tty_mkbold() { tty_escape "1;$1"; }

  tty_blue=$(tty_mkbold 34)   # Blue color
  tty_red=$(tty_mkbold 31)    # Red color
  tty_yellow=$(tty_mkbold 33) # Yellow color
  tty_green=$(tty_mkbold 32)  # Green color
  tty_bold=$(tty_mkbold 39)   # Bold text
  tty_reset=$(tty_escape 0)   # Reset text to normal
}

log_info() {
  local msg="$*"
  ensure_file_writable "$LOG_FILE" "LOG file"
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$msg"
  echo "[INFO] $msg" >>"$LOG_FILE"
}

log_success() {
  local msg="$*"
  ensure_file_writable "$LOG_FILE" "LOG file"
  printf "${tty_green}✓${tty_reset} %s\n" "$msg"
  echo "[SUCCESS] $msg" >>"$LOG_FILE"
}

log_warning() {
  local msg="$*"
  ensure_file_writable "$LOG_FILE" "LOG file"
  printf "${tty_yellow}Warning${tty_reset}: %s\n" "$msg" >&2
  echo "[WARNING] $msg" >>"$LOG_FILE"
}

# Shows error messages and stops the script.
log_error() {
  local msg="$*"
  ensure_file_writable "$LOG_FILE" "LOG file"
  printf "${tty_red}Error${tty_reset}: %s\n" "$msg" >&2
  echo "[ERROR] $msg" >>"$LOG_FILE"
  echo "[ERROR] Script aborted at $(date)" >>"$LOG_FILE"
  echo "[ERROR] Script aborted at $(date) check logfile $LOG_FILE"
  exit 1
}

# Writes extra details (debug info) only to the log file.
log_debug() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[DEBUG] $*"
  fi
  ensure_file_writable "$LOG_FILE" "LOG file"
  echo "[DEBUG] $*" >>"$LOG_FILE"
}
# ========================================================================

# =========================== PRE FLIGHT CHECKS ==========================

check_required_system_commands() {
  log_info "Checking for essential commands..."
  local missing_commands=()

  for command_name in "${REQUIRED_SYSTEM_COMMANDS[@]}"; do
    if ! command_exists "$command_name"; then
      # If command is not found, add it to the missing list.
      missing_commands+=("$command_name")
    else
      log_success "'$command_name' found:  ($(command -v "$command_name"))"
    fi
  done
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    log_error "Required command(s) missing: ${missing_commands[*]}"
  fi
}

check_operating_system_and_architecture() {
  log_info "Checking operating system and architecture..."
  # Check if the Operating System is macOS ('Darwin').
  # 'uname -s' gets the OS name.
  local system="$(/usr/bin/uname -s)"
  if [[ "$system" != "Darwin" ]]; then
    log_error "This script is designed for macOS only. Detected OS: $system"
  fi
  log_debug "Operating system confirmed as macOS (Darwin)."
  # Get the macOS version number.
  local os_version
  # 'sw_vers -productVersion' gets the version (e.g., "14.4.1").
  os_version=$(sw_vers -productVersion) || os_version="Unknown"
  log_debug "Detected macOS version: $os_version"
  # Find out the chip architecture.
  # 'uname -m' gets the hardware name (e.g., "arm64", "x86_64").
  PROCESSOR_ARCHITECTURE="$(/usr/bin/uname -m)"
  log_debug "Detected ${PROCESSOR_ARCHITECTURE} architecture."
  case "$PROCESSOR_ARCHITECTURE" in
  arm64)
    HOMEBREW_PATH="$ARM_HOMEBREW_PATH" # Expected Homebrew location
    CHIP_TYPE="Apple Silicon"
    log_debug "Architecture is arm64 (Apple Silicon). Expecting Homebrew at $HOMEBREW_PATH."
    ;;
  x86_64)
    HOMEBREW_PATH="$INTEL_HOMEBREW_PATH" # Expected Homebrew location
    CHIP_TYPE="Intel Processor"
    log_debug "Architecture is x86_64 (Intel). Expecting Homebrew at $HOMEBREW_PATH."
    ;;
  *)
    log_error "Unsupported processor architecture: '$PROCESSOR_ARCHITECTURE'. This script supports arm64 (Apple Silicon) and x86_64 (Intel)."
    ;;
  esac

  log_success "System validated: macOS Version $os_version ($CHIP_TYPE)"
}

# Checks if the computer is connected to the internet.
# Tries to 'ping' a few reliable websites. Stops with error if none work.
check_internet_connectivity() {
  log_info "Checking internet connectivity..."
  for domain in "${CHECK_DOMAINS[@]}"; do
    log_debug "Attempting to ping $domain..."
    # Try to 'ping' (send a small test message) to the website.
    # '-c 1' sends 1 ping. '-W 3' waits 3 seconds for reply. '&>/dev/null' hides output.
    if ping -c 1 -W 3 "$domain" &>/dev/null; then
      log_success "Internet connection 'OK'"
      return 0 # Found connection, stop checking.
    fi
  done
  log_error "No internet connection detected. Please check your network."
}

# Figures out which shell (bash or zsh) the user has and where its settings file is.
determine_shell_and_profile() {
  log_info "Detecting user shell and profile file..."
  CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"
  log_debug "Detected shell command based on \$SHELL: $CURRENT_SHELL"
  case "$CURRENT_SHELL" in
  zsh)
    SHELL_PROFILE_FILE="${ZDOTDIR:-$HOME}/$ZSH_PROFILE_BASENAME"
    MISE_SHELL_TYPE="zsh"
    ensure_shell_profile_exists_and_writable "ZSH profile file"
    log_success "Detected shell: zsh"
    log_debug "Zsh profile file determined as: $SHELL_PROFILE_FILE"
    ;;
  bash)
    SHELL_PROFILE_FILE="$HOME/$BASH_PROFILE_BASENAME"
    MISE_SHELL_TYPE="bash"
    ensure_shell_profile_exists_and_writable "BASH profile file"
    log_success "Detected shell: bash"
    log_debug "Bash profile file determined as: $SHELL_PROFILE_FILE"
    ;;
  *)
    log_error "Unsupported shell detected: '$CURRENT_SHELL'. This script currently only suppourts bash and zsh."
    ;;
  esac
  log_info "Using profile: $SHELL_PROFILE_FILE"
  log_debug "Mise shell type for activation set to: $MISE_SHELL_TYPE"
}
# ========================================================================

# ========================= INSTALLATION HELPERS =========================

# Shows a spinning character animation (like - \ | /) while another command runs in the background.
progress_indicator() {
  local task_name="$1"      # Name of the task (e.g., "Homebrew").
  local background_pid="$2" # Process ID (PID) of the background task.
  local critical="${3:-false}"
  local spin_chars='-\|/' # Characters for the spinner animation.
  local i=0               # Counter for which character to show.
  log_debug "Starting progress indicator for PID $background_pid (Task: $task_name)"

  # Keep spinning as long as the background process is still running.
  # 'kill -0 $pid' checks if the process exists without stopping it. '2>/dev/null' hides errors.
  while kill -0 $background_pid 2>/dev/null; do
    i=$(((i + 1) % 4)) # Cycle through the 4 spinning characters.
    # '\r' moves the cursor back to the start of the line to overwrite.
    # '${spin:$i:1}' gets one character from the 'spin' string at position 'i'.
    printf "\r %s %c " "$task_name" "${spin_chars:$i:1}"
    sleep 0.1 # Wait a very short time (0.1 seconds) before the next spin update.
  done
  # After the process finishes, clear the spinning line
  printf "\r                                   \r"

  local exit_status=0
  # 'wait $pid' waits for the background process to fully finish and gets its exit code.
  # The exit code tells us if the process succeeded (0) or failed (non-zero).
  wait "$background_pid" || exit_status=$?

  log_debug "PID $background_pid ($task_name) finished with exit status $exit_status."

  # Check if the background process finished successfully (exit code 0).
  if [ $exit_status -eq 0 ]; then
    task_name=$(echo "$task_name" | sed 's/Downloading /downloaded /; s/Unzipping /unzipped /; s/Installing /installed /; s/Searching for /found /; s/Homebrew Update/updated Homebrew/')
    log_success "Successfully $task_name"
  else
    task_name=$(echo "$task_name" | sed 's/Downloading /Download /; s/Unzipping /Unzip /; s/Installing /Install /; s/Searching for /find /; s/Homebrew Update/update Homebrew/')
    if [[ "$critical" == "critical" ]]; then
      log_error "Failed to $task_name. Check the log file: $LOG_FILE"
    else
      log_warning "Failed to $task_name. Check the log file: $LOG_FILE"
    fi
  fi
}

# ========================================================================

# ===========================  HOMEBREW SETUP  ===========================

install_homebrew_if_missing() {
  log_info "Checking for Homebrew..."
  if [[ -x "$HOMEBREW_PATH" ]]; then
    log_success "Homebrew already installed"
    log_debug "Found Homebrew at $HOMEBREW_PATH"
    return 0
  fi
  log_info "Homebrew not found. Installing (password required)... Buckle in, this will take a while."
  if ! sudo -v; then
    log_error "Failed to obtain sudo privileges, which are required for Homebrew installation. Please run the script again and provide the password when prompted."
  fi
  log_debug "Starting Homebrew installer"
  (NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")" >>"$LOG_FILE" 2>&1) &
  local installer_pid=$! # Get the PID of the background installer.

  # Show the spinning progress animation while it installs.
  progress_indicator "Installing Homebrew" "$installer_pid" "critical"
  log_info "Verifying Homebrew installation..."
  if [[ ! -x "$HOMEBREW_PATH" ]]; then
    log_error "Failed to install Homebrew. Ensure you have sudo privileges and try again."
  fi
  log_success "Homebrew successfully installed at '$HOMEBREW_PATH'."
}

configure_homebrew_shell_environment() {
  log_info "Configuring shell environment for Homebrew..."
  if [[ ! -x "$HOMEBREW_PATH" ]]; then
    log_error "Homebrew executable not found at '$HOMEBREW_PATH'. Cannot configure shell environment. Run installation step first."
  fi
  ensure_shell_profile_exists_and_writable
  local brew_shellenv_line="eval \"\$(\"${HOMEBREW_PATH}\" shellenv)\""
  log_debug "Homebrew shellenv line to add/check in profile: $brew_shellenv_line"
  if ! add_line_if_missing "$brew_shellenv_line" "$SHELL_PROFILE_FILE"; then
    log_error "Failed to add Homebrew shellenv configuration to '$SHELL_PROFILE_FILE'."
  fi
  log_debug "Activating Homebrew environment for the current script session..."
  if ! eval "$($HOMEBREW_PATH shellenv)"; then
    log_error "Failed to activate Homebrew environment in the current session using 'eval \$($HOMEBREW_PATH shellenv)'. The 'brew' command might not work correctly in this script run. Check permissions and Homebrew installation."
  fi
  if ! command_exists brew; then
    log_error "Homebrew shell environment was configured in profile, but 'brew' command is still not found in the current session's PATH. This indicates an unexpected issue. Check '$SHELL_PROFILE_FILE' and potentially restart your terminal."
  fi
  log_debug "Verified 'brew' command is now available in PATH: $(command -v brew)"
  log_success "Found Homebrew at '$HOMEBREW_PATH'"
}

update_and_configure_homebrew() {
  log_info "Updating Homebrew and applying configurations..."
  if ! command_exists brew; then
    log_error "'brew' command not found. Cannot update Homebrew. Ensure previous setup steps succeeded."
  fi
  log_success "Homebrew is ready to brew"
  log_debug "Attempting to disable Homebrew analytics using 'brew analytics off'..."
  if brew analytics off >>"$LOG_FILE" 2>&1; then
    log_debug "Successfully disabled Homebrew analytics."
  else
    log_debug "Could not disable Homebrew analytics (command failed). This is non-critical. Continuing..."
  fi
  log_info "Updating Homebrew package database (this may take a moment)..."
  log_debug "Running 'brew update'..."
  (brew update >>"$LOG_FILE" 2>&1) &
  local update_pid=$! # Get the PID of the background update process.
  progress_indicator "Homebrew Update" "$update_pid"
}

setup_homebrew_environment() {
  install_homebrew_if_missing          # Step 1: Install if needed.
  configure_homebrew_shell_environment # Step 2: Set up shell environment.
  update_and_configure_homebrew        # Step 3: Update and configure.
}

# ========================================================================

# ========================== TOOL INSTALLATION ===========================

install_homebrew_package_if_missing() {
  local package_name="$1" # Get the tool name.
  log_info "Checking for package: $package_name"
  if ! command_exists brew; then
    log_error "'brew' command not found. Cannot continue."
  fi
  log_debug "Checking if '$package_name' is installed via 'brew list $package_name'..."
  if brew list "$package_name" >/dev/null 2>&1; then
    log_success "$package_name is already installed"
  else
    log_info "Installing $package_name..."
    (brew install "$package_name" >>"$LOG_FILE" 2>&1) &
    local installer_pid=$!
    progress_indicator "Installing '$package_name'" "$installer_pid"
  fi
  return 0
}

verify_installed_tools() {
  if [[ -z "$INSTALLED_TOOLS_TO_VERIFY" ]]; then
    log_error "Missing tools to verify."
  fi
  echo
  log_info "Verifying packages installation..."
  local missing_tools=()
  for tool_name in "${INSTALLED_TOOLS_TO_VERIFY[@]}"; do
    log_debug "Verifying command: $tool_name"
    if ! command_exists "$tool_name"; then
      missing_tools+=("$tool_name")
    else
      log_success "$tool_name is available"
    fi
  done
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Critical tool(s) '${missing_tools[*]}' are missing. Please install them."
  fi
}

install_required_packages() {
  if [[ -z "$HOMEBREW_PACKAGES_TO_INSTALL" ]]; then
    log_error "No packages set to install."
  fi
  echo
  log_info "Installing required packages..."
  for package_name in "${HOMEBREW_PACKAGES_TO_INSTALL[@]}"; do
    if ! install_homebrew_package_if_missing "$package_name"; then
      log_warning "Installation failed for package '$package_name'. Check logs."
    fi
  done
}

# ========================================================================

# =========================== MISE & JAVA SETUP ==========================

configure_mise_environment() {
  if [[ -z "$MISE_SHELL_TYPE" ]]; then
    log_error "Mise shell type (MISE_SHELL_TYPE) not set. Cannot configure mise environment."
  fi
  ensure_shell_profile_exists_and_writable
  echo
  log_info "Configuring 'mise'..."

  # Find where the 'mise' command is located.
  if ! command_exists "mise"; then
    log_error "'mise' command not found. Cannot configure mise environment. Ensure mise setup was successful."
  fi
  local mise_executable="$(command -v mise)"

  log_debug "mise executable found at: $mise_executable"

  local mise_activate_line="eval \"\$(${mise_executable} activate ${MISE_SHELL_TYPE})\""
  log_debug "mise activation line to add/check in profile: $mise_activate_line"

  # Add this line to the profile file if it's not there.
  if ! add_line_if_missing "$mise_activate_line" "$SHELL_PROFILE_FILE"; then
    log_error "Failed to add mise activation line to '$SHELL_PROFILE_FILE'."
  fi

  # Activate 'mise' for the current script session so we can use it to install Java.
  log_debug "Activating mise for the current script session..."
  # Run the activation command using 'eval'. Check if it succeeds.
  if $mise_executable activate >>"$LOG_FILE" 2>&1; then
    log_success "mise environment configured and active for this session."
  else
    log_error "Failed to activate mise environment."
  fi
}

install_java_with_mise() {

  if [[ -z "$JDK_MISE_NAME" ]]; then
    log_error "JDK version not set."
  fi
  echo
  log_info "Downloading Java..."

  if ! command_exists "mise"; then
    log_error "'mise' command not found. Cannot install Java. Ensure mise setup was successful."
  fi
  local mise_executable="$(command -v mise)"

  log_debug "Using mise executable: $mise_executable"

  # Ask 'mise' for the latest recommended version of OpenJDK.
  log_debug "Determining latest recommended Java version using 'mise latest $JDK_MISE_NAME'..."
  local latest_jdk_version=""
  # Run 'mise latest'. Send errors to log file ('2>>'). Check if command succeeded ('!').
  if ! latest_jdk_version=$("$mise_executable" latest "$JDK_MISE_NAME" 2>>"$LOG_FILE"); then
    log_error "Failed to determine the latest Java version. See log: $LOG_FILE"
  fi
  # Check if 'mise latest' returned an actual version number.
  if [[ -z "$latest_jdk_version" ]]; then
    log_error "Failed to determine the latest Java version. See log: $LOG_FILE"
  fi
  log_info "Latest recommended Java version: $latest_jdk_version"

  # Combine the tool name and version (e.g., "java@openjdk@21.0.3").
  local jdk_tool_version="java@$latest_jdk_version"
  log_debug "Full tool@version string for mise: $jdk_tool_version"

  # Tell 'mise' to install this Java version.
  log_debug "Running command: $mise_executable install $jdk_tool_version"
  # Run in background, send output to log, show progress.
  ("$mise_executable" install "$jdk_tool_version" >>"$LOG_FILE" 2>&1) &
  local installer_pid=$!

  progress_indicator "Installing Java $latest_jdk_version" "$installer_pid" "critical"

  log_info "Setting Java $latest_jdk_version as the global default version..."
  log_debug "Running command: $mise_executable use --global $jdk_tool_version"
  # Run 'mise use --global'. Send output to log. Check success.
  if "$mise_executable" use --global "$jdk_tool_version" >>"$LOG_FILE" 2>&1; then
    log_success "Successfully set Java ${latest_jdk_version} as the global default."
  else
    log_error "Failed to set Java ${latest_jdk_version} as the global default. Check log: $LOG_FILE"
  fi

  # Check if Java works correctly now.
  log_info "Verifying Java installation..."
  # Run 'java -version' using 'mise exec' to ensure it uses the mise environment.
  log_debug "Running command: $mise_executable exec -- java -version"
  local java_version_output=""
  if java_version_output=$("$mise_executable" exec -- java -version 2>&1 | head -n 1); then
    log_success "Java installation verified successfully using 'mise exec'."
    log_debug "Java: $java_version_output"
    log_success "Java ${latest_jdk_version} is ready"
  else
    log_warning "Java verification failed. Check log: $LOG_FILE"
    echo "You can try verifying manually after restarting your terminal by running: java -version"
  fi
}

# ========================================================================

# ========================== riverSpider SETUP ===========================

ensure_secrets_initialized() {
  if [[ -z "${RIVER_SPIDER_DIR}" || -z "${SECRET_FILE_NAME}" || -z "${TTPASM_APP_SCRIPT_DEFAULT_PASSWD}" ]]; then
    log_error "One or more required global variables (RIVER_SPIDER_DIR, SECRET_FILE_NAME, TTPASM_APP_SCRIPT_DEFAULT_PASSWD) are not set."
  fi
  local file_path="${RIVER_SPIDER_DIR}/${SECRET_FILE_NAME}"
  ensure_file_writable "${file_path}" "${SECRET_FILE_NAME}"
  local file_content=$(<"${file_path}")
  if [[ -z $file_content ]]; then
    echo "$TTPASM_APP_SCRIPT_DEFAULT_PASSWD" >"$file_path"
  fi
}

clean_up_riverspider_download() {
  if [ -d "${RIVER_SPIDER_EXTRACT_DIRECTORY}/riverSpider" ]; then
    log_debug "Moving contents to $RIVER_SPIDER_TARGET_DIRECTORY..."
    mkdir -p "$RIVER_SPIDER_TARGET_DIRECTORY"
    mv "${RIVER_SPIDER_EXTRACT_DIRECTORY}/riverSpider/"* "$RIVER_SPIDER_TARGET_DIRECTORY/"
    rm -rf "$RIVER_SPIDER_EXTRACT_DIRECTORY" "$RIVER_SPIDER_OUTPUT_FILE"
    log_debug "Extraction and cleanup complete. Files are in $RIVER_SPIDER_TARGET_DIRECTORY"
    find_river_spider_directory
  else
    log_error "Failed to download 'riverSpider'. See Canvas for download instructions."
  fi
}

download_and_extract_riverspider() {
  if [[ -z "$RIVER_SPIDER_OUTPUT_FILE" || -z "$RIVER_SPIDER_ZIP_NAME" || -z "$RIVER_SPIDER_EXTRACT_DIRECTORY" || -z "$RIVER_SPIDER_TARGET_DIRECTORY" ]]; then
    log_error "Cann't download 'riverSpider'. See Canvas for download instructions."
  fi
  log_info "Downloading 'riverSpider'..."
  (curl -fsSL -o "$RIVER_SPIDER_OUTPUT_FILE" "https://drive.usercontent.google.com/download?id=${RIVER_SPIDER_GOOGLE_DRIVE_FILE_ID}&export=download&confirm=t" >>"$LOG_FILE" 2>&1) &
  local download_pid=$!
  progress_indicator "Downloading '${RIVER_SPIDER_ZIP_NAME}'" "$download_pid" "critical"

  mkdir -p "$RIVER_SPIDER_EXTRACT_DIRECTORY"
  (unzip "$RIVER_SPIDER_OUTPUT_FILE" -d "$RIVER_SPIDER_EXTRACT_DIRECTORY" >>"$LOG_FILE" 2>&1) &
  local unzip_pid=$!
  progress_indicator "Unzipping '${RIVER_SPIDER_ZIP_NAME}'" "$download_pid" "critical"
  sleep 0.1
  clean_up_riverspider_download
}

set_river_spider_dir_variable() {
  ensure_shell_profile_exists_and_writable
  if [[ -z "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR variable is not set."
  fi
  if [[ ! -d "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR path '$RIVER_SPIDER_DIR' is not a valid directory."
  fi
  export RIVER_SPIDER_DIR
  log_debug "Exported RIVER_SPIDER_DIR='$RIVER_SPIDER_DIR' for the current script session."
  local line_to_set="export RIVER_SPIDER_DIR=\"$RIVER_SPIDER_DIR\""
  local pattern_to_find="^export RIVER_SPIDER_DIR="
  log_debug "Ensuring shell profile ($SHELL_PROFILE_FILE) contains line: $line_to_set"

  # Check if a line matching the pattern already exists in the profile file.
  # 'grep -q' searches quietly.
  if grep -q "$pattern_to_find" "$SHELL_PROFILE_FILE"; then
    # If it exists, replace the old line with the new one using 'sed'.
    # 'sed -i''' modifies the file directly (the '' is needed for macOS compatibility).
    # '-e' specifies the command to run.
    # 's#pattern#replacement#' substitutes the pattern with the replacement.
    # '#' is used as the separator instead of '/' because the path contains '/'.
    # '.*' matches the rest of the existing line.
    # If sed fails ('||'), show a warning.
    sed -i'' -e "s#${pattern_to_find}.*#${line_to_set}#" "$SHELL_PROFILE_FILE" ||
      log_warning "Could not add RIVER_SPIDER_DIR to $SHELL_PROFILE_FILE. Add manually: $line_to_set"
  else
    # If the line doesn't exist, add it to the end of the file.
    # '{ echo ""; ...; echo ""; } >> file' appends the lines inside {} to the file.
    # Adds blank lines before and after for spacing.
    # If appending fails ('||'), show a warning.
    {
      echo ""
      echo "$line_to_set"
      echo ""
    } >>"$SHELL_PROFILE_FILE" ||
      log_warning "Could not add RIVER_SPIDER_DIR to $SHELL_PROFILE_FILE."
  fi
}

# Tries to find the 'riverSpider' directory, which should contain 'submit.sh'.
find_river_spider_directory() {
  if ! command_exists fd; then
    log_error "'fd' command not found. Cannot search for 'riverSpider' directory. Ensure 'fd' is installed."
  fi
  local temp_file
  local search_pid
  temp_file=$(mktemp) || log_error "Failed to create temporary file for search."
  log_info "Attempting to locate the riverSpider project directory..."
  log_debug "Searching within '$HOME' for a directory named 'riverSpider' containing '$SUBMIT_SCRIPT_NAME'..."
  (fd --type f "$SUBMIT_SCRIPT_NAME" "$HOME" --exec dirname {} \; | grep --color=never "/riverSpider$" | head -n 1 >"$temp_file") &
  search_pid=$!
  progress_indicator "Searching for 'riverSpider' directory" "$search_pid"
  local potential_dir
  potential_dir=$(<"$temp_file")
  # Check if a directory path was found ('-n' checks if string is not empty)
  # AND if that path actually points to a directory ('-d' checks if it's a directory).
  if ! [[ -n "$potential_dir" && -d "$potential_dir" ]]; then
    download_and_extract_riverspider
  elif [[ "$potential_dir" == "${RIVER_SPIDER_EXTRACT_DIRECTORY}/riverSpider" ]]; then
    clean_up_riverspider_download
  else
    log_success "Found 'riverSpider' at $potential_dir"
    RIVER_SPIDER_DIR="$potential_dir"
  fi
  ensure_secrets_initialized
}

update_path_in_submit_script() {
  if [[ -z "$RIVER_SPIDER_DIR" || ! -d "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR ('${RIVER_SPIDER_DIR}') is not set or invalid. Cannot update submit script. Ensure project location was found."
  fi
  if [[ -z "$SUBMIT_SCRIPT_NAME" ]]; then
    log_error "SUBMIT_SCRIPT_NAME ('${SUBMIT_SCRIPT_NAME}') is not set or invalid. Cannot update submit script. Ensure project location was found."
  fi
  local submit_script_path="${RIVER_SPIDER_DIR}/${SUBMIT_SCRIPT_NAME}"
  ensure_file_writable "$submit_script_path" "${SUBMIT_SCRIPT_NAME}"
  local old_line_pattern="$1" # The exact old line text
  local new_line_content="$2" # The new line text
  local path_description="$3"

  log_debug "Attempting to update ${submit_script_path}"
  log_debug "  Old line expected: '${old_line_pattern}'"
  log_debug "  New line content: '${new_line_content}'"
  if grep -Fxq -- "${new_line_content}" "${submit_script_path}"; then
    log_success " - ${path_description} path appears to be already correctly set in ${SUBMIT_SCRIPT_NAME}."
    return 0
  fi
  if ! grep -Fxq -- "${old_line_pattern}" "${submit_script_path}"; then
    log_warning " - Could not find '${path_description}' in '${SUBMIT_SCRIPT_NAME}'"
    return 1
  fi
  log_debug "Found the expected original line for '${path_description}'. Replacing it."
  if ! sed -i '' -e "s#${old_line_pattern}#${new_line_content}#" "$submit_script_path"; then
    log_warning " - Couldn't update path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
    return 1
  fi
  if ! grep -Fxq -- "$new_line_content" "$submit_script_path"; then
    log_warning " - Couldn't update path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
    return 1
  fi
  log_success " - Updated path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
}

# Changes relative paths (like 'secretString.txt') inside the submit.sh script
# to absolute paths (like '/Users/you/riverSpider/secretString.txt').
update_paths_in_riverspider_submit_script() {
  if [[ -z "$RIVER_SPIDER_DIR" || ! -d "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR ('$RIVER_SPIDER_DIR') is not set or invalid. Cannot update submit script. Ensure project location was found."
  fi
  if [[ -z "$SUBMIT_SCRIPT_NAME" ]]; then
    log_error "SUBMIT_SCRIPT_NAME ('$SUBMIT_SCRIPT_NAME') is not set or invalid. Cannot update submit script. Ensure project location was found."
  fi
  ensure_file_writable "${RIVER_SPIDER_DIR}/${SUBMIT_SCRIPT_NAME}" "${SUBMIT_SCRIPT_NAME}"
  echo
  log_info "Updating paths in the riverSpider submit script..."
  local new_secrets_path_line="secretPath=\"${RIVER_SPIDER_DIR}/${SECRET_FILE_NAME}\""
  local new_webapp_url_path_line="webappUrlPath=\"${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}\""
  local new_logisim_jar_path_line="logisimPath=\"${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}\""
  local new_processor_circ_path_line="processorCircPath=\"${RIVER_SPIDER_DIR}/${PROCESSOR_CIRC_FILE_NAME}\""
  local new_urlencode_sed_path_line="urlencodeSedPath=\"${RIVER_SPIDER_DIR}/${URLENCODE_SED_FILE_NAME}\""

  update_path_in_submit_script "$OLD_SECRETS_PATH_LINE" "$new_secrets_path_line" "Secret File"
  update_path_in_submit_script "$OLD_WEBAPP_URL_PATH_LINE" "$new_webapp_url_path_line" "WebApp URL File"
  update_path_in_submit_script "$OLD_LOGISIM_JAR_PATH_LINE" "$new_logisim_jar_path_line" "Logisim"
  update_path_in_submit_script "$OLD_PROCESSOR_CIRC_PATH_LINE" "$new_processor_circ_path_line" "Processor Circuit"
  update_path_in_submit_script "$OLD_URLENCODE_SED_PATH_LINE" "$new_urlencode_sed_path_line" "URLEncode Sed Script"

}

# Adds a new, easy-to-use command 'riverspider' to your shell profile file.
# This command makes running the main submit.sh script simpler.
add_river_spider_shell_helper_function() {
  ensure_shell_profile_exists_and_writable
  echo
  log_info "Setting up River Spider helper function..."
  local helper_function_name="riverspider"

  if grep -q "^${helper_function_name}()" "$SHELL_PROFILE_FILE"; then
    log_success "'$helper_function_name' helper function already in shell profile"
  else
    log_info "Adding River Spider helper function..."
    cat <<'EOF' >>"$SHELL_PROFILE_FILE"
#=======  River Spider helper function =======
riverspider() {
  local ttpasm_file=$1
  if [[ -z "$ttpasm_file" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: riverspider <filename>.ttpasm"
    return 1
  fi
  if [[ "${ttpasm_file##*.}" != "ttpasm" ]]; then
    echo "Error: File must have .ttpasm extension."
    return 1
  fi
  if [[ ! -f "$ttpasm_file" ]]; then
    echo "Error: File '$ttpasm_file' not found."
    return 1
  fi
  locate_riverspider_dir || return 1
  "$RIVER_SPIDER_DIR/submit.sh" "$(realpath "$ttpasm_file")"
}
locate_riverspider_dir() {
  if [[ -z "${RIVER_SPIDER_DIR:-}" || ! -d "$RIVER_SPIDER_DIR" ]]; then
    RIVER_SPIDER_DIR=$(fd --type f submit.sh "$HOME" --exec dirname {} \; | grep "/riverSpider$" | head -n 1)
    if [[ -z "$RIVER_SPIDER_DIR" || ! -d "$RIVER_SPIDER_DIR" ]]; then
      echo "Error: Could not locate the riverSpider directory."
      echo "See Canvas for download instructions."
      return 1
    fi
    export RIVER_SPIDER_DIR
    add_riverspider_to_profile "export RIVER_SPIDER_DIR=\"$RIVER_SPIDER_DIR\""
  fi
}
add_riverspider_to_profile() {
  local line_to_set="$1"
  local pattern_to_find="^export RIVER_SPIDER_DIR="
  local current_shell="$(basename "${SHELL:-}")"
  local shell_profile=""
  case "$current_shell" in
    zsh) shell_profile="${ZDOTDIR:-$HOME}/.zprofile" ;;
    bash) shell_profile="$HOME/.bash_profile" ;;
  esac
  if [[ -z "$shell_profile" || ! -f "$shell_profile" ]]; then
    echo "Could not add RIVER_SPIDER_DIR to shell profile."
    echo "Add manually: $line_to_set"
    return 0
  fi
  if grep -q "$pattern_to_find" "$shell_profile"; then
    sed -i'' -e "s#${pattern_to_find}.*#${line_to_set}#" "$shell_profile" ||
      echo "Could not add RIVER_SPIDER_DIR to $shell_profile. Add manually: $line_to_set"
  else
    { echo ""; echo "$line_to_set"; echo "";} >> "$shell_profile" ||
      echo "Could not add RIVER_SPIDER_DIR to $shell_profile. Add manually: $line_to_set"
  fi
}
#=============================================

#=======  Logisim helper function =======

logisim() {
  if [[ "$#" -eq 0 ]]; then
    java -jar "$RIVER_SPIDER_DIR/logisim310.jar"
    return $?
  fi

  local arg1="$1"

  if [[ "$arg1" == "-h" || "$arg1" == "--help" ]]; then
    echo "Usage: logisim [<filename.circ>]"
    echo "       logisim -h | --help     Show this help message"
    echo ""
    return 1
  fi

  if [[ "${arg1##*.}" != "circ" ]]; then
    echo "Error: File '$arg1' must have a .circ extension." >&2
    return 1
  fi

  if [[ ! -f "$arg1" ]]; then
    echo "Error: File '$arg1' not found." >&2
    return 1
  fi

  java -jar "$RIVER_SPIDER_DIR/logisim310.jar" "$arg1"
  
  return $? 
}

logproc(){
  java -jar "$RIVER_SPIDER_DIR/logisim310.jar" "$RIVER_SPIDER_DIR/processor0004.circ"
}

logalu(){
  java -jar "$RIVER_SPIDER_DIR/logisim310.jar" "$RIVER_SPIDER_DIR/alu.circ"
}

logreg(){
  java -jar "$RIVER_SPIDER_DIR/logisim310.jar" "$RIVER_SPIDER_DIR/regbank.circ"
}

#========================================
EOF

    echo "" >>"$SHELL_PROFILE_FILE"
    sed -i '' -e "s#zsh) shell_profile=.*#zsh) shell_profile=\"\${ZDOTDIR:-\$HOME}/${ZSH_PROFILE_BASENAME}\" ;;#" "$SHELL_PROFILE_FILE" ||
      log_warning "Could not update shell_profile for ZSH in $SHELL_PROFILE_FILE. Add manually: $ZSH_PROFILE_BASENAME"
    sed -i '' -e "s#bash) shell_profile=.*#bash) shell_profile=\"\$HOME/${BASH_PROFILE_BASENAME}\" ;;#" "$SHELL_PROFILE_FILE" ||
      log_warning "Could not update shell_profile for BASH in $SHELL_PROFILE_FILE. Add manually: $BASH_PROFILE_BASENAME"
    if grep -q "${helper_function_name}()" "$SHELL_PROFILE_FILE"; then
      log_success "Added '$helper_function_name' helper function to shell profile"
      log_debug "Confirmed '$helper_function_name' helper function exists in $SHELL_PROFILE_FILE."
    else
      log_warning "Failed to add '$helper_function_name' helper function."
    fi
  fi
}

# ========================================================================

display_startup_message() {
  ensure_file_writable "$LOG_FILE" "LOG file"
  echo "───────────────────────────────────────────────" >"$LOG_FILE"
  echo "Setup started at $(date)" >>"$LOG_FILE"
  echo "───────────────────────────────────────────────" >>"$LOG_FILE"
  echo "================================================="
  log_info "Starting riverSpider setup script"
  log_info "Setup started at: $(date)"
  log_info "Setup logfile:    $LOG_FILE"
  echo "================================================="
  echo
  echo
}

display_completion_message() {
  printf "\n"
  log_info "================================================="
  log_info "         riverSpider Setup Complete"
  log_info "================================================="
  printf "\n"
  log_info "${tty_bold}---All automated setup steps finished.---${tty_reset}"
  log_info "Please look back at any ${tty_yellow}'Warning:'${tty_reset} messages just in case."
  printf "\n"
  log_info "${tty_bold}--- IMPORTANT NEXT STEPS ---${tty_reset}"
  log_info "1. ${tty_yellow}Restart your Terminal:${tty_reset}"
  log_info "   (Alternatively, for your ${tty_bold}current terminal window only)${tty_reset}, you could run:"
  log_info "      ${tty_green}source${tty_reset} $SHELL_PROFILE_FILE"
  printf "\n"
  log_info "2. ${tty_yellow}Complete Manual Google App Script Setup:${tty_reset}"
  log_info "   If you haven't done it yet, follow the Google App Script setup instructions"
  log_info "   and make sure to save the Web App URL in:"
  log_info "      ${tty_green}${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}${tty_reset}"
  printf "\n"
  log_info "After restarting your terminal and doing the Google App Script setup,"
  log_info "you can use the new command like this:"
  log_info "      ${tty_green}riverspider${tty_reset} ${tty_yellow}<your_file.ttpasm>${tty_reset}"
  log_info "(You can run this from any folder)."
  printf "\n"
  log_info "───────────────────────────────────────────────"
  log_info "   Details about everything the script did were saved to:"
  log_info "      ${tty_green}$LOG_FILE${tty_reset}"
  log_info "───────────────────────────────────────────────"
  log_info "Script finished execution successfully at $(date +%Y-%m-%d_%H:%M:%S)"
  log_info "================================================="
}

# This part of the setup cannot be automated by the script.
display_google_apps_script_setup_instructions() {
  echo ""
  log_info "Manual setup of Google App Script:"
  echo ""
  echo "👉 Make a copy of:"
  echo ""
  echo "   shared/processor/${GOOGLE_SHEETS_DOC_NAME}"
  echo "   ${GOOGLE_DRIVE_FOLDER_URL}"
  echo ""
  echo "   File > Make a Copy"
  echo "   Save it to: My Drive"
  echo ""
  echo "   Click: 'Make a Copy'"
  echo ""
  echo "🔧 In your copy:"
  echo "   Extensions > Apps Script"
  echo "   Deploy > New Deployment"
  echo ""
  echo "   Description:    River Spider Script"
  echo "   Execute as:     Me"
  echo "   Access:         Anyone"
  echo ""
  echo "   Click: 'Deploy'"
  echo ""
  echo "✅ Authorize and allow access"
  echo ""
  echo "🔗 Copy the 'Web App URL'"
  echo ""
  open "${GOOGLE_DRIVE_FOLDER_URL}"
}

setup_google_webapp_url() {
  local answer=""
  local web_app_url=""
  local prompt="❓ Would you like to view Google Apps Script setup instructions? [Y/n]: "

  while true; do
    printf "\n"
    read -rp "$prompt" answer
    case "$answer" in
    "" | [Yy]*)
      display_google_apps_script_setup_instructions

      while true; do
        read -rp "📥 Paste the Web App URL (or 'q' to cancel): " web_app_url
        if [[ "$web_app_url" =~ ^[Qq]$ ]]; then
          echo ""
          echo "❌ URL entry cancelled by user."
          echo ""
          exit 1
        fi

        # Strip surrounding quotes if present
        web_app_url="${web_app_url%\"}"
        web_app_url="${web_app_url#\"}"
        if [[ "$web_app_url" =~ ^https://script\.google\.com/macros/s/.+/exec$ ]]; then
          ensure_file_writable "$RIVER_SPIDER_DIR/$WEBAPP_URL_FILE_NAME" "Web App url"
          echo "$web_app_url" >"$RIVER_SPIDER_DIR/$WEBAPP_URL_FILE_NAME"
          echo ""
          echo "📝 Web App URL saved to: ${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}"
          echo ""
          break
        else
          log_warning "⛓️‍💥 Invalid URL."
          echo "It must match: https://script.google.com/macros/s/{ID}/exec"
          echo ""
        fi
      done
      break
      ;;
    [Nn]*)
      echo ""
      echo "⏭️  Setup instructions skipped."
      echo ""
      break
      ;;
    *)
      echo ""
      log_warning "⁉️ Please answer [Y]es or [N]o."
      ;;
    esac
  done
}

main() {
  # Set up the colors for messages.
  setup_terminal_colors
  # Create/clear the log file and show starting messages on screen.
  display_startup_message

  log_info "=== PHASE 1: System Validation ==="
  echo "───────────────────────────────────────────────"
  check_required_system_commands          # Are basic tools present?
  check_operating_system_and_architecture # Is it macOS? Intel/Apple Silicon?
  check_internet_connectivity             # Can it reach the internet?
  determine_shell_and_profile             # Which shell? Where's the profile file?
  echo "───────────────────────────────────────────────"
  log_success "System validation complete."
  echo
  echo
  log_info "=== PHASE 2: Dependency Installation ==="
  echo "───────────────────────────────────────────────"
  setup_homebrew_environment # Install/configure/update Homebrew.
  install_required_packages  # Install mise, fd, etc.
  verify_installed_tools     # Check installed tools are working.
  configure_mise_environment # Set up mise in the shell.
  install_java_with_mise     # Install OpenJDK using mise.
  echo "───────────────────────────────────────────────"
  log_success "Dependency installation complete."
  echo
  echo
  log_info "=== PHASE 3: 'riverSpider' Setup ==="
  echo "───────────────────────────────────────────────"
  find_river_spider_directory               # Find or download the riverSpider folder.
  set_river_spider_dir_variable             # Always remember where the riverSpider folder is.
  update_paths_in_riverspider_submit_script # Fix paths inside submit.sh (so it can be called from anywhere)
  add_river_spider_shell_helper_function    # Add the 'riverspider' command.
  echo "───────────────────────────────────────────────"
  log_success "'riverSpider' configuration complete."
  echo

  # Show the final "all done" message.
  display_completion_message
  # Show Google Sheets steps, and/or add Web App URL to webapp.url file
  setup_google_webapp_url
  return 0
}

main "$@"
exit $?
