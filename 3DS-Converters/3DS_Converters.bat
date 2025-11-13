@echo off
cd /d "%~dp0"
setlocal EnableDelayedExpansion

mode con: cols=70 lines=40
color 0F

:: ============================================================================
:: VERSION INFO
:: ============================================================================
set "Version=v1.1"
set "ReleaseDate=2025-01-12"
set "BuildNumber=110"

title 3DS ROM Manager Suite %Version%

:: ============================================================================
:: TIMESTAMP GENERATION
:: ============================================================================
set "timestamp="

:: Try PowerShell first (works on Windows 10/11)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'" 2^>nul`) do set "timestamp=%%i"

if defined timestamp (
    set "LogFile=log\operations_%timestamp:~0,8%.log"
) else (
    :: Fallback to date/time parsing
    set "timestamp=%date:~-4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "timestamp=%timestamp: =0%"
    set "LogFile=log\operations_%timestamp:~0,8%.log"
)

:: ============================================================================
:: STATISTICS
:: ============================================================================
set "totalSuccess=0"
set "totalFailed=0"
set "totalSkipped=0"
set "sessionStartTime=%time%"
set "totalBytesProcessed=0"
set "largestFile=0"
set "largestFileName="

:: ============================================================================
:: TOOL DETECTION
:: ============================================================================
set "hasDecryptor=0"
set "has3dsconv=0"
set "hasZ3dsCompressor=0"
set "hasCtrtool=0"

if exist "Batch CIA 3DS Decryptor Redux.bat" set "hasDecryptor=1"
if exist "bin\3dsconv.exe" set "has3dsconv=1"
if exist "bin\z3ds_compressor.exe" set "hasZ3dsCompressor=1"
if exist "bin\ctrtool.exe" set "hasCtrtool=1"

:: ============================================================================
:: SETUP
:: ============================================================================
if not exist "log" mkdir "log"
if not exist "bin" mkdir "bin"

:: Initialize log - FIXED: Use regular variables first, then delayed expansion
if not exist "%LogFile%" (
    echo 3DS ROM Manager Suite %Version% > "%LogFile%"
    echo Build: %BuildNumber% >> "%LogFile%"
    echo [i] = Information >> "%LogFile%"
    echo [^^!] = Error >> "%LogFile%"
    echo [~] = Warning >> "%LogFile%"
    echo. >> "%LogFile%"
    echo Log Created: %date% %time% >> "%LogFile%"
    echo. >> "%LogFile%"
)

echo %date% - %time:~0,-3% = [i] Session Started (%Version% Build %BuildNumber%) >> "%LogFile%"

:: Check required tools
if not exist "bin\makerom.exe" goto :missingTools
if "%hasCtrtool%"=="0" goto :missingTools
if "%has3dsconv%"=="0" goto :missing3dsconv

:: REMOVED: call :checkToolVersions - this was causing crashes

goto menu

:: ============================================================================
:: Check Tool Versions
:: ============================================================================
:checkToolVersions
echo %date% - %time:~0,-3% = [i] Tool check started >> "%LogFile%"

:: Check makerom - simplified to avoid crashes
if exist "bin\makerom.exe" (
    echo %date% - %time:~0,-3% = [i] makerom.exe found >> "%LogFile%"
)

:: Check ctrtool
if exist "bin\ctrtool.exe" (
    echo %date% - %time:~0,-3% = [i] ctrtool.exe found >> "%LogFile%"
)

:: Check 3dsconv
if exist "bin\3dsconv.exe" (
    echo %date% - %time:~0,-3% = [i] 3dsconv.exe found >> "%LogFile%"
)

:: Check decrypt
if exist "bin\decrypt.exe" (
    echo %date% - %time:~0,-3% = [i] decrypt.exe found >> "%LogFile%"
)

:: Check Decryptor Redux
if exist "Batch CIA 3DS Decryptor Redux.bat" (
    echo %date% - %time:~0,-3% = [i] Decryptor Redux found >> "%LogFile%"
)

goto :eof

:: ============================================================================
:: Progress Bar
:: ============================================================================
:showProgress
set "current=%~1"
set "total=%~2"
set "filename=%~3"

if %total% EQU 0 set "total=1"

set /a percent=(current*100)/total
set /a filled=(percent*30)/100

set "bar="
for /L %%i in (1,1,30) do (
    if %%i LEQ !filled! (
        set "bar=!bar!="
    ) else (
        set "bar=!bar! "
    )
)

echo  ================================================================
echo  Progress: [!bar!] !percent!%%
echo  File !current! of !total!: !filename!
echo  ================================================================
echo.
goto :eof

:: ============================================================================
:: Input Sanitization (Enhanced)
:: ============================================================================
:sanitizeInput
set "input=%~1"
set "isSafe=1"

:: Check for dangerous characters
echo "%input%" | findstr /R "[&|<>^!]" >nul && set "isSafe=0"
echo "%input%" | findstr /C:";;" >nul && set "isSafe=0"
echo "%input%" | findstr /C:"&&" >nul && set "isSafe=0"

:: Path traversal check
call :validatePath "%input%"
if "%pathValid%"=="0" set "isSafe=0"

if "%isSafe%"=="0" (
    echo.
    echo [ERROR] Invalid or unsafe input detected
    echo         Only standard filenames in current directory are allowed
    echo.
    set "sanitizeResult=FAIL"
) else (
    set "sanitizeResult=OK"
)
goto :eof

:: ============================================================================
:: Validate Path (Security)
:: ============================================================================
:validatePath
set "pathToCheck=%~1"
set "pathValid=1"

:: Check for directory traversal
echo "%pathToCheck%" | findstr /C:".." >nul && set "pathValid=0"
echo "%pathToCheck%" | findstr /C:"~" >nul && set "pathValid=0"

:: Check for absolute paths
echo "%pathToCheck%" | findstr /R "^[A-Za-z]:" >nul && set "pathValid=0"

:: Check for UNC paths
echo "%pathToCheck%" | findstr /R "^\\\\" >nul && set "pathValid=0"

if "%pathValid%"=="0" (
    echo %date% - %time:~0,-3% = [^^!] Path validation failed: %pathToCheck% >> "!LogFile!"
)

goto :eof

:: ============================================================================
:: Check If File Is Encrypted
:: ============================================================================
:checkEncrypted
set "checkFile=%~1"
set "isEncrypted=2"

if "%hasCtrtool%"=="0" goto :eof

:: Use ctrtool to check encryption
bin\ctrtool.exe --seeddb=bin\seeddb.bin "%checkFile%" > "bin\temp_check.txt" 2>&1

if errorlevel 1 (
    if exist "bin\temp_check.txt" del "bin\temp_check.txt" >nul 2>&1
    set "isEncrypted=2"
    goto :eof
)

:: FIX: Use same detection as Decryptor Redux v1.1
:: Check for "Crypto key:             0x00" (decrypted)
findstr /c:"Crypto key:             0x00" "bin\temp_check.txt" >nul 2>&1
if !errorlevel!==0 (
    set "isEncrypted=0"
    if exist "bin\temp_check.txt" del "bin\temp_check.txt" >nul 2>&1
    goto :eof
)

:: Check for "Secure" (encrypted)
findstr /c:"Crypto key:" "bin\temp_check.txt" | findstr "Secure" >nul 2>&1
if !errorlevel!==0 (
    set "isEncrypted=1"
    if exist "bin\temp_check.txt" del "bin\temp_check.txt" >nul 2>&1
    goto :eof
)

:: Default to decrypted if no clear indicators
set "isEncrypted=0"
if exist "bin\temp_check.txt" del "bin\temp_check.txt" >nul 2>&1
goto :eof

:: ============================================================================
:: Verify Output File
:: ============================================================================
:verifyOutput
set "outputFile=%~1"
set "verifyResult=UNKNOWN"

if not exist "%outputFile%" (
    set "verifyResult=NOTFOUND"
    goto :eof
)

:: Check file size
for %%f in ("%outputFile%") do set "fileSize=%%~zf"
if %fileSize% LSS 1024 (
    set "verifyResult=TOOSMALL"
    echo %date% - %time:~0,-3% = [~] Suspicious file size: %fileSize% bytes >> "!LogFile!"
    goto :eof
)

:: Use ctrtool for validation
if "%hasCtrtool%"=="1" (
    bin\ctrtool.exe --info "%outputFile%" >bin\verify_temp.txt 2>&1
    
    findstr /i "ERROR" bin\verify_temp.txt >nul 2>&1
    if !errorlevel!==0 (
        set "verifyResult=INVALID"
        echo %date% - %time:~0,-3% = [^^!] File structure invalid >> "!LogFile!"
        del bin\verify_temp.txt >nul 2>&1
        goto :eof
    )
    
    findstr /c:"NCCH" bin\verify_temp.txt >nul 2>&1
    if !errorlevel!==0 (
        set "verifyResult=VALID"
    ) else (
        set "verifyResult=WARN"
    )
    
    del bin\verify_temp.txt >nul 2>&1
) else (
    set "verifyResult=BASIC"
)

