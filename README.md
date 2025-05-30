# Frappe Developer Machine Setup

### Running on Windows using WSL

1. **Check if WSL is installed:**

   - **Open Windows Terminal as Administrator.**
   - Run the following command:
     ```powershell
     wsl --list --verbose
     ```
   - If WSL is not installed, proceed to the next step.

2. **Enable WSL:**
   - Run the following command:
     ```powershell
     wsl --install
     ```
   - **Restart your computer.**

### Create WSL Instance

3. **Create a WSL instance named "frappe-dev":**
   - **Open Windows Terminal as Administrator.**
   - Run the following command:
     ```powershell
     wsl --install Ubuntu --name frappe-dev
     ```
   - Set user and password when the system prompted
   - Run the following command to exit from WSL:
   ```powershell
   exit
   ```

### Access WSL Instance

4. **Access the "frappe-dev" WSL instance:**
   - Run the following command:
     ```powershell
     wsl -d frappe-dev
     ```

### Running on Ubuntu/Debian

> COMING SOON !!!

### Running on MacOS using colima

> COMING SOON !!!

### Download and Run Installer Script

5. **Download the installer script using curl:**

   - In the WSL terminal, run:
     ```bash
     curl -fsSL -o /tmp/installer.sh https://raw.githubusercontent.com/akarapol/frappe-dev-machine-installer/refs/heads/main/installer.sh
     ```

6. **Change variables in the script if needed:**

   - Open the script in a text editor, for example:
     ```bash
     nano /tmp/installer.sh
     ```
   - Make any necessary changes to the variables.
   - Save and exit the editor.

7. **Run the script:**
   - In the WSL terminal, run:
     ```bash
     bash /tmp/installer.sh
     ```
