# riverSpider macOS Setup Script

# [INSTALL WALKTHROUGH](https://youtu.be/wYY27ob8vMY)

## Before Install (Required)
**Download riverSpider and setup Google Sheets Web App:**
* Download and Unzip `riverSpider` (SEE CANVAS)
* Setup [Google Sheet - Student Assembler](https://drive.google.com/drive/folders/0BxsMACqxAFNwR1pCb2pPeE5Wb1E?resourcekey=0-fb_u058vHLwLSyiSaBKPoQ):
   * Make a copy of **'Copy of assemblerStudent'**
     * File > Make a Copy
     * Save it to: My Drive
     * Click: 'Make a Copy' 
   * Deploy App Script (in your copy)
     * Extensions > Apps Script
     * Deploy > New Deployment
       ```
       Description:    River Spider Script
       Execute as:     Me
       Access:         Anyone
       ```
     * Click: 'Deploy'
     * Authorize and Allow Access
   * Put Web App URL into `riverSpider/webapp.url`
     
**Grant Full Disk Access to Terminal:**

1.  Go to **System Settings > Privacy & Security > Full Disk Access**.
2.  Click **+**, navigate to `Applications/Utilities/`, select **Terminal.app**, and click **Open**.
3.  Ensure the switch next to Terminal is **ON**.
## Install
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/b1gbyt3/macOS-riverSpider/HEAD/install.sh)"
```

* Installs: [Homebrew](https://brew.sh), [mise](https://github.com/jdx/mise?tab=readme-ov-file#what-is-it), [fd](https://github.com/sharkdp/fd?tab=readme-ov-file#fd), [wget](https://www.gnu.org/software/wget/), [coreutils](https://www.gnu.org/software/coreutils/), [OpenJDK](https://openjdk.org)
* Adds: `riverspider` shell function to your config file

## After Install (Required)
* Source config:
  * `source ~/.zprofile` (Zsh)
  * `source ~/.bash_profile` (Bash)
* Or restart terminal

## Usage
```bash
riverspider <your_file.ttpasm>
```


## LIMITATIONS
### Shell Config Files
> NOTE: CURRENTLY ONLY WORKS ON [bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) AND [zsh](https://en.wikipedia.org/wiki/Z_shell)
* Defaults:
  *  `~/.zprofile` (Zsh)
  *  `~/.bash_profile` (Bash)
* **Using different files?**
  ```bash
  git clone https://github.com/b1gbyt3/macOS-riverSpider.git && cd macOS-riverSpider
  ```
  * Edit in `install.sh`:
  ```bash
  ZSH_CONF_FILE=".zprofile"  # Change if using .zshrc
  BASH_CONF_FILE=".bash_profile"  # Change if using .bashrc
  ```
  * Run: `chmod +x install.sh && ./install.sh`

### ⚠️ No Spaces in Paths!
* ✅ GOOD: `~/CISP_310/riverSpider/`
* ❌ BAD: `~/CISP 310/riverSpider/`
* ✅ GOOD: `~/CISP310/riverSpider/my-file.ttpasm`
* ❌ BAD: `~/CISP_310/riverSpider/my file.ttpasm`
> NO this `~/"CISP 310"/riverSpider/` and `~/CISP\ 310/riverSpider/` **DOESN'T FIX IT**