goto :eof

:: ============================================================================
:: Show Error With Context
:: ============================================================================
:showError
set "errorType=%~1"
set "errorFile=%~2"

echo.
echo ================================================================
echo   ERROR OCCURRED
echo ================================================================
echo.
echo File: %errorFile%
echo.

if "%errorType%"=="DECRYPT" (
    echo Type: Decryption Failure
    echo.
    echo Possible Causes:
    echo   1. File is corrupted or incomplete
    echo   2. Missing seeddb.bin for post-2015 games
    echo   3. File is not actually encrypted
    echo.
    echo Solutions:
    echo   ^> Download seeddb.bin from GitHub
    echo   ^> Verify file integrity
    echo   ^> Try manual decryption
)

if "%errorType%"=="CONVERT_CIA" (
    echo Type: CIA Conversion Failure
    echo.
    echo Possible Causes:
    echo   1. File is still encrypted
    echo   2. DLC/Update titles don't support CCI
    echo   3. Insufficient disk space
    echo.
    echo Solutions:
    echo   ^> Use Option 3 to decrypt first
    echo   ^> Check available disk space
    echo   ^> Verify title type compatibility
)

if "%errorType%"=="CONVERT_CCI" (
    echo Type: CCI Conversion Failure
    echo.
    echo Possible Causes:
    echo   1. File format incompatible
    echo   2. Corrupted source file
    echo   3. Insufficient disk space
    echo.
    echo Solutions:
    echo   ^> Check available disk space
    echo   ^> Verify file integrity
    echo   ^> Update 3dsconv
)

if "%errorType%"=="COMPRESS" (
    echo Type: Z3DS Compression Failure
    echo.
    echo Possible Causes:
    echo   1. Insufficient disk space
    echo   2. Source file corrupted
    echo.
    echo Solutions:
    echo   ^> Free up disk space
    echo   ^> Verify source file
)

echo.
echo ================================================================
echo %date% - %time:~0,-3% = [^^!] Error: %errorType% - %errorFile% >> "!LogFile!"

pause
goto :eof

:: ============================================================================
:: Check If Filename Indicates Decrypted
:: ============================================================================
:isDecryptedFilename
set "checkName=%~1"
set "isDecryptedName=0"

if not "!checkName:-decrypted=!"=="!checkName!" set "isDecryptedName=1"

goto :eof

:: ============================================================================
:: MAIN MENU
:: ============================================================================
:menu
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo   Build !BuildNumber! - !ReleaseDate!
echo ================================================================
echo.
echo  BASIC CONVERSION
echo  ================
echo  1. CCI/3DS to CIA      Cartridge to installable format
echo  2. CIA to CCI          Installable to cartridge format
echo.
if "%hasDecryptor%"=="1" (
    echo  DECRYPTION ^& CONVERSION
    echo  ========================
    echo  3. Decrypt Files       Decrypt encrypted ROMs
    echo  4. Decrypt to CIA      Decrypt and output as CIA
    echo  5. Decrypt to CCI      Decrypt and output as CCI
    echo.
)
if "%hasZ3dsCompressor%"=="1" (
    echo  AZAHAR EMULATOR ^(Z3DS FORMAT^)
    echo  ================================
    echo  6. Compress to Z3DS    Compress ROMs for Azahar
    echo  7. Decompress Z3DS     Extract from Z3DS format
    echo  8. View Z3DS Info      Show compressed file details
    echo.
)
echo  UTILITIES
echo  =========
echo  9. List Files          Show all ROM files in folder
echo  10. Statistics         View session statistics
echo  11. Clean Temp         Remove temporary files
echo  12. Credits            About this tool
echo.
echo  0. Exit
echo.
echo ================================================================
set /p "choice=Enter choice: "

if "%choice%"=="1" goto cciToCia
if "%choice%"=="2" goto ciaToCci
if "%choice%"=="3" goto decrypt
if "%choice%"=="4" goto decryptToCia
if "%choice%"=="5" goto decryptToCci
if "%choice%"=="6" goto compressZ3ds
if "%choice%"=="7" goto decompressZ3ds
if "%choice%"=="8" goto listZ3dsInfo
if "%choice%"=="9" goto listFiles
if "%choice%"=="10" goto stats
if "%choice%"=="11" goto cleanTemp
if "%choice%"=="12" goto credits
if "%choice%"=="0" goto exitScript
goto menu

:: ============================================================================
:: CCI/3DS TO CIA CONVERSION
:: ============================================================================
:cciToCia
set "rom="
set "fileCount=0"
set "decryptedCount=0"
set "opSuccess=0"
set "opFailed=0"
set "opSkipped=0"
set "deleteSource=0"
set "deletedCount=0"

cls
echo ================================================================
echo   CCI/3DS to CIA Conversion
echo   Cartridge to Installable Format
echo ================================================================
echo.

:: Count files
for %%f in (*.cci *.3ds) do (
    set /a fileCount+=1
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    if "!isDecryptedName!"=="1" set /a decryptedCount+=1
)

if !fileCount! EQU 0 (
    echo No CCI/3DS files found.
    echo.
    pause
    goto menu
)

echo Found !fileCount! CCI/3DS file(s)
if !decryptedCount! GTR 0 echo   ^(!decryptedCount! already decrypted^)
echo.
echo Conversion tool: 3dsconv
echo   - Handles encrypted and decrypted files
echo   - Removes firmware version spoofing
echo   - Best compatibility
echo.
echo ================================================================
echo.
echo After conversion, you can delete source files to save space.
echo.
set /p "deletePrompt=Delete source files after conversion? (Y/N): "

if /i "!deletePrompt!"=="Y" (
    set "deleteSource=1"
    echo.
    echo ================================================================
    echo   [^^!] WARNING: Source files will be DELETED after conversion^^!
    echo ================================================================
) else (
    set "deleteSource=0"
    echo.
    echo   Source files will be kept.
)

echo.
set /p "rom=Filename (Enter for all, M to return to menu): "

if /i "%rom%"=="M" goto menu
if not defined rom goto :cciToCia_batch
if "%rom%"=="" goto :cciToCia_batch

call :sanitizeInput "%rom%"
if "%sanitizeResult%"=="FAIL" (
    pause
    goto menu
)

goto :cciToCia_single

:cciToCia_batch
cls
echo ================================================================
echo   Batch Conversion Confirmation
echo ================================================================
echo.
echo About to convert !fileCount! file(s) to CIA format.
echo.
if "!deleteSource!"=="1" (
    echo ================================================================
    echo   [^^!] WARNING: Source files will be DELETED^^!
    echo ================================================================
    echo.
)
set /p "confirm=Press ENTER to continue, or M to return to menu: "

if /i "!confirm!"=="M" goto menu

set "processedCount=0"

for %%f in (*.cci *.3ds) do (
    set "fullname=%%~nxf"
    set "basename=%%~nf"
    set /a processedCount+=1
    
    cls
    echo ================================================================
    echo   CCI/3DS to CIA Conversion
    echo ================================================================
    echo.
    call :showProgress !processedCount! !fileCount! "!fullname!"
    echo.

    if exist "!basename!.cia" (
        echo  [SKIP] !basename!.cia already exists
        set /a totalSkipped+=1
        set /a opSkipped+=1
        timeout /t 1 >nul
    ) else (
        echo  [CONV] Converting: !fullname!
        echo.
        
        bin\3dsconv.exe --no-fw-spoof --overwrite "%%f" 2>nul
        set "convError=!errorlevel!"
        
        echo.
        
        :: Verify output
        if exist "!basename!.cia" (
            call :verifyOutput "!basename!.cia"
            
            if "!verifyResult!"=="VALID" (
                echo  [ OK ] Conversion successful ^(verified^)
                set /a totalSuccess+=1
                set /a opSuccess+=1
            ) else if "!verifyResult!"=="BASIC" (
                echo  [ OK ] Conversion successful
                set /a totalSuccess+=1
                set /a opSuccess+=1
            ) else if "!verifyResult!"=="WARN" (
                echo  [WARN] File created but validation inconclusive
                set /a totalSuccess+=1
                set /a opSuccess+=1
            ) else (
                echo  [FAIL] Verification failed
                del "!basename!.cia" >nul 2>&1
                call :showError "CONVERT_CCI" "!fullname!"
                set /a totalFailed+=1
                set /a opFailed+=1
                timeout /t 2 >nul
                goto :skipDelete_cciToCia
            )
            
            echo %date% - %time:~0,-3% = [i] Converted: !fullname! >> "!LogFile!"
            
            :: Track file size
            for %%s in ("!basename!.cia") do set "fsize=%%~zs"
            set /a totalBytesProcessed+=fsize
            if !fsize! GTR !largestFile! (
                set "largestFile=!fsize!"
                set "largestFileName=!basename!.cia"
            )
            
            :: Delete source if requested
            if "!deleteSource!"=="1" (
                echo  [DEL ] Deleting source: !fullname!
                del "%%f" >nul 2>&1
                if not exist "%%f" (
                    echo  [ OK ] Source deleted
                    echo %date% - %time:~0,-3% = [i] Deleted: !fullname! >> "!LogFile!"
                    set /a deletedCount+=1
                ) else (
                    echo  [WARN] Could not delete source
                )
            )
        ) else (
            echo  [FAIL] Conversion failed
            call :showError "CONVERT_CCI" "!fullname!"
            echo %date% - %time:~0,-3% = [^^!] Failed: !fullname! >> "!LogFile!"
            set /a totalFailed+=1
            set /a opFailed+=1
        )
        
        :skipDelete_cciToCia
        timeout /t 1 >nul
    )
)

