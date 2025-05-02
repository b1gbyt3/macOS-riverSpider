#!/bin/bash
# Tells the computer: "Use 'bash' to run the commands below."

# --- Safety Rules ---
# -e: Stop right away if any command fails (has an error).
# -u: Stop if the script tries to use a name (variable) that hasn't been given a value.
# -o pipefail: If commands are chained with '|' (like command A | command B),
#              stop if any command in the chain fails.
set -euo pipefail

# --- Set Window Title ---
# Changes the title shown at the top of the terminal window.
echo -ne "\033]0;riverSpider macOS Setup Script\007"

# ===================================================================
# --- Shell Settings Files ---
# These are names for files that store settings for the shell.
# You might need to change these if you use different filenames like '.zshrc' or '.bashrc'.

# ZSH_CONF_FILE: Name of the settings file for the Zsh shell.
ZSH_CONF_FILE=".zprofile"
# BASH_CONF_FILE: Name of the settings file for Bash shell.
BASH_CONF_FILE=".bash_profile"
# ===================================================================

# =========================== GENERAL CONFIG =========================

# --- Log File ---
LOG_FILE="/tmp/riverspider_setup_$(date +%Y%m%d_%H%M%S).log"

# --- Homebrew Locations ---
ARM_BREW_PATH="/opt/homebrew/bin/brew"
INTEL_BREW_PATH="/usr/local/bin/brew"

# --- Software Names ---
JDK="java@openjdk" 
REQUIRED_COMMANDS=("curl" "git" "sed" "tr" "find")
PACKAGES_TO_INSTALL=("coreutils" "wget" "mise" "fd")
TOOLS_TO_VERIFY=("timeout" "wget" "mise" "fd")

# --- Google Drive Info ---
GOOGLE_DRIVE_URL="https://drive.google.com/drive/folders/0BxsMACqxAFNwR1pCb2pPeE5Wb1E?resourcekey=0-fb_u058vHLwLSyiSaBKPoQ"
GOOGLE_SHEETS_NAME="'Copy of assemblerStudent'"

# =========================== SUBMIT.SH PATHS =========================
# submit.sh by default uses a relative path; we will change it to an absolute path.
# IF YOU MAKE ANY CHANGES HERE, MAKE SURE TO UPDATE "NEW_" in update_riverspider_paths()

OLD_SECRETS_LINE='secretPath=secretString.txt'
OLD_WEBAPP_LINE='webappUrlPath=webapp.url'
OLD_LOGISIM_LINE='logisimPath=logisim310.jar'
OLD_PROC_LINE='processorCircPath=processor0004.circ'
OLD_URLENCODE_LINE='urlencodeSedPath=urlencode.sed'

# ===================================================================
# Makes text in the terminal colorful and bold.
setup_terminal_colors() {
  # Check if the script is running in a terminal that shows colors.
  if [[ -t 1 ]]; then
    # Function to create color codes.
    tty_escape() { printf "\033[%sm" "$1"; }
  else
    # If not a color terminal, this function does nothing.
    tty_escape() { :; }
  fi

  # Function to make text bold and colored.
  tty_mkbold() { tty_escape "1;$1"; }

  tty_blue=$(tty_mkbold 34)    # Blue color
  tty_red=$(tty_mkbold 31)     # Red color
  tty_yellow=$(tty_mkbold 33)  # Yellow color
  tty_green=$(tty_mkbold 32)   # Green color
  tty_bold=$(tty_mkbold 39)    # Bold text
  tty_reset=$(tty_escape 0)    # Reset text to normal
}

log_info() {
  local msg="$*"
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$msg"
  echo "[INFO] $msg" >> "$LOG_FILE"
}

log_success() {
  local msg="$*"
  printf "${tty_green}✓${tty_reset} %s\n" "$msg"
  echo "[SUCCESS] $msg" >> "$LOG_FILE"
}

log_warning() {
  local msg="$*"
  printf "${tty_yellow}Warning${tty_reset}: %s\n" "$msg" >&2
  echo "[WARNING] $msg" >> "$LOG_FILE"
}

# Shows error messages and stops the script.
log_error() {
  local msg="$*"
  printf "${tty_red}Error${tty_reset}: %s\n" "$msg" >&2
  echo "[ERROR] $msg" >> "$LOG_FILE"
  echo "[ERROR] Script aborted at $(date)" >> "$LOG_FILE"
  echo "[ERROR] Script aborted at $(date) check logfile $LOG_FILE"
  exit 1
}

