@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: Helios + Pi — Windows CMD Installer
:: =============================================================================
:: Usage: curl -fsSL https://raw.githubusercontent.com/sweetcheeks72/helios-team-installer/main/install.bat -o %TEMP%\install-helios.bat && %TEMP%\install-helios.bat
:: =============================================================================

echo.
echo  ================================================================
echo    H E L I O S   +   P i   —   Windows Installer
echo  ================================================================
echo    One-command setup for the full Helios AI orchestrator stack
echo  ================================================================
echo.

:: ─── Check Administrator privileges ─────────────────────────────────────────
:: net session is a lightweight admin check that works on all Windows versions
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] This installer requires Administrator privileges.
    echo.
    echo      WSL installation needs admin rights to enable Windows features.
    echo.
    echo  HOW TO FIX:
    echo    1. Close this window
    echo    2. Find cmd.exe in the Start menu
    echo    3. Right-click ^> "Run as administrator"
    echo    4. Re-run this installer
    echo.
    pause
    exit /b 1
)
echo  [+] Running as Administrator — OK
echo.

:: ─── Check for curl ──────────────────────────────────────────────────────────
:: curl is built into Windows 10 1803+ (C:\Windows\System32\curl.exe)
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] curl is not available on this system.
    echo.
    echo      curl is built into Windows 10 version 1803 and later.
    echo      Your Windows version appears to be too old or curl is missing.
    echo.
    echo  HOW TO FIX:
    echo    Update Windows:  Settings ^> Windows Update ^> Check for updates
    echo    Or download curl manually from: https://curl.se/windows/
    echo.
    pause
    exit /b 1
)
echo  [+] curl found — OK
echo.

:: ─── Check for WSL ───────────────────────────────────────────────────────────
:: wsl.exe lives in System32; --status exits 0 on WSL2-capable systems
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] WSL (Windows Subsystem for Linux) is not available or not enabled.
    echo.
    echo      Helios runs inside WSL 2 (Ubuntu). You need to install WSL first.
    echo.
    echo  HOW TO FIX:
    echo    1. Run:  wsl --install
    echo       (This enables WSL and installs Ubuntu automatically)
    echo    2. Restart your computer
    echo    3. Re-run this installer
    echo.
    echo  WSL documentation: https://learn.microsoft.com/en-us/windows/wsl/install
    echo.
    pause
    exit /b 1
)
echo  [+] WSL is available — OK
echo.

:: ─── Check for Ubuntu in WSL ─────────────────────────────────────────────────
:: -l -q lists installed distro names, one per line (no headers)
:: We pipe through findstr for a case-insensitive match on "Ubuntu"
wsl -l -q 2>nul | findstr /i "Ubuntu" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [~] Ubuntu is not installed in WSL. Installing now...
    echo.
    echo      This will download and install Ubuntu from the Microsoft Store.
    echo      It may take a few minutes depending on your internet speed.
    echo.
    wsl --install -d Ubuntu
    if %errorlevel% neq 0 (
        echo.
        echo  [!] WSL Ubuntu installation failed or requires a restart.
    )
    echo.
    echo  ================================================================
    echo    ACTION REQUIRED: Restart your computer
    echo  ================================================================
    echo.
    echo    WSL requires a full restart to finish setting up.
    echo    After restarting:
    echo.
    echo      1. Ubuntu will open automatically to complete setup
    echo         (create your Linux username and password)
    echo      2. Then re-run this installer from CMD as Administrator
    echo.
    pause
    exit /b 0
)
echo  [+] Ubuntu found in WSL — OK
echo.

:: ─── Run bootstrap inside WSL Ubuntu ────────────────────────────────────────
echo  ================================================================
echo    Running Helios installer inside WSL Ubuntu...
echo  ================================================================
echo.
echo  This will install: Pi CLI, Helios agents, skills, extensions,
echo  Memgraph, Ollama, MCP servers, and configure your API keys.
echo.

wsl -d Ubuntu -- bash -c "curl -fsSL https://raw.githubusercontent.com/sweetcheeks72/helios-team-installer/main/bootstrap.sh | bash"
if %errorlevel% neq 0 (
    echo.
    echo  [!] The Helios bootstrap script exited with an error.
    echo.
    echo      Check the output above for details.
    echo      Common fixes:
    echo        - Make sure Ubuntu WSL has internet access
    echo        - Run:  wsl -d Ubuntu -- ping github.com
    echo        - Retry this installer
    echo.
    pause
    exit /b 1
)

echo.
echo  [+] Bootstrap completed — OK
echo.

:: ─── Create CMD shims ────────────────────────────────────────────────────────
:: Shims live in %LOCALAPPDATA%\Programs\Helios\ so no system-wide writes needed
set "SHIM_DIR=%LOCALAPPDATA%\Programs\Helios"

if not exist "%SHIM_DIR%" (
    mkdir "%SHIM_DIR%"
    echo  [+] Created shim directory: %SHIM_DIR%
) else (
    echo  [~] Shim directory already exists — updating shims
)

:: Write helios.cmd
(
    echo @echo off
    echo wsl -d Ubuntu -- helios %%*
) > "%SHIM_DIR%\helios.cmd"
if %errorlevel% neq 0 (
    echo  [!] Failed to write helios.cmd to %SHIM_DIR%
    pause
    exit /b 1
)
echo  [+] Created: %SHIM_DIR%\helios.cmd

:: Write pi.cmd
(
    echo @echo off
    echo wsl -d Ubuntu -- pi %%*
) > "%SHIM_DIR%\pi.cmd"
if %errorlevel% neq 0 (
    echo  [!] Failed to write pi.cmd to %SHIM_DIR%
    pause
    exit /b 1
)
echo  [+] Created: %SHIM_DIR%\pi.cmd

echo.

:: ─── Add shim directory to user PATH ────────────────────────────────────────
:: Read current user PATH from registry (setx reads from here, not process env)
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do (
    set "CURRENT_PATH=%%B"
)

:: Check if shim dir is already in PATH (case-insensitive)
echo !CURRENT_PATH! | findstr /i /c:"%SHIM_DIR%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [~] Shim directory already in PATH — skipping setx
) else (
    if defined CURRENT_PATH (
        setx PATH "!CURRENT_PATH!;%SHIM_DIR%" >nul
    ) else (
        setx PATH "%SHIM_DIR%" >nul
    )
    if %errorlevel% neq 0 (
        echo  [!] Failed to update PATH with setx.
        echo      Add this directory to your PATH manually:
        echo      %SHIM_DIR%
    ) else (
        echo  [+] Added to user PATH: %SHIM_DIR%
    )
)

echo.

:: ─── Success ─────────────────────────────────────────────────────────────────
echo  ================================================================
echo    Helios is installed!
echo  ================================================================
echo.
echo    The following commands are now available from CMD:
echo.
echo      helios "your task here"
echo      pi "your task here"
echo.
echo    NOTE: Open a NEW CMD window for PATH changes to take effect.
echo.
echo  NEXT STEPS:
echo    1. Close this window and open a new CMD
echo    2. Run:  helios "hello world"
echo    3. Read the team setup guide:
echo       https://github.com/sweetcheeks72/helios-team-installer/blob/main/TEAM-SETUP.md
echo.
echo  TIP: You can also run Helios directly from WSL Ubuntu:
echo    Start Menu ^> Ubuntu ^> then type: helios "task"
echo.
echo  ================================================================
echo.
pause
endlocal
