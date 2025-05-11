#!/usr/bin/env bash
# ======================================================================================================================================
# riverSpider macOS Setup Script
#
# Author: Ilya Babenko
# Last updated: 2025-05-08
# Version: 2.4.0
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
#   Alternatively, save this script as install.sh, make it executable (chmod +x install.sh),
#   and run it with: bash ./install.sh
# ======================================================================================================================================

# -e: Stop right away if any command fails (has an error).
# -u: Stop if the script tries to use a name (variable) that hasn't been given a value.
# -o pipefail: If commands are chained with '|' (like command A | command B),
#              stop if any command in the chain fails.
set -euo pipefail

# =========================== Global Variables ===========================

# ===========================   OK TO CHANGE   ===========================

# The name of the folder where 'riverSpider' is located.
readonly RIVER_SPIDER_DIR_NAME="riverSpider"
# --- Shell Settings Filenames ---
# Default names for the shell configuration files.
# You might need to change these if you use different filenames like '.zshrc' or '.bashrc'.
readonly ZSH_PROFILE_BASENAME=".zprofile"      # For Zsh shell
readonly BASH_PROFILE_BASENAME=".bash_profile" # For Bash shell

# --- Google Drive Info  ---
# Link and name used in the manual setup instructions for Google Sheets.
readonly GOOGLE_SHEETS_DOC_URL="https://docs.google.com/spreadsheets/d/18Ln5Sivnq3Kwe9QaxTbgoJzahjdz34FqQDD_QwiiVOU/edit?gid=384184973#gid=384184973"
readonly GOOGLE_SHEETS_DOC_NAME="'Copy of assemblerStudent'" # The name of the sheet template
readonly TTPASM_APP_SCRIPT_DEFAULT_PASSWD="1234!@#\$qwerQWER"
# --- Download riverSpider from Google Drive ---
readonly RIVER_SPIDER_GOOGLE_DRIVE_FILE_ID="1g63nlTRa-Ibgj0ZUf3HX1fbdSrW90JBs"
readonly RIVER_SPIDER_ZIP_NAME="riverSpiderForMac.zip"
readonly RIVER_SPIDER_OUTPUT_FILE="${HOME}/${RIVER_SPIDER_ZIP_NAME}"
readonly RIVER_SPIDER_EXTRACT_DIRECTORY="$(mktemp -d)"
readonly RIVER_SPIDER_TARGET_DIRECTORY="${HOME}/${RIVER_SPIDER_DIR_NAME}"

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
readonly ALU_CIRC_FILE_NAME="alu.circ"
readonly REGBANK_FILE_CIRC_FILE_NAME="regbank.circ"
readonly URLENCODE_SED_FILE_NAME="urlencode.sed"

# =======================  END OK TO CHANGE  ========================

# ========================== DO NOT CHANGE ==========================

readonly START_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# --- Log File ---
# Creates a new log file with the date and time in its name each time the script runs.
readonly LOG_FILE="$(mktemp "/tmp/riverspider_setup_${START_TIMESTAMP}.log")"

# --- Homebrew Install Url ---
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# --- Homebrew Binary Location ---
readonly ARM_HOMEBREW_PATH="/opt/homebrew/bin/brew" # Usual place on Apple Silicon Macs
readonly INTEL_HOMEBREW_PATH="/usr/local/bin/brew"  # Usual place on Intel Macs

# --- Needed Commands & Tools ---
# Basic commands the script expects to find on the Mac.
readonly REQUIRED_SYSTEM_COMMANDS=("mkdir" "open" "rm" "dirname" "basename" "realpath" "touch" "cat" "echo" "printf" "head" "ping" "curl" "unzip" "git" "uname" "sw_vers" "grep" "sed" "tr" "sleep")
# Java that WORKS with logisim
readonly JDK_MISE_NAME="java@openjdk"
readonly JDK_MISE_BACKUP_VERSION="openjdk-19.0.2"
readonly HOMEBREW_PACKAGES_TO_INSTALL=("coreutils" "wget" "mise" "fd")
# Ensure tools are working after installation.
readonly INSTALLED_TOOLS_TO_VERIFY=("timeout" "wget" "mise" "fd")

# --- Internet Test Domains ---
readonly CHECK_DOMAINS=("www.google.com" "www.apple.com" "github.com")

declare FIND_ATTEMPT_COUNT=0 # How many times we've looked for the 'riverSpider' folder.
readonly MAX_FIND_ATTEMPTS=2 # How many times to look for the 'riverSpider' folder.
# ========================= END DO NOT CHANGE =======================

# ===================================================================
# These get their actual values while the script runs.
# Declaring them here makes it clear what information the script keeps track of.

declare DEBUG="false" # If true, shows debug info in the terminal window.
# can be enabled by running the script with the '-d' or '--debug' option.
declare QUIET="false" # If true, suppresses all output except errors.

declare CURRENT_SHELL=""          # Which shell is being used ("zsh" or "bash").
declare SHELL_PROFILE_FILE=""     # Full path to the shell's settings file (like ~/.zprofile).
declare HOMEBREW_PATH=""          # Where the Homebrew 'brew' command is located.
declare PROCESSOR_ARCHITECTURE="" # The computer's chip type ("arm64" or "x86_64").
declare CHIP_TYPE=""              # A friendly name for the chip ("Apple Silicon" or "Intel Processor").
declare MISE_SHELL_TYPE=""        # The shell name 'mise' needs ("zsh" or "bash").
declare RIVER_SPIDER_DIR=""       # Full path to where the 'riverSpider' folder was found.

declare TTY_BLUE=""   # Blue color for terminal messages.
declare TTY_RED=""    # Red color for terminal messages.
declare TTY_YELLOW="" # Yellow color for terminal messages.
declare TTY_GREEN=""  # Green color for terminal messages.
declare TTY_BOLD=""   # Bold text for terminal messages.
declare TTY_RESET=""  # Reset text color for terminal messages.
# ===================================================================