# Writes extra details (debug info) only to the log file.
log_debug() {
  echo "[DEBUG] $*" >> "$LOG_FILE"
}

command_exists() {
  # Check if the command exists.
  command -v "$1" >/dev/null 2>&1
}

add_line_if_missing() {
  local line="$1"   # The text line to add.
  local file="$2"   # The file to add the line to.

  # Check if the file exists; create it if it doesn't.
  [[ -f "$file" ]] || touch "$file" || log_error "Cannot create $file"

  # Add the line if it's not already in the file.
  if ! grep -qF -- "$line" "$file"; then
    log_debug "Adding line to $file: $line"
    echo "" >> "$file"
    echo "$line" >> "$file"
    echo "" >> "$file"
    return 0
  fi

  log_debug "$line - already exists in $file"
  return 0
}

# Checks if the script is running on a macOS computer.
check_macos() {
  # Get the computer's chip type (like 'arm64' or 'x86_64').
  # '$(...)' runs the command inside and captures its output.
  UNAME_MACHINE="$(/usr/bin/uname -m)"
  # Check if the chip type is NOT 'arm64' AND NOT 'x86_64'.
  if [[ "${UNAME_MACHINE}" != "arm64" ]] && [[ "${UNAME_MACHINE}" != "x86_64" ]]; then
    log_error "This script is only for macOS. Detected: $(uname)"
  fi
  # Set the correct Homebrew path based on the chip type.
  if [[ "${UNAME_MACHINE}" == "arm64" ]]; then
    HOMEBREW_PATH="$ARM_BREW_PATH"  # Use ARM path
    CHIP_TYPE="Apple Silicon"
  else
    HOMEBREW_PATH="$INTEL_BREW_PATH"  # Use Intel path
    CHIP_TYPE="Intel Processor"
  fi
  # 'sw_vers -productVersion' gets the macOS version number.
  log_success "macOS: version $(sw_vers -productVersion) ($CHIP_TYPE)"
}

# Checks if the computer is connected to the internet.
check_internet() {
  log_info "Checking internet connectivity"
  # List of websites to try reaching.
  local domains=("www.google.com" "www.apple.com" "github.com")
  # Loop through each website in the list.
  for domain in "${domains[@]}"; do
    # Try to 'ping' (send a small test message) to the website.
    # '-c 1' sends 1 ping. '-W 3' waits 3 seconds for reply. '&>/dev/null' hides output.
    if ping -c 1 -W 3 "$domain" &>/dev/null; then
      log_success "Internet connection OK"
      return 0  # Found connection, stop checking.
    fi
  done
  # If none of the websites could be reached.
  log_error "No internet connection detected. Please check your network."
}

# Finds out which command shell (like bash or zsh) is being used and finds its settings file.
detect_shell() {
  log_info "Detecting shell configuration"

  # Find the name of the current shell (like 'bash' or 'zsh').
  # '${SHELL:-/bin/bash}' uses the SHELL variable if set, otherwise defaults to /bin/bash.
  # 'basename' removes the path, leaving just the filename.
  CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"

  # Check which shell it is and set the correct profile file path.
  case "$CURRENT_SHELL" in
    zsh)
      SHELL_PROFILE_FILE="${ZDOTDIR:-$HOME}/$ZSH_CONF_FILE"
      MISE_SHELL="zsh"
      log_success "Detected shell: zsh"
      echo "   Using profile: ${SHELL_PROFILE_FILE}"
      ;;
    bash)
      SHELL_PROFILE_FILE="$HOME/$BASH_CONF_FILE"
      MISE_SHELL="bash"
      log_success "Detected shell: bash"
      echo "   Using profile: ${SHELL_PROFILE_FILE}"
      ;;
    *) # If it's not zsh or bash
      log_error "Unsupported shell: '$CURRENT_SHELL'. This script requires bash or zsh."
      ;;
  esac

  # Check if the determined profile file exists.
  # '! -e "$file"' means "if file does NOT exist".
  if [[ ! -e "$SHELL_PROFILE_FILE" ]]; then
    log_info "Creating shell profile file: ${SHELL_PROFILE_FILE}"
    # Try to create the file. Stop if it fails.
    touch "$SHELL_PROFILE_FILE" || log_error "Failed to create shell profile file: ${SHELL_PROFILE_FILE}"
  # If the file exists, check if we can write to it.
  # '! -w "$file"' means "if file is NOT writable".
  elif [[ ! -w "$SHELL_PROFILE_FILE" ]]; then
    log_warning "Shell profile file is not writable: ${SHELL_PROFILE_FILE}"
    chmod u+w "$SHELL_PROFILE_FILE" || log_error "Failed to modify permissions for $SHELL_PROFILE_FILE"
  fi
}

