; Per-user Windows installer for Jotta Text; no administrator access is needed.
; tools/package-windows-installer.py copies this script next to the generated
; install-files.nsh and uninstall-files.nsh lists and defines VERSION, OUTFILE
; and SIZE_KB. Settings stay in %APPDATA%\JottaText, outside the install folder,
; so upgrades and uninstalls keep them unless the user asks otherwise.
Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user

!define APP_NAME "Jotta Text"
!define APP_EXE "JottaText.exe"
!define PUBLISHER "João Jotta"
!define WEBSITE "https://github.com/joaojotta/Jotta-Text"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\JottaText"
!define SETTINGS_KEY "Software\JottaText"
!define SETTINGS_DIR "$APPDATA\JottaText"

Name "${APP_NAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "${SETTINGS_KEY}" "InstallDir"
BrandingText "${APP_NAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIFileVersion "${VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey /LANG=1033 "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "GPL-2.0"

!include MUI2.nsh
!include LogicLib.nsh
!include WinVer.nsh
!include x64.nsh

!define MUI_ICON "app.ico"
!define MUI_UNICON "app.ico"
!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_NODESC

!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_COMPONENTS
!insertmacro MUI_UNPAGE_INSTFILES

; The first language is the fallback; Portuguese is chosen on Portuguese systems.
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Portuguese"

LangString SEC_APP ${LANG_ENGLISH} "Jotta Text (required)"
LangString SEC_APP ${LANG_PORTUGUESE} "Jotta Text (obrigatório)"
LangString SEC_START_MENU ${LANG_ENGLISH} "Start menu shortcut"
LangString SEC_START_MENU ${LANG_PORTUGUESE} "Atalho no menu Iniciar"
LangString SEC_DESKTOP ${LANG_ENGLISH} "Desktop shortcut"
LangString SEC_DESKTOP ${LANG_PORTUGUESE} "Atalho no ambiente de trabalho"
LangString SEC_SETTINGS ${LANG_ENGLISH} "Settings and unsaved recovered documents"
LangString SEC_SETTINGS ${LANG_PORTUGUESE} "Definições e documentos recuperados não guardados"
LangString NEEDS_WINDOWS ${LANG_ENGLISH} "Jotta Text requires 64-bit Windows 10 or later."
LangString NEEDS_WINDOWS ${LANG_PORTUGUESE} "O Jotta Text requer o Windows 10 de 64 bits ou posterior."
LangString REMOVING_PREVIOUS ${LANG_ENGLISH} "Removing the previous version…"
LangString REMOVING_PREVIOUS ${LANG_PORTUGUESE} "A remover a versão anterior…"

Function .onInit
  ${IfNot} ${RunningX64}
  ${OrIfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "$(NEEDS_WINDOWS)" /SD IDOK
    Abort
  ${EndIf}
FunctionEnd

; Run the previous version's own uninstaller first, so files that this version
; no longer ships do not linger. It keeps settings: silent mode skips the
; optional settings section.
Function RemovePrevious
  ReadRegStr $0 HKCU "${UNINSTALL_KEY}" "InstallLocation"
  ${If} $0 != ""
  ${AndIf} ${FileExists} "$0\Uninstall.exe"
    DetailPrint "$(REMOVING_PREVIOUS)"
    ExecWait '"$0\Uninstall.exe" /S _?=$0'
    Delete "$0\Uninstall.exe"
    RMDir "$0"
  ${EndIf}
FunctionEnd

; Start in the install folder, like a double-click on JottaText.exe.
Function LaunchApp
  SetOutPath "$INSTDIR"
  Exec '"$INSTDIR\${APP_EXE}"'
FunctionEnd

Section "$(SEC_APP)" SecApp
  SectionIn RO
  Call RemovePrevious
  !include "install-files.nsh"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${SETTINGS_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "${WEBSITE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" ${SIZE_KB}
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

; Shortcuts start in the install folder (the current SetOutPath).
Section "$(SEC_START_MENU)" SecStartMenu
  SetOutPath "$INSTDIR"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

Section /o "$(SEC_DESKTOP)" SecDesktop
  SetOutPath "$INSTDIR"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

; Deletes only the files this version installed, never the folder recursively,
; so choosing an existing folder as the install location cannot lose other files.
Section "un.$(SEC_APP)" UnSecApp
  SectionIn RO
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  !include "uninstall-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "${SETTINGS_KEY}"
SectionEnd

Section /o "un.$(SEC_SETTINGS)" UnSecSettings
  RMDir /r "${SETTINGS_DIR}"
SectionEnd