# =========================== HELPER UTILITIES ===========================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_file_writable() {
  local file_path="$1"
  local file_description="${2:-"File"}"
  if [[ -z "${file_path}" ]]; then
    echo "[ERROR] File path argument is missing for ensure_file_writable." >>"${LOG_FILE}"
    echo "[ERROR] File path argument is missing for ensure_file_writable." >&2
    exit 1
  fi
  if [[ -z "${LOG_FILE}" ]]; then
    echo "[ERROR] LOG_FILE variable is not set. Cannot proceed." >&2
    exit 1
  fi
  if [[ -e "${LOG_FILE}" && ! -w "${LOG_FILE}" ]]; then
    echo "[ERROR] Log file is not writable: ${LOG_FILE}" >&2
    exit 1
  fi
  echo "[DEBUG] Checking if ${file_description} is writable: ${file_path}" >>"${LOG_FILE}"
  if [[ ! -e "${file_path}" ]]; then
    echo "[DEBUG] File does not exist: ${file_path}" >>"${LOG_FILE}"
    # File doesn't exist, check parent directory
    local parent_dir
    parent_dir=$(dirname "${file_path}")
    if ! mkdir -p "${parent_dir}"; then
      echo "[ERROR] Failed to create parent directory: ${parent_dir} for ${file_description}." >>"${LOG_FILE}"
      echo "[ERROR] Failed to create parent directory: ${parent_dir} for ${file_description}." >&2
      exit 1
    fi
    echo "[DEBUG] Parent directory created: ${parent_dir}" >>"${LOG_FILE}"
    if [[ ! -w "${parent_dir}" ]]; then
      echo "[ERROR] Parent directory not writable: ${parent_dir} for ${file_description}." >>"${LOG_FILE}"
      echo "[ERROR] Parent directory not writable: ${parent_dir} for ${file_description}." >&2
      exit 1
    fi
    echo "[DEBUG] Parent directory is writable: ${parent_dir}" >>"${LOG_FILE}"
    if ! touch "${file_path}"; then
      echo "[ERROR] Failed to create ${file_description} at: ${file_path}." >>"${LOG_FILE}"
      echo "[ERROR] Failed to create ${file_description} at: ${file_path}." >&2
      exit 1
    fi
    echo "[DEBUG] Created ${file_description} at: ${file_path}" >>"${LOG_FILE}"
  elif [[ ! -f "${file_path}" ]]; then
    # Path exists but is not a regular file

    echo "[ERROR] Path exists but is not a regular file: ${file_path} for ${file_description}." >&2
    exit 1
  fi
  echo "[DEBUG] File exists: ${file_path}" >>"${LOG_FILE}"
  if [[ ! -w "${file_path}" ]]; then
    echo "[DEBUG] File is not writable: ${file_path}" >>"${LOG_FILE}"
    if ! chmod u+w "${file_path}"; then
      echo "[ERROR] Failed to make ${file_description} writable (chmod failed): ${file_path}." >>"${LOG_FILE}"
      echo "[ERROR] Failed to make ${file_description} writable (chmod failed): ${file_path}." >&2
      exit 1
    fi
    echo "[DEBUG] Changed ${file_description} permissions: ${file_path}" >>"${LOG_FILE}"
    if [[ ! -w "${file_path}" ]]; then
      echo "[ERROR] Still not writable after chmod (unexpected): ${file_path} for ${file_description}." >>"${LOG_FILE}"
      echo "[ERROR] Still not writable after chmod (unexpected): ${file_path} for ${file_description}." >&2
      exit 1
    fi
    echo "[DEBUG] File is writable: ${file_path}" >>"${LOG_FILE}"
  fi
}
ensure_global_variable_has_value() {
  if [[ $# -eq 0 ]]; then
    echo "[ERROR] Missing arguments. Please provide the names of global variables to check." >>"${LOG_FILE}"
    echo "[ERROR] Missing arguments. Please provide the names of global variables to check." >&2
    exit 1
  fi
  if [[ -z "${LOG_FILE}" ]]; then
    echo "[ERROR] LOG_FILE variable is not set. Cannot proceed." >&2
    exit 1
  fi
  ensure_file_writable "${LOG_FILE}" "LOG file"
  echo "[DEBUG] Checking global variables: $*" >>"${LOG_FILE}"
  local missing_value=()
  for global_variable_name in "$@"; do
    if [[ -z "${!global_variable_name}" ]]; then
      missing_value+=("${global_variable_name}")
    fi
  done

  if [[ ${#missing_value[@]} -gt 0 ]]; then
    echo "[ERROR] Required variable(s) missing value(s): ${missing_value[*]}" >>"${LOG_FILE}"
    echo "[ERROR] Required variable(s) missing value(s): ${missing_value[*]}" >&2
    exit 1
  fi
  echo "[DEBUG] All required global variables have values." >>"${LOG_FILE}"
}
ensure_log_file_exists_and_writable() {
  ensure_global_variable_has_value "LOG_FILE"
  ensure_file_writable "${LOG_FILE}" "LOG file"
  echo "[DEBUG] Ensuring log file exists and is writable." >>"${LOG_FILE}"
}

ensure_shell_profile_exists_and_writable() {
  ensure_global_variable_has_value "SHELL_PROFILE_FILE"
  ensure_log_file_exists_and_writable
  local msg="${1:-"shell profile file"}"
  ensure_file_writable "${SHELL_PROFILE_FILE}" "${msg}"
  echo "[DEBUG] Ensuring shell profile file exists and is writable." >>"${LOG_FILE}"
}
ensure_directory_exists() {
  if [[ $# -eq 0 ]]; then
    echo "[ERROR] Missing arguments. Please provide the names of directories to check." >>"${LOG_FILE}"
    echo "[ERROR] Missing arguments. Please provide the names of directories to check." >&2
    exit 1
  fi
  ensure_log_file_exists_and_writable
  echo "[DEBUG] Ensuring directory(ies) exist(s): $*" >>"${LOG_FILE}"
  local missing_directory=()
  for directory in "$@"; do
    if [[ ! -d "${directory}" ]]; then
      missing_directory+=("${directory}")
    fi
  done
  if [[ ${#missing_directory[@]} -gt 0 ]]; then
    echo "[ERROR] Required directory(ies) not found: ${missing_directory[*]}" >>"${LOG_FILE}"
    echo "[ERROR] Required directory(ies) not found: ${missing_directory[*]}" >&2
    exit 1
  fi
  echo "[DEBUG] All required directories exist." >>"${LOG_FILE}"
}
ensure_directory_exists_and_writable() {
  if [[ $# -eq 0 ]]; then
    echo "[ERROR] Missing arguments for ensure_directory_exists_and_writable." >>"${LOG_FILE}"
    echo "[ERROR] Missing arguments for ensure_directory_exists_and_writable." >&2
    exit 1
  fi
  ensure_log_file_exists_and_writable
  echo "[DEBUG] Ensuring directory(ies) are writable: $*" >>"${LOG_FILE}"
  ensure_directory_exists "$@"
  local not_writeable_directory=()
  for directory in "$@"; do
    if [[ ! -w "${directory}" ]]; then
      echo "[DEBUG] Directory is not writable: ${directory}" >>"${LOG_FILE}"
      chmod -R +w "${directory}"
      echo "[DEBUG] Changed permissions for directory: ${directory}" >>"${LOG_FILE}"
      if [[ ! -w "${directory}" ]]; then
        echo "[ERROR] Directory is still not writable after chmod: ${directory}" >>"${LOG_FILE}"
        not_writeable_directory+=("${directory}")
      fi
    fi

  done
  if [[ ${#not_writeable_directory[@]} -gt 0 ]]; then
    echo "[ERROR] Directory(ies) not writable: ${not_writeable_directory[*]}" >>"${LOG_FILE}"
    echo "[ERROR] Directory(ies) not writable: ${not_writeable_directory[*]}" >&2
    exit 1
  fi
  echo "[DEBUG] All required directories are writable." >>"${LOG_FILE}"
}

add_line_if_missing() {
  ensure_log_file_exists_and_writable
  local line="$1" # The text line to add.
  local file="$2" # The file to add the line to.

  if [[ -z "${line}" || -z "${file}" ]]; then
    echo "[ERROR] Cannot add line to file: one of the arguments is missing." >>"${LOG_FILE}"
    echo "[ERROR] Cannot add line to file: one of the arguments is missing." >&2
    exit 1
  fi

  ensure_file_writable "${file}"
  # Add the line if it's not already in the file.
  if ! grep -Fxq -- "${line}" "${file}"; then
    echo "[DEBUG] Adding line to ${file}: ${line}" >>"${LOG_FILE}"
    echo "" >>"${file}"
    echo "${line}" >>"${file}"
    echo "" >>"${file}"
    return 0
  fi
  echo "[DEBUG] Line already exists in ${file}: ${line}" >>"${LOG_FILE}"
  return 0
}

print_separator() {
  if [[ "${QUIET}" == "false" ]]; then
    echo "───────────────────────────────────────────────"
  fi
}

print_newline() {
  if [[ "${QUIET}" == "false" ]]; then
    echo
  fi
}

print_help() {
  local script_name
  script_name=$(basename "$0")
  echo "Usage: ${script_name} [options]"
  echo ""
  echo "Options:"
  echo "  -d, --debug      Enable debug output."
  echo "  -q, --quiet      Suppress normal output (quiet mode)."
  echo "  -h, --help       Display this help message :)"
}

# ========================================================================

# ==========================  MESSAGE HELPERS  ===========================

setup_terminal_colors() {
  if [[ -t 1 ]]; then
    echo "[DEBUG] Terminal colors are enabled." >>"${LOG_FILE}"
    tty_escape() { printf "\033[%sm" "$1"; }
  else
    echo "[DEBUG] Terminal colors are disabled (not a terminal)." >>"${LOG_FILE}"
    tty_escape() { :; }
  fi

  tty_mkbold() { tty_escape "1;$1"; }

  TTY_BLUE=$(tty_mkbold 34)   # Blue color
  TTY_RED=$(tty_mkbold 31)    # Red color
  TTY_YELLOW=$(tty_mkbold 33) # Yellow color
  TTY_GREEN=$(tty_mkbold 32)  # Green color
  TTY_BOLD=$(tty_mkbold 39)   # Bold text
  TTY_RESET=$(tty_escape 0)   # Reset text to normal
}

log_info() {
  ensure_global_variable_has_value "TTY_BLUE" "TTY_BOLD" "TTY_RESET"
  ensure_log_file_exists_and_writable
  local msg="$*"
  if [[ "${QUIET}" == "false" ]]; then
    printf "${TTY_BLUE}==>${TTY_BOLD} %s${TTY_RESET}\n" "${msg}"
  fi
  echo "[INFO] ${msg}" >>"${LOG_FILE}"
}

log_success() {
  ensure_global_variable_has_value "TTY_GREEN" "TTY_RESET"
  ensure_log_file_exists_and_writable
  local msg="$*"
  if [[ "${QUIET}" == "false" ]]; then
    printf "${TTY_GREEN}✓${TTY_RESET} %s\n" "${msg}"
  fi
  echo "[SUCCESS] ${msg}" >>"${LOG_FILE}"
}

log_warning() {
  ensure_global_variable_has_value "TTY_YELLOW" "TTY_RESET"
  ensure_log_file_exists_and_writable
  local msg="$*"
  printf "${TTY_YELLOW}Warning${TTY_RESET}: %s\n" "${msg}" >&2
  echo "[WARNING] ${msg}" >>"${LOG_FILE}"
}

# Shows error messages and stops the script.
log_error() {
  ensure_global_variable_has_value "TTY_RED" "TTY_RESET"
  ensure_log_file_exists_and_writable
  local abort_timestamp
  abort_timestamp="$(date +%Y%m%d_%H%M%S)"
  local msg="$*"
  printf "${TTY_RED}Error${TTY_RESET}: %s\n" "${msg}" >&2
  echo "[ERROR] ${msg}" >>"${LOG_FILE}"
  echo "[ERROR] Script aborted at ${abort_timestamp}" >>"${LOG_FILE}"
  echo "[ERROR] Script aborted at ${abort_timestamp}. Check log file: ${LOG_FILE}" >&2
  exit 1
}

# Writes extra details (debug info) by default only to the log file.
log_debug() {
  ensure_global_variable_has_value "DEBUG"
  ensure_log_file_exists_and_writable
  local debug_mode="${DEBUG:-false}"
  if [[ "${debug_mode}" == "true" && "${QUIET}" == "false" ]]; then
    echo "[DEBUG] $*"
  fi
  echo "[DEBUG] $*" >>"${LOG_FILE}"
}
# ========================================================================

# =========================== PRE FLIGHT CHECKS ==========================

check_required_system_commands() {
  ensure_global_variable_has_value "REQUIRED_SYSTEM_COMMANDS"
  log_info "Checking for essential commands..."
  local missing_commands=()

  for command_name in "${REQUIRED_SYSTEM_COMMANDS[@]}"; do
    if ! command_exists "${command_name}"; then
      # If command is not found, add it to the missing list.
      missing_commands+=("${command_name}")
    else
      log_debug "Command '${command_name}' found at: $(command -v "${command_name}")"
    fi
  done
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    log_error "Required command(s) missing: ${missing_commands[*]}. Please install them or ensure they are in your PATH."
  fi
  log_success "All required commands are available."
}

check_operating_system_and_architecture() {
  ensure_directory_exists "/usr/bin/"
  log_info "Checking operating system and architecture..."
  # Check if the Operating System is macOS ('Darwin').
  # 'uname -s' gets the OS name.
  local system="$(/usr/bin/uname -s)"
  if [[ "${system}" != "Darwin" ]]; then
    log_error "This script is designed for macOS only. Detected OS: ${system}"
  fi
  log_debug "Operating system confirmed as macOS (Darwin)."
  # Get the macOS version number.
  local os_version
  # 'sw_vers -productVersion' gets the version (e.g., "14.4.1").
  os_version=$(sw_vers -productVersion) || os_version="Unknown"
  log_debug "Detected macOS version: ${os_version}"
  # Find out the chip architecture.
  # 'uname -m' gets the hardware name (e.g., "arm64", "x86_64").
  PROCESSOR_ARCHITECTURE="$(/usr/bin/uname -m)"
  log_debug "Detected ${PROCESSOR_ARCHITECTURE} architecture."
  case "${PROCESSOR_ARCHITECTURE}" in
  arm64)
    HOMEBREW_PATH="${ARM_HOMEBREW_PATH}" # Expected Homebrew location
    CHIP_TYPE="Apple Silicon"
    log_debug "Architecture is arm64 '${CHIP_TYPE}'. Expecting Homebrew at ${HOMEBREW_PATH}."
    ;;
  x86_64)
    HOMEBREW_PATH="${INTEL_HOMEBREW_PATH}" # Expected Homebrew location
    CHIP_TYPE="Intel Processor"
    log_debug "Architecture is x86_64 (Intel). Expecting Homebrew at ${HOMEBREW_PATH}."
    ;;
  *)
    log_error "Unsupported processor architecture: '${PROCESSOR_ARCHITECTURE}'. This script supports arm64 (Apple Silicon) and x86_64 (Intel)."
    ;;
  esac
  ensure_global_variable_has_value "HOMEBREW_PATH" "CHIP_TYPE"
  log_success "System validated: macOS Version ${os_version} (${CHIP_TYPE})"
}

# Checks if the computer is connected to the internet.
# Tries to 'ping' a few reliable websites. Stops with error if none work.
check_internet_connectivity() {
  ensure_global_variable_has_value "CHECK_DOMAINS"
  log_info "Checking internet connectivity..."
  for domain in "${CHECK_DOMAINS[@]}"; do
    log_debug "Pinging ${domain}..."
    # Try to 'ping' (send a small test message) to the website.
    # '-c 1' sends 1 ping. '-W 3' waits 3 seconds for reply. '&>/dev/null' hides output.
    if ping -c 1 -W 3 "${domain}" &>/dev/null; then
      log_debug "Successfully pinged ${domain}."
      log_success "Internet connection 'OK'"
      return 0 # Found connection, stop checking.
    fi
  done
  log_error "No internet connection detected. Please check your network."
}

# Figures out which shell (bash or zsh) the user has and where its settings file is.
determine_shell_and_profile() {
  ensure_global_variable_has_value "ZSH_PROFILE_BASENAME" "BASH_PROFILE_BASENAME"
  log_info "Detecting user shell and profile file..."
  CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"
  log_debug "Detected shell command based on \$SHELL: ${CURRENT_SHELL}"
  case "${CURRENT_SHELL}" in
  zsh)
    SHELL_PROFILE_FILE="${ZDOTDIR:-$HOME}/${ZSH_PROFILE_BASENAME}"
    MISE_SHELL_TYPE="zsh"
    ensure_shell_profile_exists_and_writable "ZSH profile file"
    log_success "Detected shell: zsh"
    log_debug "Using Zsh profile: ${SHELL_PROFILE_FILE}"
    ;;
  bash)
    SHELL_PROFILE_FILE="${HOME}/${BASH_PROFILE_BASENAME}"
    MISE_SHELL_TYPE="bash"
    ensure_shell_profile_exists_and_writable "BASH profile file"
    log_success "Detected shell: bash"
    log_debug "Using Bash profile: ${SHELL_PROFILE_FILE}"
    ;;
  *)
    log_error "Unsupported shell detected: '${CURRENT_SHELL}'. This script requires Bash or Zsh."
    ;;
  esac
  ensure_global_variable_has_value "MISE_SHELL_TYPE"
  log_info "Shell profile file set to: ${SHELL_PROFILE_FILE}"
  log_debug "Mise shell type for activation set to: ${MISE_SHELL_TYPE}"
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
  log_debug "Starting progress indicator for PID ${background_pid} (Task: ${task_name}, Critical: $([[ "${critical}" == "critical" ]] && echo true || echo false))"
  if [[ "${QUIET}" == "false" ]]; then

    # Keep spinning as long as the background process is still running.
    # 'kill -0 $pid' checks if the process exists without stopping it. '2>/dev/null' hides errors.
    while kill -0 "${background_pid}" 2>/dev/null; do
      i=$(((i + 1) % 4)) # Cycle through the 4 spinning characters.
      # '\r' moves the cursor back to the start of the line to overwrite.
      # '${spin:$i:1}' gets one character from the 'spin' string at position 'i'.
      printf "\r %s %c " "${task_name}" "${spin_chars:$i:1}"
      sleep 0.1 # Wait a very short time (0.1 seconds) before the next spin update.
    done
    # After the process finishes, clear the spinning line
    printf "\r                                   \r"
  fi
  local exit_status=0
  # 'wait $pid' waits for the background process to fully finish and gets its exit code.
  # The exit code tells us if the process succeeded (0) or failed (non-zero).
  wait "${background_pid}" || exit_status=$?

  log_debug "PID ${background_pid} ('${task_name}') finished with exit status ${exit_status}."
  # Check if the background process finished successfully (exit code 0).
  if [ "${exit_status}" -eq 0 ]; then
    task_name=$(echo "${task_name}" | sed 's/Downloading /downloaded /; s/Unzipping /unzipped /; s/Installing /installed /; s/Searching for /found /; s/Homebrew Update/updated Homebrew/')
    log_success "Successfully ${task_name}"
  else
    task_name=$(echo "${task_name}" | sed 's/Downloading /Download /; s/Unzipping /Unzip /; s/Installing /Install /; s/Searching for /find /; s/Homebrew Update/update Homebrew/')
    if [[ "${critical}" == "true" ]]; then
      log_error "Failed to ${task_name}. Check the log file: ${LOG_FILE}"
    else
      log_warning "Failed to ${task_name}. Check the log file: ${LOG_FILE}"
    fi
  fi
}

# ========================================================================

# ===========================  HOMEBREW SETUP  ===========================

install_homebrew_if_missing() {
  ensure_global_variable_has_value "HOMEBREW_PATH" "HOMEBREW_INSTALL_URL"
  ensure_log_file_exists_and_writable
  log_info "Checking for Homebrew..."
  if [[ -x "${HOMEBREW_PATH}" ]]; then
    log_success "Homebrew already installed"
    log_debug "Found Homebrew at ${HOMEBREW_PATH}"
    return 0
  fi
  log_info "Homebrew not found at the expected location (${HOMEBREW_PATH})."
  log_warning "Attempting to install Homebrew. This requires administrator privileges (sudo password) and may take several minutes."
  if ! sudo -v; then
    log_error "Failed to obtain sudo privileges, which are required for Homebrew installation. Please run the script again and provide the password when prompted."
  fi
  log_info "Starting Homebrew installation process..."
  log_debug "Executing Homebrew install script from: ${HOMEBREW_INSTALL_URL}"
  (NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${HOMEBREW_INSTALL_URL}")" >>"${LOG_FILE}" 2>&1) &
  local installer_pid=$! # Get the PID of the background installer.

  # Show the spinning progress animation while it installs.
  progress_indicator "Installing Homebrew" "${installer_pid}" "critical"
  log_info "Verifying Homebrew installation..."
  if [[ ! -x "${HOMEBREW_PATH}" ]]; then
    log_error "Homebrew installation failed. The 'brew' executable was not found at '${HOMEBREW_PATH}' after installation attempt. Check the log file: ${LOG_FILE}"
  fi
  log_success "Homebrew successfully installed at '${HOMEBREW_PATH}'."
}

configure_homebrew_shell_environment() {
  ensure_global_variable_has_value "HOMEBREW_PATH"
  ensure_shell_profile_exists_and_writable
  log_info "Configuring shell environment for Homebrew..."
  if [[ ! -x "${HOMEBREW_PATH}" ]]; then
    log_error "Homebrew executable not found at '${HOMEBREW_PATH}'. Cannot configure shell environment. Run installation step first."
  fi
  local brew_shellenv_line="eval \"\$(${HOMEBREW_PATH} shellenv)\""
  log_debug "Homebrew shellenv line to add/check in profile: ${brew_shellenv_line}"
  if ! add_line_if_missing "${brew_shellenv_line}" "${SHELL_PROFILE_FILE}"; then
    log_error "Failed to add Homebrew shellenv configuration to '${SHELL_PROFILE_FILE}'. Check file permissions."
  fi
  log_debug "Activating Homebrew environment for the current script session using: eval \"\$(${HOMEBREW_PATH} shellenv)\""
  if ! eval "$("${HOMEBREW_PATH}" shellenv)"; then
    log_error "Failed to activate Homebrew environment in the current session using 'eval \$(${HOMEBREW_PATH} shellenv)'. The 'brew' command might not work correctly in this script run. Check permissions and Homebrew installation."
  fi
  if ! command_exists brew; then
    log_error "Homebrew shell environment was configured in profile, but 'brew' command is still not found in the current session's PATH. This indicates an unexpected issue. Check '${SHELL_PROFILE_FILE}' and potentially restart your terminal."
  fi
  log_debug "Verified 'brew' command is now available in PATH: $(command -v brew)"
  log_success "Homebrew environment configured and activated for this session."
}

update_and_configure_homebrew() {
  ensure_log_file_exists_and_writable
  log_info "Updating Homebrew and applying configurations..."
  if ! command_exists brew; then
    log_error "'brew' command not found. Cannot update Homebrew. Ensure previous setup steps succeeded."
  fi
  log_success "Homebrew is ready to brew"
  log_debug "Attempting to disable Homebrew analytics using 'brew analytics off'..."
  if brew analytics off >>"${LOG_FILE}" 2>&1; then
    log_debug "Successfully disabled Homebrew analytics."
  else
    log_debug "Could not disable Homebrew analytics (command failed). This is non-critical. Continuing..."
  fi
  log_info "Updating Homebrew package database (this may take a moment)..."
  log_debug "Running 'brew update'..."
  (brew update >>"${LOG_FILE}" 2>&1) &
  local update_pid=$! # Get the PID of the background update process.
  progress_indicator "Homebrew Update" "${update_pid}"
}

setup_homebrew_environment() {
  install_homebrew_if_missing          # Step 1: Install if needed.
  configure_homebrew_shell_environment # Step 2: Set up shell environment.
  update_and_configure_homebrew        # Step 3: Update and configure.
}

# ========================================================================

# ========================== TOOL INSTALLATION ===========================

install_homebrew_package_if_missing() {
  ensure_log_file_exists_and_writable
  local package_name="$1" # Get the tool name.
  if [[ -z "${package_name}" ]]; then
    log_error "Package name argument missing for install_homebrew_package_if_missing."
  fi
  log_info "Checking for package: ${package_name}"
  if ! command_exists brew; then
    log_error "'brew' command not found. Cannot install package '${package_name}'. Ensure Homebrew setup succeeded."
  fi
  log_debug "Checking if '${package_name}' is installed via 'brew list ${package_name}'..."
  if brew list "${package_name}" >/dev/null 2>&1; then
    log_success "Package '${package_name}' is already installed."
  else
    log_info "Installing $package_name..."
    log_debug "Running 'brew install ${package_name}'..."
    (brew install "${package_name}" >>"${LOG_FILE}" 2>&1) &
    local installer_pid=$!
    progress_indicator "Installing '${package_name}'" "${installer_pid}"
  fi
  return 0
}

verify_installed_tools() {
  ensure_global_variable_has_value "INSTALLED_TOOLS_TO_VERIFY"
  print_newline
  log_info "Verifying packages installation..."
  local missing_tools=()
  for tool_name in "${INSTALLED_TOOLS_TO_VERIFY[@]}"; do
    log_debug "Verifying command: ${tool_name}"
    if ! command_exists "${tool_name}"; then
      missing_tools+=("${tool_name}")
    else
      log_success "${tool_name} is available"
    fi
  done
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Critical tool(s) '${missing_tools[*]}' are missingor not found in PATH after installation attempt. Check Homebrew installation and PATH configuration. See log: ${LOG_FILE}"
  fi
}

install_required_packages() {
  ensure_global_variable_has_value "HOMEBREW_PACKAGES_TO_INSTALL"
  print_newline
  log_info "Installing required packages..."
  for package_name in "${HOMEBREW_PACKAGES_TO_INSTALL[@]}"; do
    if ! install_homebrew_package_if_missing "${package_name}"; then
      log_warning "Installation failed for package '${package_name}'. Check logs."
    fi
  done
}

# ========================================================================

# =========================== MISE & JAVA SETUP ==========================

configure_mise_environment() {
  ensure_global_variable_has_value "MISE_SHELL_TYPE"
  ensure_shell_profile_exists_and_writable
  ensure_log_file_exists_and_writable
  print_newline
  log_info "Configuring 'mise'..."

  # Find where the 'mise' command is located.
  if ! command_exists "mise"; then
    log_error "'mise' command not found. Cannot configure mise environment. Ensure mise setup was successful."
  fi
  local mise_executable
  mise_executable="$(command -v mise)"

  log_debug "mise executable found at: ${mise_executable}"

  local mise_activate_line="eval \"\$(${mise_executable} activate ${MISE_SHELL_TYPE})\""
  log_debug "mise activation line to add/check in profile: ${mise_activate_line}"

  # Add this line to the profile file if it's not there.
  if ! add_line_if_missing "${mise_activate_line}" "${SHELL_PROFILE_FILE}"; then
    log_error "Failed to add mise activation line to '${SHELL_PROFILE_FILE}'. Check file permissions."
  fi

  # Activate 'mise' for the current script session so we can use it to install Java.
  log_debug "Activating mise for the current script session using: \"${mise_executable}\" activate"
  # Run the activation command using 'eval'. Check if it succeeds.
  if "${mise_executable}" activate >/dev/null 2>>"${LOG_FILE}"; then
    log_success "mise environment configured and active for this session."
  else
    log_error "Failed to activate mise environment."
  fi
}

install_java_with_mise() {

  ensure_global_variable_has_value "JDK_MISE_NAME"
  ensure_log_file_exists_and_writable
  print_newline
  log_info "Installing Java (OpenJDK)..."

  if ! command_exists "mise"; then
    log_error "'mise' command not found or not activated. Cannot install Java. Ensure mise setup and activation were successful."
  fi
  local mise_executable
  mise_executable="$(command -v mise)"

  log_debug "Using mise executable: ${mise_executable}"

  # Ask 'mise' for the latest recommended version of OpenJDK.
  log_debug "Determining latest recommended Java version using 'mise latest ${JDK_MISE_NAME}'..."
  local latest_jdk_version=""
  # Run 'mise latest'. Send errors to log file ('2>>'). Check if command succeeded ('!').
  if ! latest_jdk_version=$("${mise_executable}" latest "${JDK_MISE_NAME}" 2>>"${LOG_FILE}"); then
    log_warning "Failed to determine the latest recommended Java version. See log: ${LOG_FILE}"
  fi
  # Check if 'mise latest' returned an actual version number.
  if [[ -z "${latest_jdk_version}" ]]; then
    latest_jdk_version="${JDK_MISE_BACKUP_VERSION}"
    log_warning "Using backup Java version: ${latest_jdk_version}"
  else
    log_info "Latest recommended Java version: ${latest_jdk_version}"
  fi

  # Combine the tool name and version (e.g., "java@openjdk@21.0.3").
  local jdk_tool_version="java@${latest_jdk_version}"
  log_debug "Full tool@version string for mise: ${jdk_tool_version}"

  # Tell 'mise' to install this Java version.
  log_debug "Running command: ${mise_executable} install ${jdk_tool_version}"
  # Run in background, send output to log, show progress.
  ("${mise_executable}" install "${jdk_tool_version}" >>"${LOG_FILE}" 2>&1) &
  local installer_pid=$!

  progress_indicator "Installing Java ${latest_jdk_version}" "${installer_pid}" "critical"

  log_info "Setting Java ${latest_jdk_version} as the global default version..."
  log_debug "Running command: ${mise_executable} use --global ${jdk_tool_version}"
  # Run 'mise use --global'. Send output to log. Check success.
  if "${mise_executable}" use --global "${jdk_tool_version}" >>"${LOG_FILE}" 2>&1; then
    log_success "Successfully set Java ${latest_jdk_version} as the global default."
  else
    log_error "Failed to set Java ${latest_jdk_version} as the global default. Check log: ${LOG_FILE}"
  fi

  # Check if Java works correctly now.
  log_info "Verifying Java installation..."
  # Run 'java -version' using 'mise exec' to ensure it uses the mise environment.
  log_debug "Running command: ${mise_executable} exec -- java -version"
  local java_version_output=""
  if java_version_output=$("${mise_executable}" exec -- java -version 2>&1 | head -n 1); then

    log_debug "Detected Java: ${java_version_output}"
    log_success "Java ${latest_jdk_version} is ready"
  else
    log_warning "Java verification failed. Check log: ${LOG_FILE}"
    echo "You can try verifying manually after restarting your terminal by running: java -version"
  fi
}

# ========================================================================

# ========================== riverSpider SETUP ===========================

ensure_secrets_initialized() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR" "SECRET_FILE_NAME" "TTPASM_APP_SCRIPT_DEFAULT_PASSWD"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_DIR}"
  local file_path="${RIVER_SPIDER_DIR}/${SECRET_FILE_NAME}"
  ensure_file_writable "${file_path}" "${SECRET_FILE_NAME}"
  local file_content=$(<"${file_path}")
  if [[ -z "${file_content}" ]]; then
    echo "${TTPASM_APP_SCRIPT_DEFAULT_PASSWD}" >"${file_path}"
    log_debug "Secret file '${file_path}' initialized with default password."
  fi
}

clean_up_riverspider_download() {
  ensure_global_variable_has_value "RIVER_SPIDER_EXTRACT_DIRECTORY" "RIVER_SPIDER_OUTPUT_FILE" "RIVER_SPIDER_TARGET_DIRECTORY" "RIVER_SPIDER_ZIP_NAME" "RIVER_SPIDER_DIR_NAME"
  local extracted_source_dir="${RIVER_SPIDER_EXTRACT_DIRECTORY}/${RIVER_SPIDER_DIR_NAME}"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_EXTRACT_DIRECTORY}" "${RIVER_SPIDER_EXTRACT_DIRECTORY}"
  log_info "Cleaning up ${RIVER_SPIDER_ZIP_NAME} and ${RIVER_SPIDER_EXTRACT_DIRECTORY}..."
  log_debug "Ensuring target directory exists: ${RIVER_SPIDER_TARGET_DIRECTORY}"
  mkdir -p "${RIVER_SPIDER_TARGET_DIRECTORY}"
  log_debug "Moving contents to ${RIVER_SPIDER_TARGET_DIRECTORY}..."
  cp -R "${extracted_source_dir}/"* "${RIVER_SPIDER_TARGET_DIRECTORY}" 2>/dev/null || log_warning "Failed to copy files from ${extracted_source_dir} to ${RIVER_SPIDER_TARGET_DIRECTORY}. Check permissions."
  log_debug "Moved contents to ${RIVER_SPIDER_TARGET_DIRECTORY}."
  log_debug "Removing ${RIVER_SPIDER_EXTRACT_DIRECTORY} and ${RIVER_SPIDER_OUTPUT_FILE}..."
  rm -rf "${RIVER_SPIDER_EXTRACT_DIRECTORY}" || log_warning "Failed to remove ${RIVER_SPIDER_EXTRACT_DIRECTORY}. Check permissions."
  rm -f "${RIVER_SPIDER_OUTPUT_FILE}" || log_warning "Failed to remove ${RIVER_SPIDER_OUTPUT_FILE}. Check permissions."
  log_debug "Extraction and cleanup complete. Files are in $RIVER_SPIDER_TARGET_DIRECTORY"
  find_river_spider_directory
}

download_and_extract_riverspider() {
  ensure_global_variable_has_value "RIVER_SPIDER_OUTPUT_FILE" "RIVER_SPIDER_ZIP_NAME" "RIVER_SPIDER_EXTRACT_DIRECTORY" "RIVER_SPIDER_TARGET_DIRECTORY" "RIVER_SPIDER_GOOGLE_DRIVE_FILE_ID"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_EXTRACT_DIRECTORY}"
  ensure_log_file_exists_and_writable
  log_info "Downloading '${RIVER_SPIDER_DIR_NAME}'..."
  local download_url="https://drive.usercontent.google.com/download?id=${RIVER_SPIDER_GOOGLE_DRIVE_FILE_ID}&export=download&confirm=t"
  log_debug "Google Drive download URL: ${download_url}"
  (curl -fsSL -o "$RIVER_SPIDER_OUTPUT_FILE" "${download_url}" >>"$LOG_FILE" 2>&1) &
  local download_pid=$!
  progress_indicator "Downloading '${RIVER_SPIDER_ZIP_NAME}'" "$download_pid" "critical"
  if [[ ! -s "${RIVER_SPIDER_OUTPUT_FILE}" ]]; then
    log_error "Download failed or resulted in an empty file: ${RIVER_SPIDER_OUTPUT_FILE}. Check URL and network connection. See log: ${LOG_FILE}"
  fi

  (unzip "$RIVER_SPIDER_OUTPUT_FILE" -d "$RIVER_SPIDER_EXTRACT_DIRECTORY" >>"$LOG_FILE" 2>&1) &
  local unzip_pid=$!
  progress_indicator "Unzipping '${RIVER_SPIDER_ZIP_NAME}'" "$download_pid" "critical"
  sleep 0.1
  local expected_subdir="${RIVER_SPIDER_EXTRACT_DIRECTORY}/${RIVER_SPIDER_DIR_NAME}"
  ensure_directory_exists "${expected_subdir}"
  clean_up_riverspider_download
}

set_river_spider_dir_variable() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_DIR}"
  ensure_shell_profile_exists_and_writable
  if [[ -z "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR variable is not set."
  fi
  if [[ ! -d "$RIVER_SPIDER_DIR" ]]; then
    log_error "RIVER_SPIDER_DIR path '$RIVER_SPIDER_DIR' is not a valid directory."
  fi
  export RIVER_SPIDER_DIR
  log_debug "Exported RIVER_SPIDER_DIR='${RIVER_SPIDER_DIR}' for the current script session."
  local line_to_set="export RIVER_SPIDER_DIR=\"${RIVER_SPIDER_DIR}\""
  local pattern_to_find="^export RIVER_SPIDER_DIR="
  log_debug "Ensuring shell profile '${SHELL_PROFILE_FILE}' contains line: ${line_to_set}"

  # Check if a line matching the pattern already exists in the profile file.
  # 'grep -q' searches quietly.
  if grep -q "${pattern_to_find}" "${SHELL_PROFILE_FILE}"; then
    # If it exists, replace the old line with the new one using 'sed'.
    # 'sed -i''' modifies the file directly (the '' is needed for macOS compatibility).
    # '-e' specifies the command to run.
    # 's#pattern#replacement#' substitutes the pattern with the replacement.
    # '#' is used as the separator instead of '/' because the path contains '/'.
    # '.*' matches the rest of the existing line.
    # If sed fails ('||'), show a warning.
    sed -i'' -e "s#${pattern_to_find}.*#${line_to_set}#" "${SHELL_PROFILE_FILE}" ||
      log_warning "Could not add RIVER_SPIDER_DIR to ${SHELL_PROFILE_FILE}. Add manually: ${line_to_set}"
    log_debug "Updated existing line in ${SHELL_PROFILE_FILE} to: ${line_to_set}"
  else
    # If the line doesn't exist, add it to the end of the file.
    # '{ echo ""; ...; echo ""; } >> file' appends the lines inside {} to the file.
    # Adds blank lines before and after for spacing.
    # If appending fails ('||'), show a warning.
    add_line_if_missing "${line_to_set}" "${SHELL_PROFILE_FILE}" ||
      log_warning "Could not add RIVER_SPIDER_DIR to ${SHELL_PROFILE_FILE}."
    log_debug "Added new line to ${SHELL_PROFILE_FILE}: ${line_to_set}"
  fi
}

# Tries to find the 'riverSpider' directory, which should contain 'submit.sh'.
find_river_spider_directory() {
  ensure_global_variable_has_value "SUBMIT_SCRIPT_NAME" "RIVER_SPIDER_EXTRACT_DIRECTORY" "RIVER_SPIDER_DIR_NAME" "FIND_ATTEMPT_COUNT" "MAX_FIND_ATTEMPTS"
  ((FIND_ATTEMPT_COUNT++))
  log_debug "Find riverSpider directory attempt: ${FIND_ATTEMPT_COUNT}/${MAX_FIND_ATTEMPTS}"

  if [[ "${FIND_ATTEMPT_COUNT}" -gt "${MAX_FIND_ATTEMPTS}" ]]; then
    log_error "Exceeded maximum attempts (${MAX_FIND_ATTEMPTS}) to find 'riverSpider' directory. Could not locate or download."
  fi
  if ! command_exists fd; then
    log_error "'fd' command not found. Cannot search for '${RIVER_SPIDER_DIR_NAME}' directory. Ensure 'fd' is installed."
  fi
  local temp_file
  local search_pid
  temp_file=$(mktemp) || log_error "Failed to create temporary file for search results."
  ensure_file_writable "${temp_file}" "Search results temp file"
  log_info "Attempting to locate the ${RIVER_SPIDER_DIR_NAME} directory..."
  log_debug "Searching within '${HOME}' for a directory named '${RIVER_SPIDER_DIR_NAME}' containing '${SUBMIT_SCRIPT_NAME}'..."
  (fd --type f "${SUBMIT_SCRIPT_NAME}" "${HOME}" --exec dirname {} \; | grep --color=never "/${RIVER_SPIDER_DIR_NAME}$" | head -n 1 >"${temp_file}") &
  search_pid=$!
  progress_indicator "Searching for '${RIVER_SPIDER_DIR_NAME}' directory" "$search_pid"
  local potential_dir
  potential_dir=$(<"${temp_file}")
  # Check if a directory path was found ('-n' checks if string is not empty)
  # AND if that path actually points to a directory ('-d' checks if it's a directory).
  if ! [[ -n "${potential_dir}" && -d "${potential_dir}" ]]; then
    log_debug "No valid directory found. Attempting to download and extract '${RIVER_SPIDER_DIR_NAME}'..."
    download_and_extract_riverspider
  elif [[ "$potential_dir" == "${RIVER_SPIDER_EXTRACT_DIRECTORY}/${RIVER_SPIDER_DIR_NAME}" ]]; then
    ensure_directory_exists_and_writable "${RIVER_SPIDER_EXTRACT_DIRECTORY}/${RIVER_SPIDER_DIR_NAME}"
    log_debug "Found '${RIVER_SPIDER_DIR_NAME}' - in the temporary extraction directory."
    clean_up_riverspider_download
  else
    ensure_directory_exists_and_writable "${potential_dir}"
    log_success "Found '${RIVER_SPIDER_DIR_NAME}' at ${potential_dir}"
    RIVER_SPIDER_DIR="${potential_dir}"
  fi
  ensure_secrets_initialized
}

update_path_in_submit_script() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR" "SUBMIT_SCRIPT_NAME"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_DIR}"
  local submit_script_path="${RIVER_SPIDER_DIR}/${SUBMIT_SCRIPT_NAME}"
  ensure_file_writable "${submit_script_path}" "${SUBMIT_SCRIPT_NAME}"
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
  if ! sed -i '' -e "s#${old_line_pattern}#${new_line_content}#" "${submit_script_path}"; then
    log_warning " - Couldn't update path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
    return 1
  fi
  if ! grep -Fxq -- "${new_line_content}" "${submit_script_path}"; then
    log_warning " - Couldn't update path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
    return 1
  fi
  log_success " - Updated path for '${path_description}' in ${SUBMIT_SCRIPT_NAME}."
}

# Changes relative paths (like 'secretString.txt') inside the submit.sh script
# to absolute paths (like '/Users/you/riverSpider/secretString.txt').
update_paths_in_riverspider_submit_script() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR" "SUBMIT_SCRIPT_NAME" "OLD_SECRETS_PATH_LINE" "OLD_WEBAPP_URL_PATH_LINE" "OLD_LOGISIM_JAR_PATH_LINE" "OLD_PROCESSOR_CIRC_PATH_LINE" "OLD_URLENCODE_SED_PATH_LINE"
  ensure_directory_exists_and_writable "${RIVER_SPIDER_DIR}"
  local submit_script_path="${RIVER_SPIDER_DIR}/${SUBMIT_SCRIPT_NAME}"
  ensure_file_writable "${submit_script_path}" "${SUBMIT_SCRIPT_NAME}"
  print_newline
  log_info "Updating paths in the ${RIVER_SPIDER_DIR_NAME} submit script..."
  local new_secrets_path_line="secretPath=\"${RIVER_SPIDER_DIR}/${SECRET_FILE_NAME}\""
  local new_webapp_url_path_line="webappUrlPath=\"${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}\""
  local new_logisim_jar_path_line="logisimPath=\"${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}\""
  local new_processor_circ_path_line="processorCircPath=\"${RIVER_SPIDER_DIR}/${PROCESSOR_CIRC_FILE_NAME}\""
  local new_urlencode_sed_path_line="urlencodeSedPath=\"${RIVER_SPIDER_DIR}/${URLENCODE_SED_FILE_NAME}\""

  update_path_in_submit_script "${OLD_SECRETS_PATH_LINE}" "${new_secrets_path_line}" "Secret File"
  update_path_in_submit_script "${OLD_WEBAPP_URL_PATH_LINE}" "${new_webapp_url_path_line}" "WebApp URL File"
  update_path_in_submit_script "${OLD_LOGISIM_JAR_PATH_LINE}" "${new_logisim_jar_path_line}" "Logisim"
  update_path_in_submit_script "${OLD_PROCESSOR_CIRC_PATH_LINE}" "${new_processor_circ_path_line}" "Processor Circuit"
  update_path_in_submit_script "${OLD_URLENCODE_SED_PATH_LINE}" "${new_urlencode_sed_path_line}" "URLEncode Sed Script"

}

# Adds a new, easy-to-use command 'riverspider' to your shell profile file.
# This command makes running the main submit.sh script simpler.
add_river_spider_shell_helper_function() {
  ensure_global_variable_has_value "ZSH_PROFILE_BASENAME" "BASH_PROFILE_BASENAME" "RIVER_SPIDER_DIR_NAME"
  ensure_directory_exists "${RIVER_SPIDER_DIR}"
  ensure_shell_profile_exists_and_writable
  print_newline
  log_info "Setting up River Spider helper function..."
  local helper_function_name="riverspider"

  if grep -q "^${helper_function_name}()" "${SHELL_PROFILE_FILE}"; then
    log_success "'${helper_function_name}' helper function already exists in ${SHELL_PROFILE_FILE}"
  else
    log_info "Adding River Spider helper function to ${SHELL_PROFILE_FILE}..."
    cat <<-EOF >>"${SHELL_PROFILE_FILE}"
#=======  START River Spider helper function =======
riverspider() {
  local ttpasm_file=\$1
  if [[ -z "\${ttpasm_file}" || "\$1" == "-h" || "\$1" == "--help" ]]; then
    echo "Usage: riverspider <filename>.ttpasm"
    return 1
  fi
  if [[ "\${ttpasm_file##*.}" != "ttpasm" ]]; then
    echo "Error: File must have .ttpasm extension."
    return 1
  fi
  if [[ ! -f "\${ttpasm_file}" ]]; then
    echo "Error: File '\${ttpasm_file}' not found."
    return 1
  fi
  locate_riverspider_dir || return 1
  "\${RIVER_SPIDER_DIR}/${SUBMIT_SCRIPT_NAME}" "\$(realpath "\${ttpasm_file}")"
}
locate_riverspider_dir() {
  if [[ -z "\${RIVER_SPIDER_DIR:-}" || ! -d "\${RIVER_SPIDER_DIR}" ]]; then
    RIVER_SPIDER_DIR=\$(fd --type f submit.sh "\$HOME" --exec dirname {} \; | grep "/${RIVER_SPIDER_DIR_NAME}$" | head -n 1)
    if [[ -z "\${RIVER_SPIDER_DIR}" || ! -d "\${RIVER_SPIDER_DIR}" ]]; then
      echo "Error: Could not locate the ${RIVER_SPIDER_DIR_NAME} directory."
      echo "See Canvas for download instructions."
      return 1
    fi
    export RIVER_SPIDER_DIR
    add_riverspider_to_profile "export RIVER_SPIDER_DIR=\"\${RIVER_SPIDER_DIR}\""
  fi
}
add_riverspider_to_profile() {
  local line_to_set="\$1"
  local pattern_to_find="^export RIVER_SPIDER_DIR="
  local current_shell="\$(basename "\${SHELL:-}")"
  local shell_profile=""
  case "\${current_shell}" in
    zsh) shell_profile="\${ZDOTDIR:-\$HOME}/${ZSH_PROFILE_BASENAME}" ;;
    bash) shell_profile="\$HOME/${BASH_PROFILE_BASENAME}" ;;
  esac
  if [[ -z "\${shell_profile}" || ! -f "\${shell_profile}" ]]; then
    echo "Could not add RIVER_SPIDER_DIR to shell profile."
    echo "Add manually: \${line_to_set}"
    return 0
  fi
  if grep -q "\${pattern_to_find}" "\${shell_profile}"; then
    sed -i'' -e "s#\${pattern_to_find}.*#\${line_to_set}#" "\${shell_profile}" ||
      echo "Could not add RIVER_SPIDER_DIR to \${shell_profile}. Add manually: \${line_to_set}"
  else
    { echo ""; echo "\${line_to_set}"; echo "";} >> "\${shell_profile}" ||
      echo "Could not add RIVER_SPIDER_DIR to \${shell_profile}. Add manually: \${line_to_set}"
  fi
}
#=======  END River Spider helper function =======

#=======  START Logisim helper function =======

logisim() {
  if [[ "\$#" -eq 0 ]]; then
    java -jar "\${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}"
    return \$?
  fi

  local arg1="\$1"

  if [[ "\${arg1}" == "-h" || "\${arg1}" == "--help" ]]; then
    echo "Usage: logisim [<filename.circ>]"
    echo "       logisim -h | --help     Show this help message"
    echo ""
    return 1
  fi

  if [[ "\${arg1##*.}" != "circ" ]]; then
    echo "Error: File '\$arg1' must have a .circ extension." >&2
    return 1
  fi

  if [[ ! -f "\${arg1}" ]]; then
    echo "Error: File '\${arg1}' not found." >&2
    return 1
  fi

  java -jar "\${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}" "\${arg1}"
  
  return \$? 
}

logproc(){
  java -jar "\${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}" "\${RIVER_SPIDER_DIR}/${PROCESSOR_CIRC_FILE_NAME}"
}

logalu(){
  java -jar "\${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}" "\${RIVER_SPIDER_DIR}/${ALU_CIRC_FILE_NAME}"
}

logreg(){
  java -jar "\${RIVER_SPIDER_DIR}/${LOGISIM_JAR_FILE_NAME}" "\${RIVER_SPIDER_DIR}/${REGBANK_FILE_CIRC_FILE_NAME}"
}

#=======  END Logisim helper function =======
EOF

    if [[ $? -ne 0 ]]; then
      log_warning "Failed to add '${helper_function_name}' helper function to ${SHELL_PROFILE_FILE}."
    else
      if grep -q "${helper_function_name}()" "${SHELL_PROFILE_FILE}"; then
        log_success "Added '${helper_function_name}' helper function to shell profile"
        log_debug "Confirmed '${helper_function_name}' helper function exists in ${SHELL_PROFILE_FILE}."
      else
        log_warning "Failed to add '${helper_function_name}' helper function to ${SHELL_PROFILE_FILE}."
      fi
    fi
  fi
}

# ========================================================================

display_startup_message() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR_NAME" "START_TIMESTAMP" "QUIET"
  ensure_log_file_exists_and_writable
  echo "───────────────────────────────────────────────" >"${LOG_FILE}"
  echo " ${RIVER_SPIDER_DIR_NAME} macOS Setup Log" >>"${LOG_FILE}"
  echo " Started at: ${START_TIMESTAMP}" >>"${LOG_FILE}"
  echo "───────────────────────────────────────────────" >>"${LOG_FILE}"
  if [[ "${QUIET}" == "false" ]]; then
    echo "================================================="
    log_info "Starting ${RIVER_SPIDER_DIR_NAME} macOS Setup Script"
    log_info "Setup started at: ${START_TIMESTAMP}"
    log_info "Log file:         ${LOG_FILE}"
    echo "================================================="
    print_newline
    print_newline
  fi
}

display_completion_message() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR_NAME" "RIVER_SPIDER_DIR" "WEBAPP_URL_FILE_NAME" "SHELL_PROFILE_FILE" "TTY_BOLD" "TTY_RESET" "TTY_YELLOW" "TTY_GREEN" "QUIET"
  ensure_directory_exists "${RIVER_SPIDER_DIR}"
  ensure_log_file_exists_and_writable
  local end_timestamp
  end_timestamp="$(date +%Y-%m-%d_%H:%M:%S)"
  if [[ "${QUIET}" == "true" ]]; then
    echo "================================================="
    echo "Setup completed successfully at: ${end_timestamp}"
    echo "Log file:         ${LOG_FILE}"
    echo "================================================="
  else
    printf "\n"
    log_info "================================================="
    log_info "${TTY_GREEN}         ${RIVER_SPIDER_DIR_NAME} Setup Complete${TTY_RESET}"
    log_info "================================================="
    printf "\n"
    log_info "${TTY_BOLD}---All automated setup steps finished.---${TTY_RESET}"
    log_info "Please review the output above for any ${TTY_YELLOW}Warning:${TTY_RESET} messages."
    printf "\n"
    log_info "${TTY_BOLD}--- IMPORTANT NEXT STEPS ---${TTY_RESET}"
    log_info "1. ${TTY_YELLOW}Restart your Terminal:${TTY_RESET}"
    log_info "   Close all terminal windows and open a new one to apply the changes"
    log_info "   made to your shell profile (${TTY_BOLD}${SHELL_PROFILE_FILE##*/}${TTY_RESET})."
    log_info "   (Alternatively, for your ${TTY_BOLD}current terminal window only)${TTY_RESET}, you could run:"
    log_info "      ${TTY_GREEN}source \"${SHELL_PROFILE_FILE}\"${TTY_RESET} )"
    printf "\n"
    log_info "2. ${TTY_YELLOW}Verify Google App Script Setup:${TTY_RESET}"
    log_info "   Ensure you have completed the Google App Script setup instructions"
    log_info "   (shown below if you chose 'Yes') and that the Web App URL"
    log_info "   was saved to:"
    log_info "      ${TTY_GREEN}${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}${TTY_RESET}"
    printf "\n"
    log_info "${TTY_BOLD}--- Usage ---${TTY_RESET}"
    log_info "After restarting your terminal and completing the Google App Script setup,"
    log_info "you can use the new commands from any directory:"
    log_info "   - Submit a file:                  ${TTY_GREEN}riverspider${TTY_RESET} ${TTY_YELLOW}<your_file.ttpasm>${TTY_RESET}"
    log_info "   - Open Logisim:                   ${TTY_GREEN}logisim${TTY_RESET}"
    log_info "   - Open a file in Logisim:         ${TTY_GREEN}logisim${TTY_RESET} [${TTY_YELLOW}<your_file.circ>${TTY_RESET}]"
    log_info "   - Open Processor in Logisim:      ${TTY_GREEN}logproc${TTY_RESET}"
    log_info "   - Open ALU in Logisim:            ${TTY_GREEN}logalu${TTY_RESET}"
    log_info "   - Open Register Bank in Logisim:  ${TTY_GREEN}logreg${TTY_RESET}"
    printf "\n"
    printf "\n"
    log_info "───────────────────────────────────────────────"
    log_info "   Details about everything the script did were saved to:"
    log_info "      ${TTY_GREEN}${LOG_FILE}${TTY_RESET}"
    log_info "───────────────────────────────────────────────"
    log_info "Script finished execution successfully at ${end_timestamp}"
    log_info "================================================="
  fi
}