# Checks if all the needed basic commands are installed.
check_required_commands() {
  log_info "Checking for required commands"
  local required_commands=("$@") # Get the list of commands to check.
  local missing_commands=()
  
  for cmd in "${required_commands[@]}"; do
    if ! command_exists "$cmd"; then
      # If command is not found, add it to the missing list.
      missing_commands+=("$cmd")
    else
      log_success "Command found: $cmd ($(command -v "$cmd"))"
    fi
  done
  
  # After checking all commands, see if the 'missing_commands' list has anything in it.
  # '${#missing_commands[@]}' gives the number of items in the list.
  # '-gt 0' means "greater than 0".
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    # If the list is not empty, show an error with the names of missing commands and stop.
    # '${missing_commands[*]}' joins the list items into a single string.
    log_error "Required command(s) not found: ${missing_commands[*]}. Please install them first."
  fi
}

# Shows a loading animation while a command runs in the background.
install_progress_indicator() {
  local package_name="$1"  # Name of the thing being installed (e.g., "Homebrew").
  local pid="$2"           # The Process ID (PID) of the installation running in the background.
  local spin='-\|/'        # Characters for the spinning animation.
  local i=0                # Counter for the spinner character.

  # Keep spinning as long as the background process is still running.
  # 'kill -0 $pid' checks if the process exists without stopping it. '2>/dev/null' hides errors.
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))  # Cycle through the 4 spinning characters.
    # '\r' moves the cursor back to the start of the line to overwrite.
    # '${spin:$i:1}' gets one character from the 'spin' string at position 'i'.
    printf "\r Installing %s %c " "$package_name" "${spin:$i:1}"
    sleep .1  # Wait a very short time (0.1 seconds) before the next spin update.
  done
  # After the process finishes, clear the spinning line
  printf "\r                                   \r"

  # 'wait $pid' waits for the background process to fully finish and gets its exit code.
  # The exit code tells us if the process succeeded (0) or failed (non-zero).
  wait $pid
  # Check if the background process finished successfully (exit code 0).
  if [ $? -eq 0 ]; then
    log_success "$package_name installation successful"
  else
    log_error "$package_name installation failed. Check the log file: $LOG_FILE"
  fi
}