goto :cciToCia_results

:cciToCia_single
if not exist "%rom%" (
    echo ERROR: File not found: %rom%
    echo.
    pause
    goto menu
)

for %%f in ("%rom%") do set "basename=%%~nf"

if exist "%basename%.cia" (
    echo [SKIP] %basename%.cia already exists
    set /a totalSkipped+=1
    set /a opSkipped+=1
    goto :cciToCia_results
)

echo.
echo Ready to convert: %rom%
echo.
if "!deleteSource!"=="1" (
    echo ================================================================
    echo   [^^!] WARNING: Source file will be DELETED after conversion^^!
    echo ================================================================
    echo.
)
set /p "confirm=Press ENTER to continue, or M to cancel: "

if /i "!confirm!"=="M" goto menu

echo.
echo  [CONV] Converting: %rom%
echo.

bin\3dsconv.exe --no-fw-spoof --overwrite "%rom%" 2>nul
set "convError=!errorlevel!"

echo.
if exist "%basename%.cia" (
    call :verifyOutput "%basename%.cia"
    
    if "!verifyResult!"=="VALID" (
        echo  [ OK ] %basename%.cia created ^(verified^)
    ) else if "!verifyResult!"=="BASIC" (
        echo  [ OK ] %basename%.cia created
    ) else if "!verifyResult!"=="WARN" (
        echo  [WARN] File created but validation inconclusive
    ) else (
        echo  [FAIL] Verification failed
        del "%basename%.cia" >nul 2>&1
        call :showError "CONVERT_CCI" "%rom%"
        set /a totalFailed+=1
        set /a opFailed+=1
        pause
        goto menu
    )
    
    echo %date% - %time:~0,-3% = [i] Converted %rom% >> "!LogFile!"
    set /a totalSuccess+=1
    set /a opSuccess+=1
    
    :: Track file size
    for %%s in ("%basename%.cia") do set "fsize=%%~zs"
    set /a totalBytesProcessed+=fsize
    if !fsize! GTR !largestFile! (
        set "largestFile=!fsize!"
        set "largestFileName=%basename%.cia"
    )
    
    if "!deleteSource!"=="1" (
        echo.
        echo  [DEL ] Deleting source: %rom%
        del "%rom%" >nul 2>&1
        if not exist "%rom%" (
            echo  [ OK ] Source deleted
            echo %date% - %time:~0,-3% = [i] Deleted: %rom% >> "!LogFile!"
            set /a deletedCount+=1
        ) else (
            echo  [WARN] Could not delete source
        )
    )
) else (
    echo  [FAIL] Conversion failed
    call :showError "CONVERT_CCI" "%rom%"
    echo %date% - %time:~0,-3% = [^^!] Failed %rom% >> "!LogFile!"
    set /a totalFailed+=1
    set /a opFailed+=1
)

goto :cciToCia_results

:cciToCia_results
cls
echo ================================================================
echo   CONVERSION COMPLETE
echo ================================================================
echo.
echo  Success: %opSuccess%  ^|  Failed: %opFailed%  ^|  Skipped: %opSkipped%
if "!deleteSource!"=="1" echo  Deleted: %deletedCount%
echo.
echo ================================================================

if %opSuccess% GTR 0 (
    echo.
    echo  [SUCCESS] %opSuccess% file^(s^) converted to CIA^^!
    echo  Ready to install or use in emulators.
)

if %opFailed% GTR 0 (
    echo.
    echo  [ERROR] %opFailed% file^(s^) failed during conversion
    echo.
    echo  Common causes:
    echo    - File is corrupted or incomplete
    echo    - Not a valid 3DS/CCI file
    echo    - Insufficient disk space
)

if %opSkipped% GTR 0 (
    echo.
    echo  [INFO] %opSkipped% file^(s^) already converted
)

if "!deleteSource!"=="1" if %deletedCount% GTR 0 (
    echo.
    echo  [CLEANUP] %deletedCount% source file^(s^) deleted - space freed^^!
)

echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: CIA TO CCI CONVERSION
:: ============================================================================
:ciaToCci
set "rom="
set "ciaCount=0"
set "opSuccess=0"
set "opFailed=0"
set "opSkipped=0"
set "deleteSource=0"
set "deletedCount=0"

cls
echo ================================================================
echo   CIA to CCI Conversion
echo   Installable to Cartridge Format
echo ================================================================
echo.
echo NOTE: Only works with decrypted CIA files.
echo.

:: Count CIA files
for %%f in (*.cia) do (
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    if "!isDecryptedName!"=="0" set /a ciaCount+=1
)

if !ciaCount! EQU 0 (
    echo No CIA files found.
    echo.
    pause
    goto menu
)

echo Found !ciaCount! CIA file(s)
echo.
echo ================================================================
echo   STORAGE MANAGEMENT
echo ================================================================
echo.
echo After conversion, you can delete source files to save space.
echo.
echo WARNING: Deletion is PERMANENT and cannot be undone^^!
echo          Only successfully converted files will be deleted.
echo.
set /p "deletePrompt=Delete source files after conversion? (Y/N, default=N): "

if /i "!deletePrompt!"=="Y" (
    set "deleteSource=1"
    echo.
    echo [^^!] Source files WILL be deleted after successful conversion
) else (
    set "deleteSource=0"
    echo.
    echo [i] Source files will be kept
)

echo.
echo ================================================================
echo.
set "rom="
set /p "rom=Filename (Enter for all, M to return to menu): "

if /i "%rom%"=="M" goto menu

echo.

if not defined rom goto :ciaToCci_batch
if "%rom%"=="" goto :ciaToCci_batch

call :sanitizeInput "%rom%"
if "%sanitizeResult%"=="FAIL" (
    pause
    goto menu
)

goto :ciaToCci_single

:ciaToCci_batch
echo About to convert !ciaCount! CIA file(s) to CCI format.
if "!deleteSource!"=="1" (
    echo.
    echo WARNING: Source files will be DELETED after conversion^^!
)
echo.
set /p "confirm=Press ENTER to continue, or M to cancel: "

if /i "!confirm!"=="M" goto menu

cls
echo ================================================================
echo   Processing Files...
echo ================================================================
echo.

set "processedCount=0"

for %%f in (*.cia) do (
    set "fname=%%~nf"
    set "fullname=%%~nxf"
    set /a processedCount+=1
    
    cls
    echo ================================================================
    echo   CIA to CCI Conversion
    echo ================================================================
    echo.
    call :showProgress !processedCount! !ciaCount! "!fullname!"
    echo.
    
    if exist "!fname!.cci" (
        echo [SKIP] !fname!.cci exists
        set /a totalSkipped+=1
        set /a opSkipped+=1
        timeout /t 1 >nul
    ) else (
        echo [CONV] Converting: !fullname!
        echo.
        
        bin\makerom.exe -ciatocci "%%f" >nul 2>&1
        set "convError=!errorlevel!"
        
        if exist "!fname!.cci" (
            call :verifyOutput "!fname!.cci"
            
            if "!verifyResult!"=="VALID" (
                echo [ OK ] Conversion successful ^(verified^)
                set /a totalSuccess+=1
                set /a opSuccess+=1
            ) else if "!verifyResult!"=="BASIC" (
                echo [ OK ] Conversion successful
                set /a totalSuccess+=1
                set /a opSuccess+=1
            ) else (
                echo [WARN] File created but validation inconclusive
                set /a totalSuccess+=1
                set /a opSuccess+=1
            )
            
            echo %date% - %time:~0,-3% = [i] Converted !fullname! >> "!LogFile!"
            
            :: Track file size
            for %%s in ("!fname!.cci") do set "fsize=%%~zs"
            set /a totalBytesProcessed+=fsize
            if !fsize! GTR !largestFile! (
                set "largestFile=!fsize!"
                set "largestFileName=!fname!.cci"
            )
            
            if "!deleteSource!"=="1" (
                echo [DEL] Deleting source file: !fullname!
                del "%%f" >nul 2>&1
                if not exist "%%f" (
                    echo [ OK ] Source file deleted
                    echo %date% - %time:~0,-3% = [i] Deleted source: !fullname! >> "!LogFile!"
                    set /a deletedCount+=1
                ) else (
                    echo [WARN] Could not delete source file
                )
            )
        ) else (
            echo [FAIL] Incompatible ^(DLC/Update/Encrypted^)
            echo %date% - %time:~0,-3% = [^^!] Failed !fullname! >> "!LogFile!"
            set /a totalFailed+=1
            set /a opFailed+=1
        )
        timeout /t 1 >nul
    )
)