# This part of the setup cannot be automated by the script.
display_google_apps_script_setup_instructions() {
  ensure_global_variable_has_value "GOOGLE_SHEETS_DOC_NAME" "GOOGLE_SHEETS_DOC_URL" "QUIET" "TTY_BOLD" "TTY_RESET" "TTY_YELLOW" "TTY_GREEN"
  if [[ "${QUIET}" == "false" ]]; then
    open "${GOOGLE_SHEETS_DOC_URL}" 2>/dev/null || log_warning "Failed to open Google Sheets document URL in browser."
    log_info "${TTY_BOLD}--- Manual Google App Script Setup Instructions ---${TTY_RESET}"
    echo ""
    echo "${TTY_YELLOW}Step 1: Make a Copy of the Google Sheet${TTY_RESET}"
    echo "  1. Go to the following URL (opens automatically):"
    echo "     ${TTY_GREEN}${GOOGLE_SHEETS_DOC_URL}${TTY_RESET}"
    echo "     (If it doesn't open, copy and paste it into your browser)."
    echo "     Make sure you are signed in with your ${TTY_BOLD}Los Rios account${TTY_RESET}."
    echo "  2. In Google Sheets, go to the menu:"
    echo "     ${TTY_BOLD}File > Make a copy${TTY_RESET}"
    echo "  3. Name your copy (e.g., 'My Copy of assemblerStudent')."
    echo "  4. Ensure 'Folder' is set to '${TTY_BOLD}My Drive${TTY_RESET}'."
    echo "  5. Click the '${TTY_GREEN}Make a copy${TTY_RESET}' button."
    echo ""
    echo "${TTY_YELLOW}Step 2: Deploy the Apps Script from YOUR Copy${TTY_RESET}"
    echo "  1. In ${TTY_BOLD}your copy${TTY_RESET} of the spreadsheet, go to the menu:"
    echo "     ${TTY_BOLD}Extensions > Apps Script${TTY_RESET}"
    echo "     (This will open the script editor in a new tab)."
    echo "  2. In the script editor, click the '${TTY_BLUE}Deploy${TTY_RESET}' button (top right) and select:"
    echo "     '${TTY_BOLD}New deployment${TTY_RESET}'"
    echo "  3. Configure the deployment settings:"
    echo "     - Description:  '${TTY_BOLD}River Spider Script${TTY_RESET}'"
    echo "     - Execute as:   '${TTY_BOLD}Me (${TTY_GREEN}<your_email@example.com>${TTY_RESET})${TTY_BOLD}'${TTY_RESET}"
    echo "     - Who has access: '${TTY_BOLD}Anyone${TTY_RESET}'"
    echo "       ${TTY_YELLOW}(Important: Choose 'Anyone', NOT 'Anyone with Google account'. This allows the script to submit data.)${TTY_RESET}"
    echo "  4. Click the '${TTY_BLUE}Deploy${TTY_RESET}' button."
    echo ""
    echo "${TTY_YELLOW}Step 3: Authorize the Script${TTY_RESET}"
    echo "  1. Google will ask for authorization."
    echo "  2. Click '${TTY_BLUE}Authorize access${TTY_RESET}'."
    echo "  3. Choose your ${TTY_BOLD}Los Rios account${TTY_RESET}."
    echo "  4. You might see a '${TTY_RED}Google hasn't verified this app${TTY_RESET}' warning."
    echo "     Click '${TTY_BOLD}Advanced${TTY_RESET}' (bottom left)."
    echo "     Click '${TTY_BOLD}Go to <Your Script Name> (unsafe)${TTY_RESET}'."
    echo "  5. Review the permissions and click '${TTY_BLUE}Allow${TTY_RESET}'."
    echo ""
    echo "${TTY_YELLOW}Step 4: Copy the Web App URL${TTY_RESET}"
    echo "  1. After successful deployment and authorization, you will see a '${TTY_GREEN}Deployment updated${TTY_RESET}' dialog."
    echo "  2. ${TTY_BOLD}Copy the URL${TTY_RESET} provided under '${TTY_BOLD}Web app${TTY_RESET}'. It looks like:"
    echo "     ${TTY_GREEN}https://script.google.com/macros/s/..../exec${TTY_RESET}"
    echo "  3. ${TTY_BOLD}Paste this URL${TTY_RESET} when the setup script prompts for it below."
    echo "      (Alternatively, you can manually paste it into: ${RIVER_SPIDER_DIR}/${TTY_BOLD}${WEBAPP_URL_FILE_NAME}${TTY_RESET})"
    echo ""
  fi
}