setup_homebrew() {
  log_info "Detecting Homebrew"
  if [[ -x "$HOMEBREW_PATH" ]]; then
    log_success "Homebrew already installed"
    log_debug "Found Homebrew at $HOMEBREW_PATH"
  else
      # If Homebrew is not found, install it.
      log_info "Homebrew not found. Installing (password required)... Buckle in, this will take a while."
      
      log_debug "Requesting sudo privileges before Homebrew installer"
      # HACK to run NONINTERACTIVE installer
      sudo -v || log_error "Failed to get sudo privileges"
      
      log_debug "Running Homebrew installer"
      # 'NONINTERACTIVE=1' makes it run without asking questions.
      # '/bin/bash -c "..."' runs the commands inside the quotes using bash.
      # '$(curl -fsSL ...)' downloads the script content. '-f' fail fast, '-s' silent, '-S' show error, '-L' follow redirects.
      # '>> "$LOG_FILE" 2>&1' sends all output (normal and error) to the log file.
      # '&' runs the command in the background.
      (NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1) &
      installer_pid=$!  # Get the Process ID (PID) of the background installer. '$!' holds the PID of the last background command.
      # Show the spinning progress indicator while it installs.
      install_progress_indicator "Homebrew" $installer_pid


      log_info "Verifying Homebrew installation"
      # Check if Homebrew binaries are executable after installation attempt.
      if [[ -x "$HOMEBREW_PATH" ]]; then
        log_success "Found Homebrew at '$HOMEBREW_PATH'"
      else
        log_error "Could not find Homebrew binaries after installation."
      fi

  fi
  
  # --- Configure Homebrew in Shell Profile ---
  BREW_SHELLENV_LINE="eval \"\$(${HOMEBREW_PATH} shellenv)\""
  add_line_if_missing "$BREW_SHELLENV_LINE" "$SHELL_PROFILE_FILE" || log_error "Failed to update shell profile with Homebrew configuration"

  # --- Initialize Homebrew for the current script session ---
  log_debug "Initializing Homebrew in current session"
  eval "$(${HOMEBREW_PATH} shellenv)" || log_error "Failed to initialize Homebrew in current session"

  # Double-check that the 'brew' command is now available.
  if ! command_exists brew; then
    log_error "Could not find Homebrew command."
  fi

  log_success "Homebrew is ready to brew"

  # --- Configure Homebrew Settings ---
  log_info "Configuring Homebrew"
  log_debug "Disabling Homebrew analytics"
  # Tell Homebrew not to send usage data.
  # '>> "$LOG_FILE" 2>&1' sends output/errors to log.
  # '|| log_warning ...' shows a warning if the command fails, but doesn't stop the script.
  brew analytics off >> "$LOG_FILE" 2>&1 || log_warning "Failed to disable Homebrew analytics"

  # --- Update Homebrew ---
  log_info "Updating Homebrew"
  log_debug "Running brew update"
  # 'brew update' downloads the latest list of available software.
  # If update fails ('! ...'), show a warning but continue.
  if ! brew update >> "$LOG_FILE" 2>&1; then
    log_warning "Failed to update Homebrew. Continuing with potentially outdated package information."
  fi
  log_success "Homebrew is up to date"
}

install_package_if_missing() {
  local package="$1"

  log_debug "Checking package: $package"
  # 'brew list "$package"' checks if the package is installed.
  # '&>/dev/null' hides the output/error from 'brew list'.
  # '!' reverses the result: "if package is NOT listed".
  if ! brew list "$package" &>/dev/null; then
    log_info "Installing $package..."
    # Install the package using 'brew install'.
    # Run in the background ('&') and send output to log file ('>> ... 2>&1').
    (brew install "$package" >> "$LOG_FILE" 2>&1) &
    installer_pid=$!  # Get the process ID of the background installation.
    # Show the spinning progress indicator.
    install_progress_indicator "$package" $installer_pid
  else
    # If 'brew list' succeeded, the package is already installed.
    log_success "$package is already installed"
  fi
}

install_packages() {
  log_info "Installing required packages"
  
  local packages=("$@")
  
  for pkg in "${packages[@]}"; do
    install_package_if_missing "$pkg"
  done
}

verify_tools() {
  log_info "Verifying packages installation"
  local tools=("$@")
  
  for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
      log_error "Critical tool '$tool' is missing. Please install it."
    else
      log_success "$tool is available"
    fi
  done
}

configure_mise() {
  log_info "Configuring MISE"
  # Find where the 'mise' command is installed.
  MISE_BIN="$(command -v mise)"
  
  # Check if 'mise' was found.
  # '-z "$VAR"' checks if the variable VAR is empty.
  if [[ -z "$MISE_BIN" ]]; then
    log_error "mise command not found after installation."
  fi
  
  log_debug "mise found at $MISE_BIN"

  # This line sets up 'mise' to work with your shell (zsh or bash).
  # It needs to be added to your shell profile file.
  MISE_ACTIVATE_LINE="eval \"\$(${MISE_BIN} activate ${MISE_SHELL})\""
  # Add the line if missing. Show warning if adding fails, but don't stop.
  add_line_if_missing "$MISE_ACTIVATE_LINE" "$SHELL_PROFILE_FILE" || log_warning "Failed to update shell profile with mise configuration"

  # Activate 'mise' for the current script session.
  # '> /dev/null' hides the output. Stop with error if activation fails ('||').
  "$MISE_BIN" activate > /dev/null || log_error "Failed to activate mise in current session"
}