goto :ciaToCci_results

:ciaToCci_single
if not exist "%rom%" (
    echo ERROR: File not found: %rom%
    echo.
    pause
    goto menu
)

for %%f in ("%rom%") do set "basename=%%~nf"

if exist "%basename%.cci" (
    echo [SKIP] %basename%.cci already exists
    set /a totalSkipped+=1
    set /a opSkipped+=1
    goto :ciaToCci_results
)

echo Ready to convert: %rom%
if "!deleteSource!"=="1" (
    echo.
    echo WARNING: Source file will be DELETED after conversion^^!
)
echo.
set /p "confirm=Press ENTER to continue, or M to cancel: "

if /i "!confirm!"=="M" goto menu

echo.
echo [CONV] %rom%
echo.

bin\makerom.exe -ciatocci "%rom%" >nul 2>&1
set "convError=!errorlevel!"

echo.

if exist "%basename%.cci" (
    call :verifyOutput "%basename%.cci"
    
    if "!verifyResult!"=="VALID" (
        echo [ OK ] %basename%.cci created ^(verified^)
    ) else if "!verifyResult!"=="BASIC" (
        echo [ OK ] %basename%.cci created
    ) else (
        echo [WARN] File created but validation inconclusive
    )
    
    echo %date% - %time:~0,-3% = [i] Converted %rom% >> "!LogFile!"
    set /a totalSuccess+=1
    set /a opSuccess+=1
    
    :: Track file size
    for %%s in ("%basename%.cci") do set "fsize=%%~zs"
    set /a totalBytesProcessed+=fsize
    if !fsize! GTR !largestFile! (
        set "largestFile=!fsize!"
        set "largestFileName=%basename%.cci"
    )
    
    if "!deleteSource!"=="1" (
        echo.
        echo [DEL] Deleting source file: %rom%
        del "%rom%" >nul 2>&1
        if not exist "%rom%" (
            echo [ OK ] Source file deleted
            echo %date% - %time:~0,-3% = [i] Deleted source: %rom% >> "!LogFile!"
            set /a deletedCount+=1
        ) else (
            echo [WARN] Could not delete source file
        )
    )
) else (
    echo [FAIL] Conversion failed
    call :showError "CONVERT_CIA" "%rom%"
    echo %date% - %time:~0,-3% = [^^!] Failed %rom% >> "!LogFile!"
    set /a totalFailed+=1
    set /a opFailed+=1
)

goto :ciaToCci_results

:ciaToCci_results
cls
echo ================================================================
echo   CONVERSION COMPLETE
echo ================================================================
echo.
echo  Success: %opSuccess%  ^|  Failed: %opFailed%  ^|  Skipped: %opSkipped%
if "!deleteSource!"=="1" (
    echo  Deleted: %deletedCount%
)
echo.
echo ================================================================

if %opSuccess% GTR 0 (
    echo.
    echo  [SUCCESS] %opSuccess% file^(s^) converted to CCI^^!
)

if %opFailed% GTR 0 (
    echo.
    echo  [ERROR] %opFailed% file^(s^) failed
    echo  Common reasons: Encrypted, DLC, Update, or System title
)

if %opSkipped% GTR 0 (
    echo.
    echo  [INFO] %opSkipped% file^(s^) already converted
)

if "!deleteSource!"=="1" (
    if %deletedCount% GTR 0 (
        echo.
        echo  [CLEANUP] %deletedCount% source file^(s^) deleted
        echo  Space has been freed on your drive.
    )
)

echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: DECRYPT FILES
:: ============================================================================
:decrypt
if "%hasDecryptor%"=="0" goto :noDecryptor

cls
echo ================================================================
echo   Decrypt Files
echo   Decrypt Encrypted ROMs
echo ================================================================
echo.

:: Count files
set "needDecryption=0"
set "alreadyDecrypted=0"

for %%f in (*.cia *.cci *.3ds) do (
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    
    if "!isDecryptedName!"=="0" (
        call :checkEncrypted "%%f"
        if "!isEncrypted!"=="1" set /a needDecryption+=1
        if "!isEncrypted!"=="0" set /a alreadyDecrypted+=1
    ) else (
        set /a alreadyDecrypted+=1
    )
)

if !needDecryption! EQU 0 (
    echo [INFO] No encrypted files found
    echo.
    if !alreadyDecrypted! GTR 0 (
        echo Found !alreadyDecrypted! already decrypted file^(s^)
    )
    echo.
    pause
    goto menu
)

echo File Analysis:
echo ================================================================
echo   Encrypted files:     !needDecryption!
if !alreadyDecrypted! GTR 0 (
    echo   Already decrypted:   !alreadyDecrypted!
)
echo ================================================================
echo.

:: Count existing decrypted files before operation
set "beforeCountCIA=0"
set "beforeCountCCI=0"
for %%f in (*-decrypted.cia) do set /a beforeCountCIA+=1
for %%f in (*-decrypted.cci) do set /a beforeCountCCI+=1

echo Launching Batch CIA 3DS Decryptor Redux...
echo.
echo NOTE: If the decryptor exits immediately, there may be
echo no encrypted files or the files are already decrypted.
echo.
echo ================================================================
echo.
set /p "confirm=Press ENTER to continue, or M to return to menu: "

if /i "!confirm!"=="M" goto menu

call "Batch CIA 3DS Decryptor Redux.bat"

:: Count decrypted files after operation
set "afterCountCIA=0"
set "afterCountCCI=0"
for %%f in (*-decrypted.cia) do set /a afterCountCIA+=1
for %%f in (*-decrypted.cci) do set /a afterCountCCI+=1

set /a newCIA=afterCountCIA-beforeCountCIA
set /a newCCI=afterCountCCI-beforeCountCCI
set /a newTotal=newCIA+newCCI

cls
echo ================================================================
echo   DECRYPTION RESULTS
echo ================================================================
echo.

if %newTotal% GTR 0 (
    echo Operation Summary:
    if %newCIA% GTR 0 echo   - %newCIA% file^(s^) decrypted to CIA
    if %newCCI% GTR 0 echo   - %newCCI% file^(s^) decrypted to CCI
    echo.
    echo [SUCCESS] %newTotal% file^(s^) decrypted^^!
) else (
    echo [INFO] No new files created
    echo.
    echo This could mean:
    echo   - Files are already decrypted
    echo   - No encrypted files were found
    echo   - Decryption was cancelled
)

echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: DECRYPT TO CIA
:: ============================================================================
:decryptToCia
if "%hasDecryptor%"=="0" goto :noDecryptor

cls
echo ================================================================
echo   Decrypt to CIA
echo   Decrypt and Output as CIA Format
echo ================================================================
echo.

:: Pre-check for files
set "hasFiles=0"
for %%f in (*.cia *.cci *.3ds) do (
    set "hasFiles=1"
    goto :foundFiles_CIA
)
:foundFiles_CIA

if "%hasFiles%"=="0" (
    echo [ERROR] No ROM files found to decrypt
    echo.
    echo This tool looks for: .cia, .cci, .3ds files
    echo.
    pause
    goto menu
)

echo This will decrypt all encrypted files to CIA format.
echo.
echo ================================================================
echo.
set /p "confirm=Continue? (Y to proceed, M to return to menu): "

if /i "!confirm!"=="M" goto menu
if /i not "!confirm!"=="Y" goto menu

echo.
echo Starting decrypt to CIA...
echo.
echo NOTE: If the decryptor exits immediately, there may be
echo no encrypted files or the files are already decrypted.
echo.
pause

call "Batch CIA 3DS Decryptor Redux.bat" AUTO CIA

echo.
echo Decryptor finished.
echo.
pause
goto menu

:: ============================================================================
:: DECRYPT TO CCI
:: ============================================================================
:decryptToCci
if "%hasDecryptor%"=="0" goto :noDecryptor

cls
echo ================================================================
echo   Decrypt to CCI
echo   Decrypt and Output as CCI Format
echo ================================================================
echo.

:: Pre-check for files
set "hasFiles=0"
for %%f in (*.cia *.cci *.3ds) do (
    set "hasFiles=1"
    goto :foundFiles_CCI
)
:foundFiles_CCI

if "%hasFiles%"=="0" (
    echo [ERROR] No ROM files found to decrypt
    echo.
    echo This tool looks for: .cia, .cci, .3ds files
    echo.
    pause
    goto menu
)

echo This will decrypt all encrypted files to CCI format.
echo.
echo ================================================================
echo.
set /p "confirm=Continue? (Y to proceed, M to return to menu): "

if /i "!confirm!"=="M" goto menu
if /i not "!confirm!"=="Y" goto menu

echo.
echo Starting decrypt to CCI...
echo.
echo NOTE: If the decryptor exits immediately, there may be
echo no encrypted files or the files are already decrypted.
echo.
pause

call "Batch CIA 3DS Decryptor Redux.bat" AUTO CCI

echo.
echo Decryptor finished.
echo.
pause
goto menu

