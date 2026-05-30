; ==================================================
; Localhost Manager - Professional NSIS Installer
; Version: 1.0.0
; Supports: XAMPP, WAMP, Laragon
; ==================================================

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "WinVer.nsh"

; ==================== CONFIGURATION ====================
!define PRODUCT_NAME "Localhost Manager"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Localhost Manager"
!define PRODUCT_WEB_SITE "https://github.com/localhost-manager"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\localhost-manager.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; Installer attributes
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "LocalhostManager-Setup-${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES64\Localhost Manager"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

; Compression
SetCompressor /SOLID lzma
SetCompressorDictSize 64

; ==================== MUI CONFIGURATION ====================
!define MUI_ABORTWARNING
!define MUI_ICON "..\..\desktop-app\src-tauri\icons\icon.ico"
!define MUI_UNICON "..\..\desktop-app\src-tauri\icons\icon.ico"
; Note: Custom banner images are optional. Uncomment if you have them:
; !define MUI_WELCOMEFINISHPAGE_BITMAP "installer-banner.bmp"
; !define MUI_HEADERIMAGE
; !define MUI_HEADERIMAGE_BITMAP "installer-header.bmp"
; !define MUI_HEADERIMAGE_RIGHT

; Welcome page
!define MUI_WELCOMEPAGE_TITLE "Welcome to ${PRODUCT_NAME} Setup"
!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation of ${PRODUCT_NAME}.$\r$\n$\r$\n${PRODUCT_NAME} helps you manage Apache virtual hosts, SSL certificates, and local development environments.$\r$\n$\r$\nSupported stacks: XAMPP, WAMP, Laragon$\r$\n$\r$\nClick Next to continue."

; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\localhost-manager.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${PRODUCT_NAME}"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "View README"

; ==================== PAGES ====================
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
Page custom StackSelectionPage StackSelectionPageLeave
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Language
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Spanish"

; ==================== VARIABLES ====================
Var Dialog
Var Label
Var StackCombo
Var SelectedStack
Var XAMPPDetected
Var WAMPDetected
Var LaragonDetected

; ==================== FUNCTIONS ====================

Function .onInit
    ; Check Windows version (requires Windows 10+)
    ${IfNot} ${AtLeastWin10}
        MessageBox MB_OK|MB_ICONSTOP "This application requires Windows 10 or later."
        Abort
    ${EndIf}

    ; Detect installed stacks
    StrCpy $XAMPPDetected "0"
    StrCpy $WAMPDetected "0"
    StrCpy $LaragonDetected "0"

    IfFileExists "C:\xampp\apache\bin\httpd.exe" 0 +2
        StrCpy $XAMPPDetected "1"

    IfFileExists "C:\wamp64\bin\apache\*.*" 0 +2
        StrCpy $WAMPDetected "1"

    IfFileExists "C:\laragon\bin\apache\*.*" 0 +2
        StrCpy $LaragonDetected "1"

    ; Default to XAMPP if detected, otherwise first available
    ${If} $XAMPPDetected == "1"
        StrCpy $SelectedStack "xampp"
    ${ElseIf} $WAMPDetected == "1"
        StrCpy $SelectedStack "wamp"
    ${ElseIf} $LaragonDetected == "1"
        StrCpy $SelectedStack "laragon"
    ${Else}
        StrCpy $SelectedStack "xampp"
    ${EndIf}
FunctionEnd

Function StackSelectionPage
    !insertmacro MUI_HEADER_TEXT "Select Development Stack" "Choose your local development environment"

    nsDialogs::Create 1018
    Pop $Dialog

    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; Title label
    ${NSD_CreateLabel} 0 0 100% 24u "Select the development stack you want to use with ${PRODUCT_NAME}:"
    Pop $Label

    ; Detection status
    ${NSD_CreateGroupBox} 0 30u 100% 70u "Detected Stacks"
    Pop $0

    ; XAMPP status
    ${If} $XAMPPDetected == "1"
        ${NSD_CreateLabel} 10u 45u 90% 12u "✓ XAMPP detected at C:\xampp"
    ${Else}
        ${NSD_CreateLabel} 10u 45u 90% 12u "✗ XAMPP not found"
    ${EndIf}
    Pop $0

    ; WAMP status
    ${If} $WAMPDetected == "1"
        ${NSD_CreateLabel} 10u 60u 90% 12u "✓ WAMP detected at C:\wamp64"
    ${Else}
        ${NSD_CreateLabel} 10u 60u 90% 12u "✗ WAMP not found"
    ${EndIf}
    Pop $0

    ; Laragon status
    ${If} $LaragonDetected == "1"
        ${NSD_CreateLabel} 10u 75u 90% 12u "✓ Laragon detected at C:\laragon"
    ${Else}
        ${NSD_CreateLabel} 10u 75u 90% 12u "✗ Laragon not found"
    ${EndIf}
    Pop $0

    ; Stack selection
    ${NSD_CreateLabel} 0 110u 100% 12u "Select stack to configure:"
    Pop $Label

    ${NSD_CreateDropList} 0 125u 200u 80u ""
    Pop $StackCombo

    ; Add items to combo
    ${NSD_CB_AddString} $StackCombo "XAMPP"
    ${NSD_CB_AddString} $StackCombo "WAMP"
    ${NSD_CB_AddString} $StackCombo "Laragon"

    ; Select default
    ${If} $SelectedStack == "xampp"
        ${NSD_CB_SelectString} $StackCombo "XAMPP"
    ${ElseIf} $SelectedStack == "wamp"
        ${NSD_CB_SelectString} $StackCombo "WAMP"
    ${ElseIf} $SelectedStack == "laragon"
        ${NSD_CB_SelectString} $StackCombo "Laragon"
    ${EndIf}

    ; Warning label
    ${NSD_CreateLabel} 0 150u 100% 24u "Note: You can change the stack later in the application settings."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function StackSelectionPageLeave
    ${NSD_GetText} $StackCombo $0

    ${If} $0 == "XAMPP"
        StrCpy $SelectedStack "xampp"
    ${ElseIf} $0 == "WAMP"
        StrCpy $SelectedStack "wamp"
    ${ElseIf} $0 == "Laragon"
        StrCpy $SelectedStack "laragon"
    ${EndIf}