install_java() {
  log_debug "Checking for latest Java version"

  # Ask 'mise' for the latest available version number of the package named in $JDK (java@openjdk).
  # '2>> "$LOG_FILE"' sends any error messages from 'mise latest' to the log file.
  # If the command fails ('||'), stop with an error.
  LATEST_JDK=$("$MISE_BIN" latest "$JDK" 2>> "$LOG_FILE") || log_error "Failed to determine latest Java version"

  # Check if we got a version number.
  if [[ -z "$LATEST_JDK" ]]; then
    log_error "Failed to determine latest Java version."
  fi
  
  log_debug "Latest Java version: $LATEST_JDK"
  log_info "Installing Java $LATEST_JDK"
  
  log_debug "Running: mise install java@${LATEST_JDK}"
  # Tell 'mise' to install this specific Java version.
  # Run in the background ('&') and send output to log file.
  ("$MISE_BIN" install "java@${LATEST_JDK}" >> "$LOG_FILE" 2>&1) &
  installer_pid=$!  # Get process ID.
  # Show progress indicator.
  install_progress_indicator "Java $LATEST_JDK" $installer_pid

  log_debug "Setting Java ${LATEST_JDK} as global"
  # Tell 'mise' to make this Java version the default one for the whole system ('--global').
  # If setting global fails ('! ...'), stop with an error.
  if ! "$MISE_BIN" use --global "java@${LATEST_JDK}" >> "$LOG_FILE" 2>&1; then
    log_error "Failed to set Java ${LATEST_JDK} as global version"
  fi

  log_success "Set Java ${LATEST_JDK} as global version"
  
  log_info "Verifying Java OpenJDK installation"
  # Try running 'java -version' using 'mise exec' (which ensures the mise-managed version is used).
  # Send output to log file.
  if "$MISE_BIN" exec -- java -version >> "$LOG_FILE" 2>&1; then
    # If successful, get the first line of the version output to show the user.
    # '2>&1' sends error stream to normal output stream. '| head -n 1' takes only the first line.
    JAVA_VERSION=$("$MISE_BIN" exec -- java -version 2>&1 | head -n 1)
    log_debug "Java: $JAVA_VERSION"
    log_success "Java ${LATEST_JDK} is ready"
  else
    # If verification command failed, show a warning.
    log_warning "Java ${LATEST_JDK} verification failed."
    echo "To check manually after restarting your terminal:"
    echo "  java --version"
  fi
}

# Tries to find the 'riverSpider' directory, which should contain 'submit.sh'.
locate_river_spider_dir() {
  log_info "Locating riverSpider directory"
  
  local potential_dir
  # Search inside the user's home directory ('~') for a file named 'submit.sh'.
  # 'find ~ ...' starts searching from the home directory.
  # '-name submit.sh' looks for files with this exact name.
  # '-type f' means only find files (not directories).
  # '-exec dirname {} \;' runs the 'dirname' command on each found file path ('{}')
  #                      to get just the directory part. '\;' ends the -exec command.
  # '2> /dev/null' hides errors (like "Permission denied" in some folders).
  # '| grep "/riverSpider$"' filters the results, keeping only lines that end with "/riverSpider".
  # '| head -n 1' takes only the first matching directory found.
  potential_dir=$(find ~/ -name submit.sh -type f -exec dirname {} \; 2> /dev/null | grep "/riverSpider$" | head -n 1) || true
  # Check if a directory path was found ('-n' checks if string is not empty)
  # AND if that path actually points to a directory ('-d' checks if it's a directory).
  if ! [[ -n "$potential_dir" && -d "$potential_dir" ]]; then
    log_error "Could not locate riverSpider. See Canvas for download instructions."
  fi
  # Save the found path into the RIVER_SPIDER_DIR variable.
  # 'export' makes it available in this terminal sessions.
  export RIVER_SPIDER_DIR="$potential_dir"
  log_success "Found riverSpider/submit.sh at $potential_dir"

  # Add a line to the shell profile file to remember this path for future terminal sessions.
  # This line will look like: export RIVER_SPIDER_DIR="/path/to/riverSpider"
  add_riverspider_to_profile "export RIVER_SPIDER_DIR=\"$RIVER_SPIDER_DIR\""
}