:: ============================================================================
:: COMPRESS TO Z3DS FORMAT
:: ============================================================================
:compressZ3ds
if "%hasZ3dsCompressor%"=="0" goto :noCompressor

set "opSuccess=0"
set "opFailed=0"
set "opSkipped=0"
set "deleteSource=0"
set "deletedCount=0"

cls
echo ================================================================
echo   Compress to Z3DS Format
echo   Compress for Azahar Emulator
echo ================================================================
echo.

:: Count files by type
set "count3ds=0"
set "countCci=0"
set "countCia=0"
set "totalCount=0"

for %%f in (*.3ds) do (
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    if "!isDecryptedName!"=="0" set /a count3ds+=1
)

for %%f in (*.cci) do (
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    if "!isDecryptedName!"=="0" set /a countCci+=1
)

for %%f in (*.cia) do (
    set "fname=%%~nf"
    call :isDecryptedFilename "!fname!"
    if "!isDecryptedName!"=="0" set /a countCia+=1
)

set /a totalCount=count3ds+countCci+countCia

if %totalCount% EQU 0 (
    echo No files found to compress.
    echo.
    echo Supported: .3ds, .cci, .cia
    echo Note: Skips *-decrypted.* files
    echo.
    pause
    goto menu
)

:: Display file type counts
echo File Type Detection:
echo ================================================================
if %count3ds% GTR 0 echo   [1] .3DS files:  %count3ds% found  ^(outputs .z3ds^)
if %countCci% GTR 0 echo   [2] .CCI files:  %countCci% found  ^(outputs .zcci^)
if %countCia% GTR 0 echo   [3] .CIA files:  %countCia% found  ^(outputs .zcia^)
echo.
echo   [4] All types:   %totalCount% total files
echo ================================================================
echo.

:: Let user choose file type
set "fileTypeChoice="
set /p "fileTypeChoice=Select file type (1-4, M for menu, Enter=4): "

if /i "%fileTypeChoice%"=="M" goto menu
if not defined fileTypeChoice set "fileTypeChoice=4"
if "%fileTypeChoice%"=="" set "fileTypeChoice=4"

:: Validate choice and set file pattern
set "selectedPattern="
set "selectedName="
set "fileCount=0"

if "%fileTypeChoice%"=="1" (
    if %count3ds% EQU 0 (
        echo.
        echo [ERROR] No .3DS files available to compress
        echo.
        pause
        goto menu
    )
    set "selectedPattern=*.3ds"
    set "selectedName=3DS"
    set "fileCount=%count3ds%"
) else if "%fileTypeChoice%"=="2" (
    if %countCci% EQU 0 (
        echo.
        echo [ERROR] No .CCI files available to compress
        echo.
        pause
        goto menu
    )
    set "selectedPattern=*.cci"
    set "selectedName=CCI"
    set "fileCount=%countCci%"
) else if "%fileTypeChoice%"=="3" (
    if %countCia% EQU 0 (
        echo.
        echo [ERROR] No .CIA files available to compress
        echo.
        pause
        goto menu
    )
    set "selectedPattern=*.cia"
    set "selectedName=CIA"
    set "fileCount=%countCia%"
) else if "%fileTypeChoice%"=="4" (
    set "selectedPattern=*.3ds *.cci *.cia"
    set "selectedName=All Types"
    set "fileCount=%totalCount%"
) else (
    echo.
    echo [ERROR] Invalid choice
    echo.
    pause
    goto menu
)

echo.
echo Selected: %selectedName% ^(%fileCount% file^(s^)^)
echo.

:: Ask for compression level
echo Compression level:
echo   [1] Fast      - Level 1 (fastest, larger files)
echo   [2] Balanced  - Level 3 (default, recommended)
echo   [3] Best      - Level 9 (slower, smallest files)
echo   [M] Return to menu
echo.
set /p "compLevel=Choice (1-3, M for menu, Enter=2): "

if /i "%compLevel%"=="M" goto menu
if not defined compLevel set "compLevel=2"
if "%compLevel%"=="" set "compLevel=2"

set "levelArg="
if "%compLevel%"=="1" set "levelArg=-1"
if "%compLevel%"=="2" set "levelArg=-3"
if "%compLevel%"=="3" set "levelArg=-9"

:: Display compression level
if "%compLevel%"=="1" set "levelName=Fast ^(Level 1^)"
if "%compLevel%"=="2" set "levelName=Balanced ^(Level 3^)"
if "%compLevel%"=="3" set "levelName=Best ^(Level 9^)"

echo.
echo Compression: %levelName%
echo.
echo ================================================================
echo   STORAGE MANAGEMENT
echo ================================================================
echo.
echo After compression, you can delete source files to save space.
echo.
set /p "deletePrompt=Delete source files after compression? (Y/N): "

if /i "!deletePrompt!"=="Y" (
    set "deleteSource=1"
    echo.
    echo ================================================================
    echo   [^^!] WARNING: Source files will be DELETED after compression^^!
    echo ================================================================
) else (
    set "deleteSource=0"
    echo.
    echo   Source files will be kept.
)

echo.
set /p "rom=Specific filename (Enter for all, M for menu): "

if /i "%rom%"=="M" goto menu

echo.

if not defined rom goto :compressZ3ds_batch
if "%rom%"=="" goto :compressZ3ds_batch

call :sanitizeInput "%rom%"
if "%sanitizeResult%"=="FAIL" (
    pause
    goto menu
)

goto :compressZ3ds_single

:compressZ3ds_batch
set "currentFile=0"

:: Process files matching selected pattern
for %%f in (%selectedPattern%) do (
    set "fullname=%%~nxf"
    set "basename=%%~nf"
    set "ext=%%~xf"
    
    :: Skip decrypted files
    call :isDecryptedFilename "!basename!"
    if "!isDecryptedName!"=="0" (
        :: Determine expected output file
        set "expectedOutput="
        if /i "!ext!"==".3ds" set "expectedOutput=!basename!.z3ds"
        if /i "!ext!"==".cci" set "expectedOutput=!basename!.zcci"
        if /i "!ext!"==".cia" set "expectedOutput=!basename!.zcia"
        
        if defined expectedOutput (
            set /a currentFile+=1
            
            cls
            echo ================================================================
            echo   Compress to Z3DS Format
            echo   Compression: %levelName%
            echo ================================================================
            echo.
            call :showProgress !currentFile! !fileCount! "!fullname!"
            echo.
            
            if exist "!expectedOutput!" (
                echo  [SKIP] Already compressed
                set /a totalSkipped+=1
                set /a opSkipped+=1
                timeout /t 1 >nul
            ) else (
                echo  [COMP] Compressing to: !expectedOutput!
                echo  Please wait...
                echo.
                
                "bin\z3ds_compressor.exe" %levelArg% "%%f" >nul 2>&1
                set "compError=!errorlevel!"
                
                if exist "!expectedOutput!" (
                    if "!compError!"=="0" (
                        echo  [ OK ] Compression successful
                        echo %date% - %time:~0,-3% = [i] Compressed %%f >> "!LogFile!"
                        set /a totalSuccess+=1
                        set /a opSuccess+=1
                        
                        :: Track file size
                        for %%s in ("!expectedOutput!") do set "fsize=%%~zs"
                        set /a totalBytesProcessed+=fsize
                        if !fsize! GTR !largestFile! (
                            set "largestFile=!fsize!"
                            set "largestFileName=!expectedOutput!"
                        )
                        
                        if "!deleteSource!"=="1" (
                            echo  [DEL ] Deleting source file
                            del "%%f" >nul 2>&1
                            if not exist "%%f" (
                                echo  [ OK ] Source file deleted
                                echo %date% - %time:~0,-3% = [i] Deleted: !fullname! >> "!LogFile!"
                                set /a deletedCount+=1
                            ) else (
                                echo  [WARN] Could not delete source file
                            )
                        )
                    ) else (
                        echo  [WARN] File created but tool reported error
                        echo %date% - %time:~0,-3% = [~] Warning %%f >> "!LogFile!"
                        set /a totalSuccess+=1
                        set /a opSuccess+=1
                    )
                ) else (
                    echo  [FAIL] Compression failed
                    call :showError "COMPRESS" "!fullname!"
                    echo %date% - %time:~0,-3% = [^^!] Failed %%f >> "!LogFile!"
                    set /a totalFailed+=1
                    set /a opFailed+=1
                )
                timeout /t 1 >nul
            )
        )
    )
)

goto :compressZ3ds_results

:compressZ3ds_single
if not exist "%rom%" (
    echo ERROR: File not found: %rom%
    echo.
    pause
    goto menu
)

for %%f in ("%rom%") do (
    set "basename=%%~nf"
    set "ext=%%~xf"
)

:: Determine expected output
set "expectedOutput="
if /i "%ext%"==".3ds" set "expectedOutput=%basename%.z3ds"
if /i "%ext%"==".cci" set "expectedOutput=%basename%.zcci"
if /i "%ext%"==".cia" set "expectedOutput=%basename%.zcia"

if not defined expectedOutput (
    echo [ERROR] Unsupported file type: %ext%
    echo.
    echo Supported: .3ds, .cci, .cia
    echo.
    pause
    goto menu
)