setup_google_webapp_url() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR" "WEBAPP_URL_FILE_NAME" "TTY_BOLD" "TTY_RESET" "TTY_GREEN" "QUIET"
  ensure_directory_exists "${RIVER_SPIDER_DIR}"
  if [[ "${QUIET}" == "false" ]]; then
    local webapp_file_path="${RIVER_SPIDER_DIR}/${WEBAPP_URL_FILE_NAME}"
    ensure_file_writable "${webapp_file_path}" "Web App url"
    local answer=""
    local web_app_url=""
    local prompt_instructions="❓ Would you like to view Google Apps Script setup instructions? [Y/n]: "
    local prompt_paste_url="📥 Paste the ${TTY_BOLD}Web App URL${TTY_RESET} copied from the Google Apps Script deployment (or 'q' to quit setup): "
    local url_pattern='^https://script\.google\.com/macros/s/.+/exec$'
    if [[ -s "${webapp_file_path}" ]]; then
      log_debug "File ${webapp_file_path} exists. Checking for a valid URL."
      local existing_url
      existing_url=$(<"${webapp_file_path}")
      if [[ "${existing_url}" =~ ${url_pattern} ]]; then
        log_success "Valid Web App URL already found in ${webapp_file_path}"
        read -rp "❓ A valid URL exists. Overwrite it? [y/N]: " overwrite_answer
        log_debug "User input (overwrite): ${overwrite_answer}"
        case "${overwrite_answer}" in
        [Yy]*) log_info "Proceeding to overwrite existing URL." ;;
        *)
          log_info "Keeping existing URL. Skipping Google App Script setup prompt."
          return 0
          ;;
        esac
      else
        log_warning "File ${webapp_file_path} exists but contains an invalid URL. Proceeding to get a new one."
      fi
    fi
    while true; do
      printf "\n"
      read -rp "${prompt_instructions}" answer
      answer_lower=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
      log_debug "User input (instructions): ${answer_lower}"
      case "${answer_lower}" in
      "" | "y" | "yes")
        display_google_apps_script_setup_instructions

        while true; do
          read -rp "${prompt_paste_url}" web_app_url
          local url_lower
          url_lower=$(echo "$web_app_url" | tr '[:upper:]' '[:lower:]')
          if [[ "${url_lower}" == "q" ]]; then
            echo ""
            echo "❌ URL entry cancelled by user. Setup aborted."
            echo ""
            exit 1
          fi

          # Strip surrounding quotes if present
          web_app_url="${web_app_url%\"}" # Remove trailing quote
          web_app_url="${web_app_url#\"}" # Remove leading quote
          web_app_url="${web_app_url%\'}" # Remove trailing single quote
          web_app_url="${web_app_url#\'}" # Remove leading single quote
          log_debug "User input URL: ${web_app_url}"
          if [[ "${web_app_url}" =~ ${url_pattern} ]]; then
            echo "${web_app_url}" >"${RIVER_SPIDER_DIR}"
            echo ""
            echo "📝 Web App URL saved to: ${webapp_file_path}"
            echo ""
            break
          else
            log_warning "⛓️‍💥 Invalid URL."
            echo "   The URL must start with ${TTY_GREEN}https://script.google.com/macros/s/${TTY_RESET}"
            echo "   and end with ${TTY_GREEN}/exec${TTY_RESET}."
            echo "   Example: ${TTY_GREEN}https://script.google.com/macros/s/AKfycb.../exec${TTY_RESET}"
            echo "   Please paste the correct URL copied from the deployment dialog, or type 'q' to quit."
            echo ""
          fi
        done
        break
        ;;
      "n" | "no")
        echo ""
        echo "⏭️  Setup instructions skipped."
        echo ""
        break
        ;;
      *)
        echo ""
        log_warning "⁉️  Please answer [Y]es or [N]o."
        ;;
      esac
    done
  fi
}