add_riverspider_to_profile() {
  local line_to_set="$1"
  # This pattern is used to find existing lines that set RIVER_SPIDER_DIR.
  # '^' means "start of the line".
  local pattern_to_find="^export RIVER_SPIDER_DIR="

  # Check if the SHELL_PROFILE_FILE variable is set and if the file exists.
  # '-z "$VAR"' checks if empty. '! -f "$file"' checks if file does not exist.
  if [[ -z "$SHELL_PROFILE_FILE" || ! -f "$SHELL_PROFILE_FILE" ]]; then
    log_warning "Please add this line to your shell profile:" 
    echo "$line_to_set"
  # Check if a line matching the pattern already exists in the profile file.
  # 'grep -q' searches quietly.
  elif grep -q "$pattern_to_find" "$SHELL_PROFILE_FILE"; then
    if [[ ! -w "$SHELL_PROFILE_FILE" ]]; then
      log_warning "Shell profile file is not writable: $SHELL_PROFILE_FILE"
      chmod u+w "$SHELL_PROFILE_FILE" || log_error "Failed to modify permissions for $SHELL_PROFILE_FILE"
    fi
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
    { echo ""; echo "$line_to_set"; echo "";} >> "$SHELL_PROFILE_FILE" || 
      log_warning "Could not add RIVER_SPIDER_DIR to $SHELL_PROFILE_FILE. Add manually: $line_to_set"
  fi
}

# Changes relative paths (like 'secretString.txt') inside the submit.sh script
# to absolute paths (like '/Users/you/riverSpider/secretString.txt').
update_riverspider_paths() {
 log_info "Configuring riverSpider"
 
 # Check if the RIVER_SPIDER_DIR variable is set.
 if [[ -z "$RIVER_SPIDER_DIR" ]]; then
   log_error "RIVER_SPIDER_DIR environment variable is not set."
 fi
 
 # Construct the full path to the submit.sh script.
 local submit_script="$RIVER_SPIDER_DIR/submit.sh"

 # Check if the submit.sh script exists.
 if [[ ! -f "$submit_script" ]]; then
   log_error "Submit script not found at $submit_script"
 fi

 if [[ ! -w "$submit_script" ]]; then
    log_warning "submit.sh file is not writable: $submit_script"
    chmod u+w "$submit_script" || log_error "Failed to modify permissions for $submit_script"
 fi

# --- Define the NEW lines with absolute paths ---
 # These use the $RIVER_SPIDER_DIR variable found earlier.
 NEW_SECRETS_LINE="secretPath=\"${RIVER_SPIDER_DIR}/secretString.txt\""
 NEW_WEBAPP_LINE="webappUrlPath=\"${RIVER_SPIDER_DIR}/webapp.url\""
 NEW_LOGISIM_LINE="logisimPath=\"${RIVER_SPIDER_DIR}/logisim310.jar\""
 NEW_PROC_LINE="processorCircPath=\"${RIVER_SPIDER_DIR}/processor0004.circ\""
 NEW_URLENCODE_LINE="urlencodeSedPath=\"${RIVER_SPIDER_DIR}/urlencode.sed\""

 # --- Use 'sed' to replace OLD lines with NEW lines in submit.sh ---
 # 'sed -i''' modifies the file directly. '-e "s#old#new#"' performs substitution.
 # '&& log_success ...' runs log_success only if sed command succeeded (exit code 0).
 # '|| log_warning ...' runs log_warning only if sed command failed (non-zero exit code).
 sed -i'' -e "s#${OLD_SECRETS_LINE}#${NEW_SECRETS_LINE}#" "$submit_script" && log_success " - Updated secretPath" || log_warning " - FAILED to update secretPath"
 sed -i'' -e "s#${OLD_WEBAPP_LINE}#${NEW_WEBAPP_LINE}#" "$submit_script" && log_success " - Updated webappUrlPath" || log_warning " - FAILED to update webappUrlPath"
 sed -i'' -e "s#${OLD_LOGISIM_LINE}#${NEW_LOGISIM_LINE}#" "$submit_script" && log_success " - Updated logisimPath" || log_warning " - FAILED to update logisimPath"
 sed -i'' -e "s#${OLD_PROC_LINE}#${NEW_PROC_LINE}#" "$submit_script" && log_success " - Updated processorCircPath" || log_warning " - FAILED to update processorCircPath"
 sed -i'' -e "s#${OLD_URLENCODE_LINE}#${NEW_URLENCODE_LINE}#" "$submit_script" && log_success " - Updated urlencodeSedPath" || log_warning " - FAILED to update urlencodeSedPath"

 log_success "Updated paths in $submit_script"
}