if exist "%expectedOutput%" (
    echo [SKIP] Already compressed: %expectedOutput%
    set /a totalSkipped+=1
    set /a opSkipped+=1
    goto :compressZ3ds_results
)

echo Processing: %rom%
echo Output:     %expectedOutput%
if "!deleteSource!"=="1" (
    echo.
    echo WARNING: Source file will be DELETED after compression^^!
)
echo.

echo  [COMP] Compressing: %rom%
echo  Please wait...
echo.
"bin\z3ds_compressor.exe" %levelArg% "%rom%" >nul 2>&1
set "compError=!errorlevel!"

echo.

if exist "%expectedOutput%" (
    if "!compError!"=="0" (
        echo [ OK ] Compression successful
        echo %date% - %time:~0,-3% = [i] Compressed %rom% ^> %expectedOutput% >> "!LogFile!"
        set /a totalSuccess+=1
        set /a opSuccess+=1
        
        :: Track file size
        for %%s in ("%expectedOutput%") do set "fsize=%%~zs"
        set /a totalBytesProcessed+=fsize
        if !fsize! GTR !largestFile! (
            set "largestFile=!fsize!"
            set "largestFileName=%expectedOutput%"
        )
        
        if "!deleteSource!"=="1" (
            echo.
            echo [DEL] Deleting source file: %rom%
            del "%rom%" >nul 2>&1
            if not exist "%rom%" (
                echo [ OK ] Source file deleted
                echo %date% - %time:~0,-3% = [i] Deleted source: %rom% >> "!LogFile!"
                set /a deletedCount+=1
            ) else (
                echo [WARN] Could not delete source file
            )
        )
    ) else (
        echo [WARN] File created but tool reported error
        echo %date% - %time:~0,-3% = [~] Warning %rom% >> "!LogFile!"
        set /a totalSuccess+=1
        set /a opSuccess+=1
    )
) else (
    echo [FAIL] Compression failed
    call :showError "COMPRESS" "%rom%"
    echo %date% - %time:~0,-3% = [^^!] Failed %rom% >> "!LogFile!"
    set /a totalFailed+=1
    set /a opFailed+=1
)

:compressZ3ds_results
cls
echo ================================================================
echo   COMPRESSION COMPLETE
echo   Type: %selectedName%
echo ================================================================
echo.
echo  Success: %opSuccess%  ^|  Failed: %opFailed%  ^|  Skipped: %opSkipped%
if "!deleteSource!"=="1" (
    echo  Deleted: %deletedCount%
)
echo.
echo ================================================================

if %opSuccess% GTR 0 (
    echo.
    echo  [SUCCESS] %opSuccess% file^(s^) compressed^^!
    echo.
    echo  Output formats:
    if "%fileTypeChoice%"=="1" echo    - .z3ds files created
    if "%fileTypeChoice%"=="2" echo    - .zcci files created
    if "%fileTypeChoice%"=="3" echo    - .zcia files created
    if "%fileTypeChoice%"=="4" (
        echo    - .z3ds files from .3ds sources
        echo    - .zcci files from .cci sources
        echo    - .zcia files from .cia sources
    )
    echo.
    echo  Files ready for Azahar emulator.
)

if %opFailed% GTR 0 (
    echo.
    echo  [ERROR] %opFailed% file^(s^) failed
)

if %opSkipped% GTR 0 (
    echo.
    echo  [INFO] %opSkipped% file^(s^) already compressed
)

if "!deleteSource!"=="1" (
    if %deletedCount% GTR 0 (
        echo.
        echo  [CLEANUP] %deletedCount% source file^(s^) deleted
    )
)

echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: DECOMPRESS Z3DS FORMAT
:: ============================================================================
:decompressZ3ds
if "%hasZ3dsCompressor%"=="0" goto :noCompressor

set "opSuccess=0"
set "opFailed=0"
set "opSkipped=0"
set "deleteSource=0"
set "deletedCount=0"

cls
echo ================================================================
echo   Decompress Z3DS Format
echo   Extract from Compressed Format
echo ================================================================
echo.

:: Count Z3DS files
set "fileCount=0"
for %%f in (*.zcci *.zcia *.z3ds *.z3dsx) do set /a fileCount+=1

if !fileCount! EQU 0 (
    echo No Z3DS files found.
    echo.
    echo Supported: .zcci, .zcia, .z3ds, .z3dsx
    echo.
    pause
    goto menu
)

echo Found !fileCount! Z3DS file(s)
echo.
echo ================================================================
echo.
echo After decompression, you can delete compressed files to save space.
echo.
set /p "deletePrompt=Delete compressed files after decompression? (Y/N): "

if /i "!deletePrompt!"=="Y" (
    set "deleteSource=1"
    echo.
    echo ================================================================
    echo   WARNING: Compressed files will be DELETED after decompression^^!
    echo ================================================================
) else (
    set "deleteSource=0"
    echo.
    echo   Compressed files will be kept.
)

echo.
set "rom="
set /p "rom=Filename (Enter for all, M to return to menu): "

if /i "%rom%"=="M" goto menu

echo.

if not defined rom goto :decompressZ3ds_batch
if "%rom%"=="" goto :decompressZ3ds_batch

call :sanitizeInput "%rom%"
if "%sanitizeResult%"=="FAIL" (
    pause
    goto menu
)

goto :decompressZ3ds_single

:decompressZ3ds_batch
set "currentFile=0"

for %%f in (*.zcci *.zcia *.z3ds *.z3dsx) do (
    set "fullname=%%~nxf"
    set "basename=%%~nf"
    set "ext=%%~xf"
    set /a currentFile+=1
    
    cls
    echo ================================================================
    echo   Decompress Z3DS Format
    echo ================================================================
    echo.
    call :showProgress !currentFile! !fileCount! "!fullname!"
    echo.
    
    :: Determine expected output
    set "outfile="
    if /i "!ext!"==".zcci" set "outfile=!basename!.cci"
    if /i "!ext!"==".zcia" set "outfile=!basename!.cia"
    if /i "!ext!"==".z3ds" set "outfile=!basename!.3ds"
    if /i "!ext!"==".z3dsx" set "outfile=!basename!.3dsx"
    
    if exist "!outfile!" (
        echo  [SKIP] !outfile! already exists
        set /a totalSkipped+=1
        set /a opSkipped+=1
        timeout /t 1 >nul
    ) else (
        echo  [DECO] Decompressing to: !outfile!
        echo  Please wait...
        echo.
        
        "bin\z3ds_compressor.exe" --decompress "%%f" >nul 2>&1
        set "decompError=!errorlevel!"
        
        if exist "!outfile!" (
            if "!decompError!"=="0" (
                echo  [ OK ] Decompression successful
                echo %date% - %time:~0,-3% = [i] Decompressed %%f >> "!LogFile!"
                set /a totalSuccess+=1
                set /a opSuccess+=1
                
                :: Track file size
                for %%s in ("!outfile!") do set "fsize=%%~zs"
                set /a totalBytesProcessed+=fsize
                if !fsize! GTR !largestFile! (
                    set "largestFile=!fsize!"
                    set "largestFileName=!outfile!"
                )
                
                if "!deleteSource!"=="1" (
                    echo  [DEL ] Deleting compressed file
                    del "%%f" >nul 2>&1
                    if not exist "%%f" (
                        echo  [ OK ] Compressed file deleted
                        echo %date% - %time:~0,-3% = [i] Deleted: !fullname! >> "!LogFile!"
                        set /a deletedCount+=1
                    ) else (
                        echo  [WARN] Could not delete compressed file
                    )
                )
            ) else (
                echo  [WARN] File created but tool reported error
                echo %date% - %time:~0,-3% = [~] Warning %%f >> "!LogFile!"
                set /a totalSuccess+=1
                set /a opSuccess+=1
            )
        ) else (
            echo  [FAIL] Decompression failed
            echo %date% - %time:~0,-3% = [^^!] Failed %%f >> "!LogFile!"
            set /a totalFailed+=1
            set /a opFailed+=1
        )
        timeout /t 1 >nul
    )
)

goto :decompressZ3ds_results

:decompressZ3ds_single
if not exist "%rom%" (
    echo ERROR: File not found: %rom%
    echo.
    pause
    goto menu
)

for %%f in ("%rom%") do (
    set "basename=%%~nf"
    set "ext=%%~xf"
)

:: Determine expected output
set "outfile="
if /i "%ext%"==".zcci" set "outfile=%basename%.cci"
if /i "%ext%"==".zcia" set "outfile=%basename%.cia"
if /i "%ext%"==".z3ds" set "outfile=%basename%.3ds"
if /i "%ext%"==".z3dsx" set "outfile=%basename%.3dsx"

if exist "%outfile%" (
    echo [SKIP] %outfile% already exists
    set /a totalSkipped+=1
    set /a opSkipped+=1
    goto :decompressZ3ds_results
)