FunctionEnd

; ==================== INSTALLER SECTIONS ====================

Section "Main Application" SecMain
    SectionIn RO

    SetOutPath "$INSTDIR"

    ; Copy main application files
    File "..\..\desktop-app\src-tauri\target\release\localhost-manager.exe"
    File /oname=README.md "..\..\README.md"

    ; Create user config directory
    CreateDirectory "$PROFILE\localhost-manager"
    CreateDirectory "$PROFILE\localhost-manager\conf"
    CreateDirectory "$PROFILE\localhost-manager\certs"
    CreateDirectory "$PROFILE\localhost-manager\backups"
    CreateDirectory "$PROFILE\localhost-manager\scripts"
    CreateDirectory "$PROFILE\localhost-manager\scripts\windows"

    ; Copy PowerShell scripts
    SetOutPath "$PROFILE\localhost-manager\scripts\windows"
    File "..\..\scripts\windows\generate-all.ps1"
    File "..\..\scripts\windows\generate-vhosts-config.ps1"
    File "..\..\scripts\windows\generate-certificates.ps1"
    File "..\..\scripts\windows\update-hosts.ps1"
    File "..\..\scripts\windows\install.ps1"

    ; Create default hosts.json if not exists
    IfFileExists "$PROFILE\localhost-manager\conf\hosts.json" +3 0
        SetOutPath "$PROFILE\localhost-manager\conf"
        FileOpen $0 "$PROFILE\localhost-manager\conf\hosts.json" w
        FileWrite $0 "{}"
        FileClose $0

    ; Save selected stack to config
    SetOutPath "$PROFILE\localhost-manager\conf"
    FileOpen $0 "$PROFILE\localhost-manager\conf\stack.conf" w
    FileWrite $0 "$SelectedStack"
    FileClose $0

    ; Create Start Menu shortcuts
    SetOutPath "$INSTDIR"
    CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\localhost-manager.exe" "" "$INSTDIR\localhost-manager.exe" 0
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

    ; Desktop shortcut
    CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\localhost-manager.exe" "" "$INSTDIR\localhost-manager.exe" 0

    ; Write registry keys
    WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\localhost-manager.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\localhost-manager.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoModify" 1
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoRepair" 1

    ; Get install size
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Visual C++ Runtime" SecVCRuntime
    ; Check if VC++ Runtime is installed
    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Installed"
    ${If} $0 != "1"
        DetailPrint "Installing Visual C++ Runtime..."
        SetOutPath "$TEMP"
        File "vc_redist.x64.exe"
        ExecWait '"$TEMP\vc_redist.x64.exe" /quiet /norestart'
        Delete "$TEMP\vc_redist.x64.exe"
    ${Else}
        DetailPrint "Visual C++ Runtime already installed"
    ${EndIf}
SectionEnd

Section "WebView2 Runtime" SecWebView2
    ; Check if WebView2 is installed
    ReadRegStr $0 HKLM "SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
    ${If} $0 == ""
        ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
    ${EndIf}

    ${If} $0 == ""
        DetailPrint "Installing WebView2 Runtime..."
        SetOutPath "$TEMP"
        File "MicrosoftEdgeWebview2Setup.exe"
        ExecWait '"$TEMP\MicrosoftEdgeWebview2Setup.exe" /silent /install'
        Delete "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    ${Else}
        DetailPrint "WebView2 Runtime already installed (version: $0)"
    ${EndIf}
SectionEnd

; ==================== UNINSTALLER ====================

Section "Uninstall"
    ; Remove application files
    Delete "$INSTDIR\localhost-manager.exe"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR"

    ; Remove Start Menu shortcuts
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
    RMDir "$SMPROGRAMS\${PRODUCT_NAME}"

    ; Remove Desktop shortcut
    Delete "$DESKTOP\${PRODUCT_NAME}.lnk"

    ; Remove registry keys
    DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"

    ; Ask about user data
    MessageBox MB_YESNO|MB_ICONQUESTION "Do you want to remove your configuration files and certificates?$\r$\n$\r$\nThis includes your virtual hosts configuration and SSL certificates." IDNO +3
        RMDir /r "$PROFILE\localhost-manager"

    SetAutoClose true
SectionEnd

; ==================== DESCRIPTIONS ====================

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "Main application files and scripts"
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVCRuntime} "Microsoft Visual C++ Runtime (required)"
    !insertmacro MUI_DESCRIPTION_TEXT ${SecWebView2} "Microsoft WebView2 Runtime (required for UI)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END