# Adds a new, easy-to-use command 'riverspider' to your shell profile file.
# This command makes running the main submit.sh script simpler.
add_river_spider_helper() {
  log_info "Setting up River Spider helper function..."
  
  if [[ ! -w "$SHELL_PROFILE_FILE" ]]; then
    log_warning "Shell profile file is not writable: $SHELL_PROFILE_FILE"
    chmod u+w "$SHELL_PROFILE_FILE" || log_error "Failed to modify permissions for $SHELL_PROFILE_FILE"
  fi
  if grep -q "riverspider()" "$SHELL_PROFILE_FILE"; then
    log_success "'riverspider' helper function already in shell profile"
  else
    echo "Adding River Spider helper function..."
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
    { echo ""; echo "$line_to_set"; } >> "$shell_profile" ||
      echo "Could not add RIVER_SPIDER_DIR to $shell_profile. Add manually: $line_to_set"
  fi
}
#=============================================
EOF

    echo "" >>  "$SHELL_PROFILE_FILE"
    sed -i '' -e "s#zsh) shell_profile=.*#zsh) shell_profile=\"\${ZDOTDIR:-\$HOME}/${ZSH_CONF_FILE}\" ;;#" "$SHELL_PROFILE_FILE"
    sed -i '' -e "s#bash) shell_profile=.*#bash) shell_profile=\"\$HOME/${BASH_CONF_FILE}\" ;;#" "$SHELL_PROFILE_FILE"
    if grep -q "riverspider()" "$SHELL_PROFILE_FILE"; then
      log_success "Added 'riverspider' helper function to shell profile"
      log_debug "Confirmed 'riverspider' helper function exists in $SHELL_PROFILE_FILE."
    else
      log_warning "Failed to add 'riverspider' helper function. Please add the following manually to your shell profile file:"
      echo ""
      echo "$HELPER_FUNCTION"
      echo ""
    fi
  fi
}

# This part of the setup cannot be automated by the script.
display_riverspider_setup_instructions() {
  echo ""
  log_warning "Manual setup of River Spider required:"

  echo ""
  echo "👉 Make a copy of:"
  echo ""
  echo "   shared/processor/$GOOGLE_SHEETS_NAME"
  echo "   $GOOGLE_DRIVE_URL"
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
  echo "📥 Paste it into:"
  echo "   $RIVER_SPIDER_DIR/webapp.url"
  echo ""
  echo "📦 To verify River Spider setup:"
  echo "   cd $RIVER_SPIDER_DIR"
  echo "   ./submit.sh test.ttpasm"
  echo ""
}

display_completion_message() {
  echo ""
  log_info "Setup complete!"
  log_info "───────────────────────────────────────────────"
  log_info "Please restart your terminal"
  log_info "or run: source ${SHELL_PROFILE_FILE}"
  log_info "to apply all changes."
  log_info "───────────────────────────────────────────────"
  log_info "Log file: ${LOG_FILE}"
  echo ""
  
  log_debug "Script completed successfully at $(date)"
}

main() {
  setup_terminal_colors

  echo "Setup started at $(date)" > "$LOG_FILE"
  log_info "Starting riverSpider setup script"
  log_info "Setup started at: $(date)"
  log_info "Setup logfile:    $LOG_FILE"


  # === Pre-flight Checks ===
  # Run checks before attempting any installations.
  check_macos     # Check if on macOS.
  check_internet  # Check for internet connection.
  detect_shell    # Find shell and profile file.
  # Check if basic commands like 'curl', 'git' etc. are installed.
  check_required_commands "${REQUIRED_COMMANDS[@]}"

  # === riverSpider Directory Setup ===
  locate_river_spider_dir    # Find the downloaded riverSpider folder.
  update_riverspider_paths   # Fix paths inside submit.sh (so it can be called from anywhere)

  # === Software Installation ===
  setup_homebrew # install or find Homebrew binaries
  
  install_packages "${PACKAGES_TO_INSTALL[@]}" # Install tools via Homebrew.
  verify_tools "${TOOLS_TO_VERIFY[@]}"         # make sure tools are usuable
  
  configure_mise                               # Set up the 'mise' tool.
  install_java                                 # Install Java using 'mise'.

  # === Final Configuration ===
  
  add_river_spider_helper                      # Add the 'riverspider' command to profile.
  
  display_riverspider_setup_instructions       # Show Google Sheets steps.
  
  display_completion_message
  
  return 0
}

main "$@"
exit 0