echo Ready to decompress: %rom%
echo Output: %outfile%
echo.
if "!deleteSource!"=="1" (
    echo ================================================================
    echo   WARNING: Compressed file will be DELETED after decompression^^!
    echo ================================================================
    echo.
)
set /p "confirm=Press ENTER to continue, or M to cancel: "

if /i "!confirm!"=="M" goto menu

echo.
echo  [DECO] Decompressing: %rom%
echo  Please wait...
echo.

"bin\z3ds_compressor.exe" --decompress "%rom%" >nul 2>&1
set "decompError=!errorlevel!"

if exist "%outfile%" (
    if "!decompError!"=="0" (
        echo  [ OK ] Decompression successful
        echo %date% - %time:~0,-3% = [i] Decompressed %rom% >> "!LogFile!"
        set /a totalSuccess+=1
        set /a opSuccess+=1
        
        :: Track file size
        for %%s in ("%outfile%") do set "fsize=%%~zs"
        set /a totalBytesProcessed+=fsize
        if !fsize! GTR !largestFile! (
            set "largestFile=!fsize!"
            set "largestFileName=%outfile%"
        )
        
        if "!deleteSource!"=="1" (
            echo.
            echo  [DEL ] Deleting compressed: %rom%
            del "%rom%" >nul 2>&1
            if not exist "%rom%" (
                echo  [ OK ] Compressed file deleted
                echo %date% - %time:~0,-3% = [i] Deleted: %rom% >> "!LogFile!"
                set /a deletedCount+=1
            ) else (
                echo  [WARN] Could not delete compressed file
            )
        )
    ) else (
        echo  [WARN] File created but tool reported error
        echo %date% - %time:~0,-3% = [~] Warning %rom% >> "!LogFile!"
        set /a totalSuccess+=1
        set /a opSuccess+=1
    )
) else (
    echo  [FAIL] Decompression failed
    echo %date% - %time:~0,-3% = [^^!] Failed %rom% >> "!LogFile!"
    set /a totalFailed+=1
    set /a opFailed+=1
)

goto :decompressZ3ds_results

:decompressZ3ds_results
cls
echo ================================================================
echo   DECOMPRESSION COMPLETE
echo ================================================================
echo.
echo  Success: %opSuccess%  ^|  Failed: %opFailed%  ^|  Skipped: %opSkipped%
if "!deleteSource!"=="1" echo  Deleted: %deletedCount%
echo.
echo ================================================================

if %opSuccess% GTR 0 (
    echo.
    echo  [SUCCESS] %opSuccess% file^(s^) decompressed^^!
    echo  Files restored to original format.
)

if %opFailed% GTR 0 (
    echo.
    echo  [ERROR] %opFailed% file^(s^) failed
)

if %opSkipped% GTR 0 (
    echo.
    echo  [INFO] %opSkipped% file^(s^) already decompressed
)

if "!deleteSource!"=="1" if %deletedCount% GTR 0 (
    echo.
    echo  [CLEANUP] %deletedCount% compressed file^(s^) deleted - space freed^^!
)

echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: LIST Z3DS FILE INFO
:: ============================================================================
:listZ3dsInfo
if "%hasZ3dsCompressor%"=="0" goto :noCompressor

cls
echo ================================================================
echo   Z3DS File Information
echo   Detailed Compressed File Info
echo ================================================================
echo.

set "z3dsCount=0"
for %%f in (*.zcci *.zcia *.z3ds *.z3dsx) do set /a z3dsCount+=1

if !z3dsCount! EQU 0 (
    echo No Z3DS files found in current directory.
    echo.
    pause
    goto menu
)

echo Found !z3dsCount! Z3DS file(s)
echo.
echo Type 'X' at any prompt to return to menu.
echo.
pause

:: Loop through files
set "currentFile=0"
for %%f in (*.zcci *.zcia *.z3ds *.z3dsx) do (
    set /a currentFile+=1
    
    cls
    echo ================================================================
    echo   Z3DS File Information [!currentFile!/!z3dsCount!]
    echo ================================================================
    echo.
    echo FILE: %%~nxf
    echo ================================================================
    "bin\z3ds_compressor.exe" --list "%%f" 2>nul
    echo.
    echo ================================================================
    
    if !currentFile! LSS !z3dsCount! (
        echo.
        set "continue="
        set /p "continue=Press ENTER for next file, or type X to exit: "
        
        if /i "!continue!"=="X" (
            echo.
            echo Returning to menu...
            timeout /t 1 >nul
            goto menu
        )
    ) else (
        echo.
        echo All files reviewed.
        echo.
        pause
    )
)

goto menu

:: ============================================================================
:: LIST FILES
:: ============================================================================
:listFiles
cls
echo ================================================================
echo   File Inventory
echo   All ROM Files in Current Directory
echo ================================================================
echo.

set "cciCount=0"
set "ciaCount=0"
set "threedsCount=0"
set "zcciCount=0"
set "zciaCount=0"
set "z3dsCount=0"
set "decryptedCount=0"

for %%f in (*.cci) do set /a cciCount+=1
for %%f in (*.cia) do set /a ciaCount+=1
for %%f in (*.3ds) do set /a threedsCount+=1
for %%f in (*.zcci) do set /a zcciCount+=1
for %%f in (*.zcia) do set /a zciaCount+=1
for %%f in (*.z3ds) do set /a z3dsCount+=1

for %%f in (*-decrypted.*) do set /a decryptedCount+=1

set /a totalFiles=threedsCount+cciCount+ciaCount+z3dsCount+zcciCount+zciaCount

echo SUMMARY
echo ================================================================
echo STANDARD FORMATS:
echo   3DS files:           %threedsCount%
echo   CCI files:           %cciCount%
echo   CIA files:           %ciaCount%
echo.
echo COMPRESSED FORMATS (AZAHAR):
echo   Z3DS files:          %z3dsCount%
echo   ZCCI files:          %zcciCount%
echo   ZCIA files:          %zciaCount%
echo.
echo OTHER:
echo   Decrypted files:     %decryptedCount%
echo   Total files:         %totalFiles%
echo ================================================================
echo.

if %totalFiles% EQU 0 (
    echo No ROM files found in current directory.
    echo.
    pause
    goto menu
)

echo Press any key to view detailed file list...
pause >nul

:: Browse files by category
set "currentCategory=1"

:listFiles_nextCategory

