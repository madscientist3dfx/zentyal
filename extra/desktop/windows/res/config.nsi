; Script generated by the HM NIS Edit Script Wizard.

; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "Zentyal Desktop"
!define PRODUCT_VERSION "0.2"
!define PRODUCT_PUBLISHER "eBox Technologies S.L."
!define PRODUCT_WEB_SITE "http://www.zentyal.com"
!define PRODUCT_DIR_REGKEY "Software\Zentyal\${PRODUCT_NAME}"
!define PRODUCT_UNINST_KEY "Software\Zentyal\${PRODUCT_NAME}\Uninstall\"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; MUI 1.67 compatible ------
!include "MUI.nsh"
!include nsDialogs.nsh
!include LogicLib.nsh

!define MUI_ABORTWARNING
!define MUI_ICON "zentyal.ico"

!insertmacro MUI_LANGUAGE "English"
; MUI end ------
Page custom nsDialogsPage nsDialogsPageLeave
Page instfiles

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "zentyal-desktop-config.exe"
InstallDir "$PROGRAMFILES\Zentyal Desktop"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""

Var Dialog
Var Label
Var Text

Function nsDialogsPage
         ReadRegStr $0 HKLM "${PRODUCT_DIR_REGKEY}" "SERVER"

	nsDialogs::Create 1018
	Pop $Dialog

	${If} $Dialog == error
		Abort
	${EndIf}

	${NSD_CreateLabel} 0 0 100% 12u "Enter Zentyal Server address:"
	Pop $Label

	${NSD_CreateText} 0 10u 100% 15u $0
	Pop $Text

	nsDialogs::Show
FunctionEnd

Function nsDialogsPageLeave
	${NSD_GetText} $Text $0
        WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "SERVER" "$0"
        MessageBox MB_OK "Server configuration changed"
        Quit
FunctionEnd

Section
        DetailPrint "Server address stored"
SectionEnd
