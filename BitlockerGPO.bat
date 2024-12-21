@echo off
setlocal
TIMEOUT /T 11 /NOBREAK

:CheckBitlocker
echo ========================
echo =Checking for Bitlocker=
echo ========================


for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Encryption Method:"') do (
	if "%%A"=="128" goto Decrypt
	)


for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Encryption Method:"') do (
	if "%%A"=="None" goto CheckTPM
	)


for /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Encryption Method:"') do (
	if "%%A"=="XTS-AES" goto Decrypt
	)

for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Encryption Method:"') do (
	if "%%A"=="256" goto EncryptionCompleted
	)


Goto Exit



:CheckTPM

for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
	if "%%A"=="TRUE" goto CheckTPM2
	)

Goto TPMFailure

:CheckTPM2

for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
	if "%%A"=="TRUE" goto StartTPM
	)

:TPMFailure

echo ===============================================================
echo =The System Volume Encryption on Drive (%systemDrive%) failed.=
echo =The problem could be the TPM Chip is off in the BIOS.        =
echo =Check the TPM status Below                                   =
echo ===============================================================

Powershell Get-TPM

Goto Exit

:StartTPM
powershell Initialize-Tpm

Goto AdBackUp


:Decrypt
echo ======================
echo =Decrypting Bitlocker=
echo ======================

manage-bde %systemDrive% -off

:Wait
Timeout /t 1200

for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Conversion"') do (
	if "%%A"=="Decrypted" goto CheckBitlocker
	)

for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Conversion"') do (
	if "%%A"=="Decryption" goto wait
	)

Goto Exit





:AdBackUp
echo ===============================================================
echo =Backing up Bitlocker Recovery Infromation to Active Directory=
echo ===============================================================

manage-bde -protectors -delete %systemdrive% -type RecoveryPassword
manage-bde -protectors -add %systemdrive% -RecoveryPassword
for /F "tokens=2 delims=: " %%A in ('manage-bde -protectors -get %systemdrive% -type recoverypassword ^| findstr "ID:"') do (
	echo %%A
	manage-bde -protectors -adbackup %systemdrive% -id %%A
	)

TIMEOUT /T 3 /NOBREAK



:Encrypt
echo ===========================
echo =Encrypting with BitLocker=
echo ===========================

manage-bde -protectors -enable %systemdrive%
manage-bde -on %SystemDrive% -EncryptionMethod AES256 -SkipHardwareTest

:Wait2
TIMEOUT /T 60 /NOBREAK

for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Conversion"') do (
	if "%%A"=="Encryption" goto EncryptionCompleted
	)

for /F "tokens=4 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "Conversion"') do (
	if "%%A"=="Encrypted" goto EncryptionCompleted
	)

Goto Wait2
Goto Exit






:EncryptionCompleted
echo ======================================================
echo = It appears the system drive(%SystemDrive%) is                 =
echo = already encrypted or its in progress. See the Drive=
echo = Protection Status below.                           =
echo ======================================================
Powershell Get-BitlockerVolume
TIMEOUT /T 30 /NOBREAK

:exit
endlocal
exit