:: Category 1: 3DS FILES
if %currentCategory% EQU 1 (
    if %threedsCount% GTR 0 (
        call :listFiles_showPaged "*.3ds" "3DS FILES" %threedsCount% 1
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: Category 2: CCI FILES
if %currentCategory% EQU 2 (
    if %cciCount% GTR 0 (
        call :listFiles_showPaged "*.cci" "CCI FILES" %cciCount% 2
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: Category 3: CIA FILES
if %currentCategory% EQU 3 (
    if %ciaCount% GTR 0 (
        call :listFiles_showPaged "*.cia" "CIA FILES" %ciaCount% 3
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: Category 4: Z3DS FILES
if %currentCategory% EQU 4 (
    if %z3dsCount% GTR 0 (
        call :listFiles_showPaged "*.z3ds" "Z3DS FILES - COMPRESSED" %z3dsCount% 4
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: Category 5: ZCCI FILES
if %currentCategory% EQU 5 (
    if %zcciCount% GTR 0 (
        call :listFiles_showPaged "*.zcci" "ZCCI FILES - COMPRESSED" %zcciCount% 5
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: Category 6: ZCIA FILES
if %currentCategory% EQU 6 (
    if %zciaCount% GTR 0 (
        call :listFiles_showPaged "*.zcia" "ZCIA FILES - COMPRESSED" %zciaCount% 6
        if "!exitList!"=="1" goto menu
    )
    set /a currentCategory+=1
    goto listFiles_nextCategory
)

:: All done
cls
echo ================================================================
echo   All categories reviewed^^!
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: Show Paged File List
:: ============================================================================
:listFiles_showPaged
set "pattern=%~1"
set "categoryName=%~2"
set "fileCount=%~3"
set "categoryNum=%~4"
set "exitList=0"

:: Calculate total pages (27 files per page)
set /a totalPages=(fileCount + 26) / 27
set "currentPage=1"

:listFiles_showPage
cls
echo ================================================================
echo   %categoryName% [Category %categoryNum%/6 - Page %currentPage%/%totalPages%]
echo   Total: %fileCount% file^(s^)
echo ================================================================
echo.

:: Calculate range
set /a startNum=(currentPage - 1) * 27 + 1
set /a endNum=currentPage * 27
if %endNum% GTR %fileCount% set /a endNum=fileCount

set "fileNum=0"
for %%f in (%pattern%) do (
    set /a fileNum+=1
    
    if !fileNum! GEQ %startNum% if !fileNum! LEQ %endNum% (
        echo  !fileNum!. %%~nxf
    )
)

echo.
echo ================================================================
echo.

:: Navigation
if %currentPage% LSS %totalPages% (
    if %currentPage% GTR 1 (
        echo [N] Next page  ^|  [P] Previous page  ^|  [S] Skip category  ^|  [X] Exit
    ) else (
        echo [N] Next page  ^|  [S] Skip category  ^|  [X] Exit
    )
) else (
    if %currentPage% GTR 1 (
        echo [P] Previous page  ^|  [S] Skip category  ^|  [X] Exit
        echo Press ENTER to continue to next category
    ) else (
        echo [X] Exit  ^|  Press ENTER to continue to next category
    )
)

echo.
set "choice="
set /p "choice=Your choice: "

if /i "!choice!"=="X" (
    set "exitList=1"
    goto :eof
)

if /i "!choice!"=="S" goto :eof

if /i "!choice!"=="N" (
    if %currentPage% LSS %totalPages% (
        set /a currentPage+=1
        goto listFiles_showPage
    )
)

if /i "!choice!"=="P" (
    if %currentPage% GTR 1 (
        set /a currentPage-=1
        goto listFiles_showPage
    )
)

:: ENTER - continue
if "%choice%"=="" (
    if %currentPage% LSS %totalPages% (
        set /a currentPage+=1
        goto listFiles_showPage
    ) else (
        goto :eof
    )
)

goto listFiles_showPage

:: ============================================================================
:: STATISTICS
:: ============================================================================
:stats
cls
echo ================================================================
echo   Session Statistics
echo   Started: %sessionStartTime%
echo ================================================================
echo.
echo Operations:
echo ================================================================
echo Successful:          %totalSuccess%
echo Failed:              %totalFailed%
echo Skipped:             %totalSkipped%
echo ================================================================
echo.

if %totalBytesProcessed% GTR 0 (
    set /a bytesInMB=totalBytesProcessed/1048576
    set /a bytesInGB=totalBytesProcessed/1073741824
    
    echo Data Processed:
    echo ================================================================
    if !bytesInGB! GTR 0 (
        echo Total:               !bytesInGB! GB
    ) else if !bytesInMB! GTR 0 (
        echo Total:               !bytesInMB! MB
    ) else (
        echo Total:               %totalBytesProcessed% bytes
    )
    
    if defined largestFileName (
        set /a largestInMB=largestFile/1048576
        echo Largest file:        !largestFileName! ^(!largestInMB! MB^)
    )
    echo ================================================================
    echo.
)

echo Log file: %LogFile%
echo.
pause
goto menu

:: ============================================================================
:: CLEAN TEMPORARY FILES
:: ============================================================================
:cleanTemp
cls
echo ================================================================
echo   Clean Temporary Files
echo ================================================================
echo.

:: Count files
set "cleanCount=0"
set "ncchRootCount=0"

for %%f in (*.ncch) do set /a ncchRootCount+=1
for %%f in (bin\*.ncch bin\*.app bin\CTR_Content.txt bin\content.* bin\part.* bin\temp_check.txt bin\verify_temp.txt) do (
    if exist "%%f" set /a cleanCount+=1
)

:: Count temp directories
for /d %%d in (bin\temp_*) do set /a cleanCount+=1

set /a totalCleanCount=cleanCount+ncchRootCount

if %totalCleanCount% EQU 0 (
    echo No temporary files found.
    echo.
    echo Your workspace is already clean^^!
    echo.
    pause
    goto menu
)

echo Found temporary files:
echo ----------------------------------------------------------------
if %ncchRootCount% GTR 0 (
    echo   Root folder:     %ncchRootCount% .ncch file^(s^)
)
if %cleanCount% GTR 0 (
    echo   bin folder:      %cleanCount% temp file^(s^)/folder^(s^)
)
echo ----------------------------------------------------------------
echo   Total:           %totalCleanCount% item^(s^)
echo.
set /p "confirm=Clean these files? (Y/N): "
if /i not "!confirm!"=="Y" goto menu

echo.
echo Cleaning temporary files...
echo.

set "deletedCount=0"

:: Clean root NCCH files
if %ncchRootCount% GTR 0 (
    echo [CLEAN] Removing root .ncch files...
    for %%f in (*.ncch) do (
        del "%%f" >nul 2>&1
        if not exist "%%f" (
            echo   - Deleted: %%~nxf
            set /a deletedCount+=1
        )
    )
)

:: Clean bin folder
echo [CLEAN] Removing bin temp files...
for %%f in (bin\*.ncch bin\*.app bin\CTR_Content.txt bin\content.* bin\part.* bin\temp_check.txt bin\verify_temp.txt) do (
    if exist "%%f" (
        del "%%f" >nul 2>&1
        if not exist "%%f" (
            echo   - Deleted: %%f
            set /a deletedCount+=1
        )
    )
)

:: Clean temp directories
echo [CLEAN] Removing temp directories...
for /d %%d in (bin\temp_*) do (
    if exist "%%d" (
        rd /s /q "%%d" >nul 2>&1
        if not exist "%%d" (
            echo   - Deleted: %%d
            set /a deletedCount+=1
        )
    )
)

echo.
echo ================================================================
echo  [SUCCESS] Cleanup complete^^!
echo  Removed %deletedCount% item^(s^)
echo ================================================================
echo %date% - %time:~0,-3% = [i] Cleaned %deletedCount% temp files >> "!LogFile!"
echo.
pause
goto menu

:: ============================================================================
:: CREDITS
:: ============================================================================
:credits
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo   Build !BuildNumber! - !ReleaseDate!
echo ================================================================
echo.
echo CREATED BY:
echo   Dihny                   Enhanced batch version
echo.
echo SPECIAL THANKS:
echo   Claude AI               Script analysis and v1.5 optimization
echo   3DS Community           Testing and feedback
echo.
echo INSPIRED BY:
echo   rohithvishaal           Original Python concept
echo   R-YaTian                Prior batch adaptation
echo.
echo CORE SCRIPTS:
echo   matif ^& xxmichibxx      Decryptor Redux v1.1
echo.
echo TOOLS:
echo   3DSGuy ^& jakcron        makerom, ctrtool
echo   shijimasoft             decrypt.exe
echo   ihaveamac ^& soarqin     3dsconv, seeddb
echo   energeticokay           z3ds_compressor
echo.
echo VERSION HISTORY:
echo   v1.5 - Enhanced error handling, Windows 11 support
echo   v1.0 - Initial release
echo.
echo Independently developed from rohithvishaal's concept
echo and refined with community tools and ideas.
echo.
echo ================================================================
echo.
pause
goto menu

:: ============================================================================
:: EXIT
:: ============================================================================
:exitScript
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo ================================================================
echo.

set /a totalOps=!totalSuccess!+!totalFailed!+!totalSkipped!
if !totalOps! GTR 0 (
    echo Session Summary:
    echo ================================================================
    echo Successful:  %totalSuccess%
    echo Failed:      %totalFailed%
    echo Skipped:     %totalSkipped%
    echo ================================================================
    echo.
    echo Log saved to: %LogFile%
    echo.
)

echo Thank you for using 3DS ROM Manager Suite^^!
echo.
echo %date% - %time:~0,-3% = [i] Session Ended >> "!LogFile!"
pause
exit

:: ============================================================================
:: ERROR HANDLERS
:: ============================================================================

:missingTools
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo ================================================================
echo.
echo [ERROR] Missing Required Files
echo.
echo This tool requires:
if not exist "bin\makerom.exe" (
    echo   [REQUIRED] bin\makerom.exe
)
if "%hasCtrtool%"=="0" (
    echo   [REQUIRED] bin\ctrtool.exe
)
echo.
if "%hasZ3dsCompressor%"=="0" (
    echo Optional tools not found:
    echo   [OPTIONAL] bin\z3ds_compressor.exe
    echo              Enables Z3DS compression for Azahar emulator
    echo.
)
echo Download required tools from:
echo   https://github.com/3DSGuy/Project_CTR/releases
echo.
echo Extract and place in: %cd%\bin\
echo.
echo %date% - %time:~0,-3% = [^^!] Missing required tools >> "!LogFile!"
pause
exit

:missing3dsconv
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo ================================================================
echo.
echo [ERROR] 3dsconv Not Found
echo.
echo This tool requires:
echo   [REQUIRED] bin\3dsconv.exe
echo.
echo 3dsconv is essential for CCI/3DS to CIA conversion.
echo It handles both encrypted and decrypted files automatically.
echo.
echo Download from:
echo   https://github.com/ihaveamac/3dsconv/releases
echo.
echo Extract 3dsconv.exe and place in: %cd%\bin\
echo.
echo %date% - %time:~0,-3% = [^^!] Missing 3dsconv >> "!LogFile!"
pause
exit

:noDecryptor
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo ================================================================
echo.
echo [ERROR] Decryptor Not Found
echo.
echo This feature requires Batch CIA 3DS Decryptor Redux.bat
echo to be in the same folder as this tool.
echo.
pause
goto menu

:noCompressor
cls
echo ================================================================
echo   3DS ROM Manager Suite !Version!
echo ================================================================
echo.
echo [ERROR] Z3DS Compressor Not Found
echo.
echo This feature requires:
echo   - bin\z3ds_compressor.exe (single static executable)
echo.
echo This tool enables Z3DS compression/decompression
echo for Azahar emulator.
echo.
pause
goto menu