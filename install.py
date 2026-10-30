#!/usr/bin/env python3
"""
PyStudio cross-platform installer launcher.

Detects the OS, asks the user which platform to install for.
If the installer script (install.sh or install.ps1) is missing,
it automatically downloads it from GitHub before running.
"""

import os
import platform
import subprocess
import sys
import urllib.request

# ============================================================
#  GITHUB CONFIGURATION
# ============================================================
REPO_OWNER = "Codez-suriya"
REPO_NAME = "PyStudio"
# ⚠️ REMINDER: Change this back to "main" before merging your Temp branch!
BRANCH = "main"  


def detect_os() -> str:
    """Return 'windows', 'linux', or 'unknown'."""
    sysname = platform.system().lower()
    if sysname == "windows":
        return "windows"
    if sysname == "linux":
        return "linux"
    return "unknown"


def run(cmd, cwd=None):
    """Run a command, stream output, return exit code (integer)."""
    print(f"  > {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, cwd=cwd)
        return result.returncode
    except FileNotFoundError:
        print(f"  ERROR: Command not found: {cmd[0]}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return 1


def download_file(url, dest_path):
    """Download a single file from the internet."""
    print(f"[*] Downloading {os.path.basename(dest_path)}...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        print(f"[+] Downloaded successfully.")
    except Exception as e:
        print(f"  ERROR: Failed to download {url}", file=sys.stderr)
        print(f"  Details: {e}", file=sys.stderr)
        sys.exit(1)


def install_linux(script_dir: str) -> int:
    """Download (if needed) and run install.sh."""
    script = os.path.join(script_dir, "install.sh")
    
    if not os.path.isfile(script):
        url = f"https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{BRANCH}/install.sh"
        download_file(url, script)
        
    # Ensure it's executable
    os.chmod(script, 0o755)
    
    print("[*] Starting Linux installation...")
    return run(["bash", "install.sh"], cwd=script_dir)


def install_windows(script_dir: str) -> int:
    """Download and run the Windows installer in the selected directory."""

    default_dir = os.path.join(
        os.path.expanduser("~"), "Downloads", "PyStudio"
    )

    print("\n  PyStudio Windows Installer")
    print("  --------------------------")
    print(f"  Default location: {default_dir}")

    try:
        user_dir = input(
            "\n  Enter installation directory (press Enter for default): "
        ).strip()
    except (EOFError, KeyboardInterrupt):
        print("\n  Installation cancelled.")
        return 1

    # Resolve the installation directory.
    if user_dir:
        install_dir = os.path.abspath(
            os.path.expandvars(os.path.expanduser(user_dir))
        )

        parent_dir = os.path.dirname(install_dir)

        # Allow a new destination folder if its parent exists.
        if (
            not os.path.isdir(parent_dir)
            or os.path.isfile(install_dir)
        ):
            print("[!] Invalid directory. Using Downloads instead.")
            install_dir = default_dir
    else:
        install_dir = default_dir

    # Create the destination directory.
    try:
        os.makedirs(install_dir, exist_ok=True)
    except OSError as e:
        print(f"[!] Cannot use selected directory: {e}")
        print("[!] Falling back to Downloads.")

        install_dir = default_dir

        try:
            os.makedirs(install_dir, exist_ok=True)
        except OSError as fallback_error:
            print(
                f"[ERROR] Cannot create Downloads directory: {fallback_error}",
                file=sys.stderr
            )
            return 1

    print(f"\n[*] Installation location: {install_dir}")

    install_script = os.path.join(install_dir, "install.ps1")
    run_script = os.path.join(install_dir, "run.ps1")

    # Download the latest Windows installer script.
    url = (
        f"https://raw.githubusercontent.com/"
        f"{REPO_OWNER}/{REPO_NAME}/{BRANCH}/install.ps1"
    )

    try:
        download_file(url, install_script)
    except Exception as e:
        print(f"[ERROR] Installer download failed: {e}", file=sys.stderr)
        return 1

    # Run the PowerShell installer.
    # Note: install.ps1 will automatically download the repository files 
    # into this directory because we are passing -InstallDir.
    print("\n[*] Starting Windows installation...")

    rc = run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            install_script,
            "-InstallDir",
            install_dir,
        ],
        cwd=install_dir,
    )

    if rc != 0:
        print(
            f"[ERROR] Windows installation failed with code {rc}",
            file=sys.stderr
        )
        return rc

    # Ask whether to launch PyStudio.
    if os.path.isfile(run_script):
        try:
            ans = input("\n  Launch PyStudio now? [Y/n] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            ans = "n"

        if ans in ("", "y", "yes"):
            print("[*] Launching PyStudio...")

            return run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    run_script,
                ],
                cwd=install_dir,
            )

        print(f"\n  Run it later with: {run_script}")
    else:
        print("[!] run.ps1 not found. Skipping launch.")

    return 0


def main() -> int:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    detected = detect_os()

    print("")
    print("  PyStudio installer")
    print("  ------------------")
    print(f"  Detected platform: {platform.system()} ({platform.machine()})")
    print("")
    print("  Select target platform:")
    print("    1) Linux")
    print("    2) Windows")
    print("")

    try:
        choice = input("  Enter 1 or 2: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n  Cancelled.")
        return 1

    if choice == "1":
        if detected != "linux":
            print("WARNING: selected Linux but the current OS is not Linux.", file=sys.stderr)
        return install_linux(script_dir)
    elif choice == "2":
        if detected != "windows":
            print("WARNING: selected Windows but the current OS is not Windows.", file=sys.stderr)
        return install_windows(script_dir)
    else:
        print("  Invalid choice. Enter 1 or 2.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
