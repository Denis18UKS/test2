Unicode true

!include "MUI2.nsh"
!include "LogicLib.nsh"

Name "VK Dialog Exporter"
OutFile "dist\VKDialogExporter.exe"
InstallDir "$LOCALAPPDATA\Programs\VKDialogExporter"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "Russian"

Section "Install" SEC01
    SetShellVarContext current
    SetOutPath "$INSTDIR"
    File /oname=source.zip "source.zip"
    File /oname=install_runtime.ps1 "install_runtime.ps1"

    DetailPrint "Installing VK Dialog Exporter runtime..."
    nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\install_runtime.ps1" -InstallDir "$INSTDIR"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Installation failed (code $0). Check the installer log/details and your internet connection."
        Abort
    ${EndIf}

    Delete "$INSTDIR\install_runtime.ps1"
    Delete "$INSTDIR\source.zip"

    SetOutPath "$INSTDIR\vk-dialog-exporter"
    CreateDirectory "$SMPROGRAMS\VK Dialog Exporter"
    CreateShortCut "$SMPROGRAMS\VK Dialog Exporter\VK Dialog Exporter.lnk" "$INSTDIR\vk-dialog-exporter\.venv\Scripts\pythonw.exe" '"$INSTDIR\vk-dialog-exporter\launcher.py"' "$INSTDIR\vk-dialog-exporter\.venv\Scripts\pythonw.exe" 0
    CreateShortCut "$DESKTOP\VK Dialog Exporter.lnk" "$INSTDIR\vk-dialog-exporter\.venv\Scripts\pythonw.exe" '"$INSTDIR\vk-dialog-exporter\launcher.py"' "$INSTDIR\vk-dialog-exporter\.venv\Scripts\pythonw.exe" 0

    WriteUninstaller "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VKDialogExporter" "DisplayName" "VK Dialog Exporter"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VKDialogExporter" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VKDialogExporter" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VKDialogExporter" "Publisher" "VK Dialog Exporter"

    Exec '"$INSTDIR\vk-dialog-exporter\.venv\Scripts\pythonw.exe" "$INSTDIR\vk-dialog-exporter\launcher.py"'
SectionEnd

Section "Uninstall"
    SetShellVarContext current
    Delete "$DESKTOP\VK Dialog Exporter.lnk"
    Delete "$SMPROGRAMS\VK Dialog Exporter\VK Dialog Exporter.lnk"
    RMDir "$SMPROGRAMS\VK Dialog Exporter"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VKDialogExporter"
    RMDir /r "$INSTDIR"
SectionEnd