main() {
  ensure_global_variable_has_value "RIVER_SPIDER_DIR_NAME"

  for arg in "$@"; do
    case "${arg}" in
    -h | --help)
      print_help
      return 0
      ;;
    -d | --debug)
      DEBUG="true"
      QUIET="false"
      break
      ;;
    -q | --quiet)
      QUIET="true"
      DEBUG="false"
      break
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      return 1
      ;;
    esac
  done
  # Set up the colors for messages.
  setup_terminal_colors
  # Create/clear the log file and show starting messages on screen.
  display_startup_message

  log_info "=== PHASE 1: System Validation ==="
  print_separator
  check_required_system_commands          # Are basic tools present?
  check_operating_system_and_architecture # Is it macOS? Intel/Apple Silicon?
  check_internet_connectivity             # Can it reach the internet?
  determine_shell_and_profile             # Which shell? Where's the profile file?
  print_separator
  log_success "System validation complete."
  print_newline
  print_newline
  log_info "=== PHASE 2: Dependency Installation ==="
  print_separator
  setup_homebrew_environment # Install/configure/update Homebrew.
  install_required_packages  # Install mise, fd, etc.
  verify_installed_tools     # Check installed tools are working.
  configure_mise_environment # Set up mise in the shell.
  install_java_with_mise     # Install OpenJDK using mise.
  print_separator
  log_success "Dependency installation complete."
  print_newline
  print_newline
  log_info "=== PHASE 3: '${RIVER_SPIDER_DIR_NAME}' Setup ==="
  print_separator
  find_river_spider_directory               # Find or download the riverSpider folder.
  set_river_spider_dir_variable             # Always remember where the riverSpider folder is.
  update_paths_in_riverspider_submit_script # Fix paths inside submit.sh (so it can be called from anywhere)
  add_river_spider_shell_helper_function    # Add the 'riverspider' command.
  print_separator
  log_success "'${RIVER_SPIDER_DIR_NAME}' configuration complete."
  print_newline

  # Show the final "all done" message.
  display_completion_message
  print_newline
  print_newline
  log_info "=== PHASE 4: Google App Script Setup ==="
  print_separator
  # Show Google Sheets steps, and/or add Web App URL to webapp.url file
  setup_google_webapp_url
  print_separator
  print_newline
  return 0
}

main "$@"
exit $?
