@echo off
cd /d "%~dp0"
setlocal EnableDelayedExpansion

mode con: cols=80 lines=40
color 0F
title Batch CIA 3DS Decryptor Redux v1.1

:: ============================================================================
:: CONFIGURATION
:: ============================================================================
set "Version=v1.1"
set "addDecryptedSuffix=1"

:: Auto mode detection (called from ROM Manager Suite)
set "autoMode=0"
set "outputFormat=default"
if /i "%~1"=="AUTO" set "autoMode=1"
if /i "%~2"=="CIA" set "outputFormat=cia"
if /i "%~2"=="CCI" set "outputFormat=cci"

:: Paths
set "rootdir=%cd%"
set "logfile=log\decryptor_log.txt"
set "content=bin\CTR_Content.txt"
set "MakeROM=bin\makerom.exe"

:: Suffix configuration
if "!addDecryptedSuffix!"=="1" (
    set "suffix=-decrypted"
) else (
    set "suffix="
)

:: Statistics
set "totalCount=0"
set "finalCount=0"
set "count3DS=0"
set "countCIA=0"
set "success3DS=0"
set "successCIA=0"
set "failed3DS=0"
set "failedCIA=0"
set "skipped3DS=0"
set "skippedCIA=0"
set "convertToCCI=0"
set "convert3DStoCIA=0"
set "golfEvent=0"

:: ============================================================================
:: INITIALIZATION
:: ============================================================================
call :initEnvironment
if errorlevel 1 goto :missingTools

:: ============================================================================
:: MAIN EXECUTION
:: ============================================================================
call :countFiles
if !totalCount! EQU 0 goto :noFiles

if "!autoMode!"=="0" (
    call :getUserPreferences
    call :showConversionFlow
) else (
    if "!outputFormat!"=="cia" set "convert3DStoCIA=1"
)

call :processROMFiles
call :showResults
goto :cleanup

:: ============================================================================
:: FUNCTION: Initialize Environment
:: ============================================================================
:initEnvironment
:: Create directories
if not exist "log" mkdir "log"
if not exist "bin" mkdir "bin"

:: Initialize log
if not exist "!logfile!" (
    echo Batch CIA 3DS Decryptor Redux !Version! > "!logfile!"
    echo [i] = Information >> "!logfile!"
    echo [^^!] = Error >> "!logfile!"
    echo [~] = Warning >> "!logfile!"
    echo. >> "!logfile!"
    echo Log Created: %date% %time% >> "!logfile!"
    echo. >> "!logfile!"
)

echo %date% - %time:~0,-3% = [i] Decryptor started >> "!logfile!"
if "!autoMode!"=="1" echo %date% - %time:~0,-3% = [i] AUTO mode: !outputFormat! >> "!logfile!"

:: Detect x86 makerom if needed
if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    if exist "bin\makerom_x86.exe" set "MakeROM=bin\makerom_x86.exe"
)

:: Verify 64-bit OS
if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto :unsupported

:: Check for Windows XP x64 / Server 2003 (version 5.2)
ver | find "5.2" >nul
if "%errorlevel%"=="0" goto :unsupported

:: Check required tools
if not exist "bin\decrypt.exe" exit /b 1
if not exist "!MakeROM!" exit /b 1
if not exist "bin\ctrtool.exe" exit /b 1

:: Warn about missing seeddb.bin
if not exist "bin\seeddb.bin" (
    echo %date% - %time:~0,-3% = [~] seeddb.bin not found - seed-encrypted games may fail >> "!logfile!"
    if "!autoMode!"=="0" (
        echo.
        echo [WARNING] seeddb.bin not found in bin\ folder
        echo.
        echo Some newer games ^(2015+^) require seeddb.bin for decryption.
        echo Download from: https://github.com/ihaveamac/3DS-rom-tools/tree/master/seeddb
        echo.
        timeout /t 3 >nul
    )
)

:: Clean old NCCH files
for %%a in (bin\*.ncch *.ncch) do del "%%a" >nul 2>&1

exit /b 0

:: ============================================================================
:: FUNCTION: Count Files (Safe with special characters)
:: ============================================================================
:countFiles
set "count3DS=0"
set "countCIA=0"

for %%f in (*.cia) do (
    set "fname=%%~nf"
    
    :: Skip already decrypted files using findstr
    echo !fname! | findstr /C:"!suffix!" >nul 2>&1
    if errorlevel 1 set /a countCIA+=1
)

for %%f in (*.3ds *.cci) do (
    set "fname=%%~nf"
    
    :: Skip already decrypted files using findstr
    echo !fname! | findstr /C:"!suffix!" >nul 2>&1
    if errorlevel 1 set /a count3DS+=1
)

set /a totalCount=!countCIA!+!count3DS!
exit /b 0

:: ============================================================================
:: FUNCTION: Get User Preferences
:: ============================================================================
:getUserPreferences
:: Ask about 3DS output format
if !count3DS! GEQ 1 (
    cls
    echo ================================================================
    echo   Batch CIA 3DS Decryptor Redux !Version!
    echo   3DS File Output Format
    echo ================================================================
    echo.
    if !count3DS! EQU 1 (
        echo Found 1 3DS/CCI file
    ) else (
        echo Found !count3DS! 3DS/CCI files
    )
    echo.
    echo Output format for decrypted files?
    echo.
    echo   [1] CIA - Installable format ^(Recommended^)
    echo   [2] CCI - Cartridge format
    echo.
    set /p "format3DS=Choice (1 or 2): "
    
    if "!format3DS!"=="1" set "convert3DStoCIA=1"
)

:: Ask about CIA to CCI conversion
if !countCIA! GEQ 1 (
    cls
    echo ================================================================
    echo   Batch CIA 3DS Decryptor Redux !Version!
    echo   CIA Conversion Options
    echo ================================================================
    echo.
    if !countCIA! EQU 1 (
        echo Found 1 CIA file
    ) else (
        echo Found !countCIA! CIA files
    )
    echo.
    echo Convert to CCI format after decryption?
    echo.
    echo NOTE: Not compatible with DLC, Updates, Demos, or System titles
    echo.
    echo   [Y] Yes
    echo   [N] No
    echo.
    set /p "question=Choice (Y/N): "
    if /i "!question!"=="y" set "convertToCCI=1"
)

:: Ask for specific file or batch
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo   File Selection
echo ================================================================
echo.
set "targetFile="
set /p "targetFile=ROM name (or Enter for all): "

exit /b 0

:: ============================================================================
:: FUNCTION: Show Conversion Flow
:: ============================================================================
:showConversionFlow
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo Decrypting...
echo.
echo.
echo.
echo                  #############   #############
echo                  #         ###   #         ###

set "FancyArt=0"

:: Both CIA and 3DS files present
if !countCIA! GEQ 1 if !count3DS! GEQ 1 (
    if "!convert3DStoCIA!"=="1" if "!convertToCCI!"=="1" (
        echo                  # CIA/3DS #     # CIA/CCI #
    ) else if "!convert3DStoCIA!"=="1" (
        echo                  # CIA/3DS #     #   CIA   #
    ) else if "!convertToCCI!"=="1" (
        echo                  # CIA/3DS #     # CCI/CCI #
    ) else (
        echo                  # CIA/3DS #     # CIA/CCI #
    )
    set "FancyArt=1"
)

:: Only CIA files
if "!FancyArt!"=="0" if !countCIA! GEQ 1 (
    if "!convertToCCI!"=="1" (
        echo                  #   CIA   #     #   CCI   #
    ) else (
        echo                  #   CIA   #     #   CIA   #
    )
    set "FancyArt=1"
)

:: Only 3DS files
if "!FancyArt!"=="0" if !count3DS! GEQ 1 (
    if "!convert3DStoCIA!"=="1" (
        echo                  #   3DS   #     #   CIA   #
    ) else (
        echo                  #   3DS   #     #   CCI   #
    )
)

echo                  #        --------^>        #
echo                  #         #     #         #
echo                  ###########     ###########
echo.
timeout /t 2 >nul
exit /b 0

:: ============================================================================
:: FUNCTION: Process ROM Files
:: ============================================================================
:processROMFiles
if !count3DS! GTR 0 (
    if !count3DS! EQU 1 (
        echo %date% - %time:~0,-3% = [i] Found !count3DS! 3DS file. Start decrypting... >> "!logfile!"
    ) else (
        echo %date% - %time:~0,-3% = [i] Found !count3DS! 3DS files. Start decrypting... >> "!logfile!"
    )
    call :process3DSFiles
)

if !countCIA! GTR 0 (
    if !countCIA! EQU 1 (
        echo %date% - %time:~0,-3% = [i] Found !countCIA! CIA file. Start decrypting... >> "!logfile!"
    ) else (
        echo %date% - %time:~0,-3% = [i] Found !countCIA! CIA files. Start decrypting... >> "!logfile!"
    )
    call :processCIAFiles
)
exit /b 0

:: ============================================================================
:: FUNCTION: Process 3DS Files (Safe filename handling)
:: ============================================================================
:process3DSFiles
set "processedCount=0"

for %%a in (*.3ds *.cci) do (
    set "FileName=%%~na"
    set "fullFileName=%%~nxa"
    set "fullPath=%%~fa"
    set "processFile=0"
    set "skipFile=0"
    
    :: Check if already processed using findstr
    echo !FileName! | findstr /C:"!suffix!" >nul 2>&1
    if not errorlevel 1 set "skipFile=1"
    
    :: Check if we should process this file
    if "!skipFile!"=="0" (
        if "!targetFile!"=="" (
            set "processFile=1"
        ) else if /i "!targetFile!"=="!FileName!" (
            set "processFile=1"
        ) else if /i "!targetFile!"=="!fullFileName!" (
            set "processFile=1"
        )
    )
    
    if "!processFile!"=="1" (
        set /a processedCount+=1
        
        :: Determine output filename
        if "!convert3DStoCIA!"=="1" (
            set "finalOutput=!FileName!!suffix!.cia"
        ) else (
            set "finalOutput=!FileName!!suffix!.cci"
        )
        
        :: Process if output doesn't exist
        if not exist "!finalOutput!" (
            if "!autoMode!"=="0" (
                cls
                echo ================================================================
                echo   Decrypting 3DS/CCI Files
                echo ================================================================
                echo.
                call :showProgressBar !processedCount! !count3DS!
                echo.
                echo File: !fullFileName!
                echo.
            )
            
            call :decrypt3DSFile "!fullPath!" "!FileName!" "!finalOutput!"
            
            if "!autoMode!"=="0" timeout /t 1 >nul
        ) else (
            if "!autoMode!"=="0" echo [SKIP] !finalOutput! exists
            echo %date% - %time:~0,-3% = [~] 3DS file "!FileName!" was already decrypted >> "!logfile!"
            set /a skipped3DS+=1
            set /a finalCount+=1
        )
    )
)

:: Clean NCCH files
for %%a in (bin\*.ncch) do del "%%a" >nul 2>&1

exit /b 0

:: ============================================================================
:: FUNCTION: Decrypt 3DS File
:: ============================================================================
:decrypt3DSFile
set "inputFile=%~1"
set "baseName=%~2"
set "outputFile=%~3"

:: DEBUG: Log input
echo %date% - %time:~0,-3% = [DEBUG] Input file: %inputFile% >> "!logfile!"
echo %date% - %time:~0,-3% = [DEBUG] Base name: %baseName% >> "!logfile!"

:: Analyze file with ctrtool
bin\ctrtool.exe --seeddb=bin\seeddb.bin "%inputFile%" >"!content!" 2>&1

:: Extract metadata (more robust)
set "TitleId="
set "TitleVersion="

for /f "tokens=2 delims=: " %%x in ('findstr /c:"Title id:" "!content!"') do (
    if not defined TitleId (
        set "TitleId=%%x"
        set "TitleId=!TitleId: =!"
    )
)

for /f "tokens=3 delims= " %%z in ('findstr /c:"Title version:" "!content!"') do (
    if not defined TitleVersion set "TitleVersion=%%z"
)

:: Fallback if extraction failed
if "!TitleId!"=="" set "TitleId=unknown"
if "!TitleId!"=="id" set "TitleId=unknown"
if "!TitleVersion!"=="" set "TitleVersion=0"

:: DEBUG: Log extracted metadata
echo %date% - %time:~0,-3% = [DEBUG] Extracted Title ID: !TitleId! >> "!logfile!"
echo %date% - %time:~0,-3% = [DEBUG] Extracted Version: !TitleVersion! >> "!logfile!"

:: Better encryption detection
set "isDecrypted=0"
findstr /c:"Crypto key:             0x00" "!content!" >nul 2>&1
if !errorlevel!==0 set "isDecrypted=1"

:: Check if already decrypted
if "!isDecrypted!"=="1" (
    if "!autoMode!"=="0" echo [SKIP] Already decrypted
    echo %date% - %time:~0,-3% = [~] 3DS file "!baseName!" [!TitleId! v!TitleVersion!] is already decrypted >> "!logfile!"
    set /a skipped3DS+=1
    exit /b 0
)

:: File is encrypted, proceed with decryption
if "!autoMode!"=="0" echo [DECRYPT] Decrypting ROM...
echo %date% - %time:~0,-3% = [i] Decrypting "!fullFileName!" [!TitleId! v!TitleVersion!] >> "!logfile!"

:: Golf easter egg check
if "!golfEvent!"=="0" call :checkGolfTitle "!TitleId!"

:: DEBUG: Check file exists before copy
if not exist "%inputFile%" (
    echo %date% - %time:~0,-3% = [DEBUG] ERROR - Input file does not exist! >> "!logfile!"
    set /a failed3DS+=1
    exit /b 1
)

:: Copy file to bin\ before decrypting
echo %date% - %time:~0,-3% = [DEBUG] Copying file to bin\temp_decrypt.3ds >> "!logfile!"
copy "%inputFile%" "bin\temp_decrypt.3ds" >nul 2>&1

if not exist "bin\temp_decrypt.3ds" (
    echo %date% - %time:~0,-3% = [DEBUG] ERROR - Copy failed! >> "!logfile!"
    set /a failed3DS+=1
    exit /b 1
)

:: Decrypt in bin\ directory
echo %date% - %time:~0,-3% = [DEBUG] Running decrypt.exe >> "!logfile!"
pushd bin
decrypt.exe "temp_decrypt.3ds" --no-verbose >decrypt_output.txt 2>&1
set "decryptExit=!errorlevel!"
popd

:: DEBUG: Log decrypt result
echo %date% - %time:~0,-3% = [DEBUG] decrypt.exe exit code: !decryptExit! >> "!logfile!"
if exist "bin\decrypt_output.txt" (
    echo %date% - %time:~0,-3% = [DEBUG] decrypt.exe output: >> "!logfile!"
    type "bin\decrypt_output.txt" >> "!logfile!"
)

:: Clean temp input file
del "bin\temp_decrypt.3ds" >nul 2>&1

:: Check if NCCH files were created
set "ncchCount=0"
for %%F in (bin\*.ncch) do set /a ncchCount+=1

echo %date% - %time:~0,-3% = [DEBUG] NCCH files found: !ncchCount! >> "!logfile!"

if !ncchCount!==0 (
    echo %date% - %time:~0,-3% = [DEBUG] ERROR - No NCCH files created by decrypt.exe! >> "!logfile!"
    if "!autoMode!"=="0" echo [FAIL] decrypt.exe created no output files
    set /a failed3DS+=1
    exit /b 1
)

:: List NCCH files before rename
echo %date% - %time:~0,-3% = [DEBUG] NCCH files before rename: >> "!logfile!"
for %%F in (bin\*.ncch) do echo %date% - %time:~0,-3% = [DEBUG]   %%F >> "!logfile!"

:: Rename NCCH files
call :renameNCCHFiles

:: List NCCH files after rename
echo %date% - %time:~0,-3% = [DEBUG] NCCH files after rename: >> "!logfile!"
for %%F in (bin\tmp.*.ncch) do echo %date% - %time:~0,-3% = [DEBUG]   %%F >> "!logfile!"

:: Build makerom arguments
set "ARG="
for %%f in ("bin\tmp.*.ncch") do (
    if "%%~nxf"=="tmp.Main.ncch" set "i=0"
    if "%%~nxf"=="tmp.Manual.ncch" set "i=1"
    if "%%~nxf"=="tmp.DownloadPlay.ncch" set "i=2"
    if "%%~nxf"=="tmp.Partition4.ncch" set "i=3"
    if "%%~nxf"=="tmp.Partition5.ncch" set "i=4"
    if "%%~nxf"=="tmp.Partition6.ncch" set "i=5"
    if "%%~nxf"=="tmp.N3DSUpdateData.ncch" set "i=6"
    if "%%~nxf"=="tmp.UpdateData.ncch" set "i=7"
    set "ARG=!ARG! -i "%%f:!i!:!i!""
    echo %date% - %time:~0,-3% = [DEBUG] Added to ARG: -i "%%f:!i!:!i!" >> "!logfile!"
)

:: DEBUG: Log final ARG
echo %date% - %time:~0,-3% = [DEBUG] Final makerom ARG: !ARG! >> "!logfile!"

if "!ARG!"=="" (
    echo %date% - %time:~0,-3% = [DEBUG] ERROR - ARG is empty, no NCCH files matched! >> "!logfile!"
    set /a failed3DS+=1
    exit /b 1
)

:: Build output based on format
if "!convert3DStoCIA!"=="1" (
    :: Build CIA directly from NCCH files
    if "!autoMode!"=="0" echo [BUILD] Creating CIA...
    
    echo %date% - %time:~0,-3% = [DEBUG] makerom CIA command: -f cia -ignoresign -target t -o "!outputFile!"!ARG! >> "!logfile!"
    
    :: Capture ALL output
    "!MakeROM!" -f cia -ignoresign -target t -o "!outputFile!"!ARG! >bin\makerom_output.txt 2>&1
    set "makeromExit=!errorlevel!"
    
    :: Log output
    echo %date% - %time:~0,-3% = [DEBUG] makerom exit code: !makeromExit! >> "!logfile!"
    echo %date% - %time:~0,-3% = [DEBUG] makerom output: >> "!logfile!"
    type bin\makerom_output.txt >> "!logfile!"
    echo. >> "!logfile!"
    
    :: Check for errors in output (since exit code is unreliable)
    findstr /i "ERROR" bin\makerom_output.txt >nul 2>&1
    if !errorlevel!==0 (
        if "!autoMode!"=="0" echo [FAIL] makerom reported errors
        echo %date% - %time:~0,-3% = [^^!] makerom CIA build failed for "!baseName!" >> "!logfile!"
        del bin\makerom_output.txt >nul 2>&1
        set /a failed3DS+=1
        exit /b 1
    )
    
    :: Check if output was created
    if not exist "!outputFile!" (
        echo %date% - %time:~0,-3% = [DEBUG] ERROR - CIA was not created! >> "!logfile!"
        if "!autoMode!"=="0" echo [FAIL] CIA creation failed
        del bin\makerom_output.txt >nul 2>&1
        set /a failed3DS+=1
        exit /b 1
    )
    
) else (
    :: Build CCI directly
    if "!autoMode!"=="0" echo [BUILD] Creating CCI...
    echo %date% - %time:~0,-3% = [DEBUG] makerom CCI command: -f cci -ignoresign -target t -o "!outputFile!"!ARG! >> "!logfile!"
    
    :: Capture ALL output
    "!MakeROM!" -f cci -ignoresign -target t -o "!outputFile!"!ARG! >bin\makerom_output.txt 2>&1
    set "makeromExit=!errorlevel!"
    
    :: Log output
    echo %date% - %time:~0,-3% = [DEBUG] makerom exit code: !makeromExit! >> "!logfile!"
    echo %date% - %time:~0,-3% = [DEBUG] makerom output: >> "!logfile!"
    type bin\makerom_output.txt >> "!logfile!"
    echo. >> "!logfile!"
    
    :: Check for errors in output
    findstr /i "ERROR" bin\makerom_output.txt >nul 2>&1
    if !errorlevel!==0 (
        if "!autoMode!"=="0" echo [FAIL] makerom reported errors
        echo %date% - %time:~0,-3% = [^^!] makerom CCI build failed for "!baseName!" >> "!logfile!"
        del bin\makerom_output.txt >nul 2>&1
        set /a failed3DS+=1
        exit /b 1
    )
    
    :: Check if output was created
    if not exist "!outputFile!" (
        echo %date% - %time:~0,-3% = [DEBUG] ERROR - CCI was not created! >> "!logfile!"
        if "!autoMode!"=="0" echo [FAIL] CCI creation failed
        del bin\makerom_output.txt >nul 2>&1
        set /a failed3DS+=1
        exit /b 1
    )
)

:: Clean output logs
if exist "bin\makerom_output.txt" del "bin\makerom_output.txt" >nul 2>&1
if exist "bin\decrypt_output.txt" del "bin\decrypt_output.txt" >nul 2>&1

:: Clean NCCH files
for %%b in (bin\*.ncch) do del "%%b" >nul 2>&1

:: Check result and increment counters
if exist "!outputFile!" (
    if "!autoMode!"=="0" echo [ OK ] Successfully created !outputFile!
    echo %date% - %time:~0,-3% = [i] Decrypting succeeded for "!baseName!" >> "!logfile!"
    set /a success3DS+=1
    set /a finalCount+=1
) else (
    if "!autoMode!"=="0" echo [FAIL] Output file not created
    echo %date% - %time:~0,-3% = [^^!] Output file was not created for "!baseName!" >> "!logfile!"
    set /a failed3DS+=1
)

exit /b 0

:: ============================================================================
:: FUNCTION: Rename NCCH Files
:: ============================================================================
:renameNCCHFiles
:: decrypt.exe creates files like "temp_decrypt.Main.ncch"
:: We need to rename them to "tmp.Main.ncch" format
:: IMPORTANT: "Download Play" has a SPACE in the partition name!

for %%F in ("bin\*.Main.ncch") do ren "%%F" "tmp.Main.ncch" 2>nul
for %%F in ("bin\*.Manual.ncch") do ren "%%F" "tmp.Manual.ncch" 2>nul
for %%F in ("bin\*.Download Play.ncch") do ren "%%F" "tmp.DownloadPlay.ncch" 2>nul
for %%F in ("bin\*.Partition4.ncch") do ren "%%F" "tmp.Partition4.ncch" 2>nul
for %%F in ("bin\*.Partition5.ncch") do ren "%%F" "tmp.Partition5.ncch" 2>nul
for %%F in ("bin\*.Partition6.ncch") do ren "%%F" "tmp.Partition6.ncch" 2>nul
for %%F in ("bin\*.N3DSUpdateData.ncch") do ren "%%F" "tmp.N3DSUpdateData.ncch" 2>nul
for %%F in ("bin\*.UpdateData.ncch") do ren "%%F" "tmp.UpdateData.ncch" 2>nul

exit /b 0

:: ============================================================================
:: FUNCTION: Process CIA Files (Safe filename handling)
:: ============================================================================
:processCIAFiles
set "processedCount=0"

for %%a in (*.cia) do (
    set "FileName=%%~na"
    set "fullFileName=%%~nxa"
    set "fullPath=%%~fa"
    set "processFile=0"
    set "skipFile=0"
    
    :: Check if already processed
    echo !FileName! | findstr /C:"!suffix!" >nul 2>&1
    if not errorlevel 1 set "skipFile=1"
    
    :: Check if we should process this file
    if "!skipFile!"=="0" (
        if "!targetFile!"=="" (
            set "processFile=1"
        ) else if /i "!targetFile!"=="!FileName!" (
            set "processFile=1"
        ) else if /i "!targetFile!"=="!fullFileName!" (
            set "processFile=1"
        )
    )
    
    if "!processFile!"=="1" (
        set /a processedCount+=1
        
        :: Determine output filename
        if "!convertToCCI!"=="1" (
            set "outputFile=!FileName!!suffix!.cci"
        ) else (
            set "outputFile=!FileName!!suffix!.cia"
        )
        
        :: Check if already processed
        if exist "!FileName!*!suffix!.cia" (
            if "!convertToCCI!"=="1" (
                if not exist "!FileName!*!suffix!.cci" (
                    :: Need to convert existing CIA to CCI
                    call :convertExistingCIAtoCCI "!FileName!"
                ) else (
                    if "!autoMode!"=="0" echo [SKIP] Already converted to CCI
                    echo %date% - %time:~0,-3% = [~] CIA file "!FileName!" was already converted to CCI >> "!logfile!"
                    set /a finalCount+=1
                )
            ) else (
                if "!autoMode!"=="0" echo [SKIP] Already decrypted
                echo %date% - %time:~0,-3% = [~] CIA file "!FileName!" was already decrypted >> "!logfile!"
                set /a finalCount+=1
            )
        ) else if exist "!FileName!*!suffix!.cci" (
            if "!autoMode!"=="0" echo [SKIP] Already converted to CCI
            echo %date% - %time:~0,-3% = [~] CIA file "!FileName!" was already converted to CCI >> "!logfile!"
            set /a finalCount+=1
        ) else (
            if "!autoMode!"=="0" (
                cls
                echo ================================================================
                echo   Decrypting CIA Files
                echo ================================================================
                echo.
                call :showProgressBar !processedCount! !countCIA!
                echo.
                echo File: !fullFileName!
                echo.
            )
            
            call :decryptCIAFile "!fullPath!" "!FileName!" "!outputFile!"
            
            if "!autoMode!"=="0" timeout /t 1 >nul
        )
    )
)

:: Clean NCCH files
for %%a in (bin\*.ncch) do del "%%a" >nul 2>&1

exit /b 0

:: ============================================================================
:: FUNCTION: Decrypt CIA File
:: ============================================================================
:decryptCIAFile
set "inputFile=%~1"
set "baseName=%~2"
set "outputFile=%~3"

:: Delete old content file
if exist "!content!" del "!content!" >nul 2>&1

:: Analyze CIA with ctrtool
bin\ctrtool.exe --seeddb=bin\seeddb.bin "%inputFile%" >"!content!" 2>&1

:: Extract metadata using correct token positions
set "TitleId="
set "TitleVersion="
for /f "tokens=2 delims=: " %%x in ('findstr /c:"Title id:" "!content!"') do (
    if not defined TitleId (
        set "TitleId=%%x"
        set "TitleId=!TitleId: =!"
    )
)
for /f "tokens=3 delims= " %%z in ('findstr /c:"Title version:" "!content!"') do (
    if not defined TitleVersion set "TitleVersion=%%z"
)

:: Check for errors
set /p "ctrtool_data="<"!content!"
echo "!ctrtool_data!" | findstr "ERROR" >nul 2>&1
if !errorlevel!==0 (
    if "!autoMode!"=="0" echo [FAIL] Invalid CIA file
    echo %date% - %time:~0,-3% = [^^!] CIA is invalid [!baseName!.cia] >> "!logfile!"
    set /a failedCIA+=1
    exit /b 0
)

:: Check if decrypted using correct crypto key detection
findstr /c:"Crypto key:             0x00" "!content!" >nul 2>&1
if !errorlevel!==0 (
    if "!autoMode!"=="0" echo [SKIP] Already decrypted
    echo %date% - %time:~0,-3% = [~] CIA file "!baseName!" [!TitleId! v!TitleVersion!] is already decrypted >> "!logfile!"
    set /a skippedCIA+=1
    exit /b 0
)

:: Check if it's encrypted (look for Secure in crypto key)
findstr /c:"Crypto key:" "!content!" | findstr "Secure" >nul 2>&1
if !errorlevel!==0 (
    :: Standard CIA processing
    call :processCIAByType "%inputFile%" "!baseName!" "!outputFile!" "!TitleId!" "!TitleVersion!"
) else (
    :: Try TWL title processing
    call :processTWLTitle "%inputFile%" "!baseName!" "!outputFile!" "!TitleId!" "!TitleVersion!"
)

exit /b 0

:: ============================================================================
:: FUNCTION: Process CIA By Type
:: ============================================================================
:processCIAByType
set "inputPath=%~1"
set "baseName=%~2"
set "outputPath=%~3"
set "titleId=%~4"
set "titleVer=%~5"

set "CIAType=0"
set /a "i=0"
set "ARG="

:: Golf easter egg check
if "!golfEvent!"=="0" call :checkGolfTitle "!titleId!"

:: Use proper Title ID category detection (extract category from position 4-7)
set "Category=!titleId:~4,4!"

:: Game titles (eShop/Gamecard) - category 0000
if /i "!Category!"=="0000" (
    echo %date% - %time:~0,-3% = [i] CIA file "!baseName!" [!titleId! v!titleVer!] is a eShop or Gamecard title >> "!logfile!"
    set "CIAType=1"
    set "typeLabel=Game"
    call :decryptAndRebuildCIA "%inputPath%" "!baseName!" "!typeLabel!" "!titleVer!"
    exit /b 0
)

:: System titles - categories 0010, 001b, 0030, 009b, 00db, 0130, 0138
if /i "!Category!"=="0010" set "CIAType=1"
if /i "!Category!"=="001b" set "CIAType=1"
if /i "!Category!"=="0030" set "CIAType=1"
if /i "!Category!"=="009b" set "CIAType=1"
if /i "!Category!"=="00db" set "CIAType=1"
if /i "!Category!"=="0130" set "CIAType=1"
if /i "!Category!"=="0138" set "CIAType=1"

if "!CIAType!"=="1" (
    call :logCIASystemType "!titleId!" "!baseName!" "!titleVer!"
    set "typeLabel=System"
    call :decryptAndRebuildCIA "%inputPath%" "!baseName!" "!typeLabel!" "!titleVer!"
    exit /b 0
)

:: Demos - category 0002
if /i "!Category!"=="0002" (
    echo %date% - %time:~0,-3% = [i] CIA file "!baseName!" [!titleId! v!titleVer!] is a demo title >> "!logfile!"
    set "CIAType=1"
    set "typeLabel=Demo"
    call :decryptAndRebuildCIA "%inputPath%" "!baseName!" "!typeLabel!" "!titleVer!"
    exit /b 0
)

:: Updates - category 000e
if /i "!Category!"=="000e" (
    echo %date% - %time:~0,-3% = [i] CIA file "!baseName!" [!titleId! v!titleVer!] is an update title >> "!logfile!"
    set "CIAType=1"
    set "typeLabel=Patch"
    call :decryptAndRebuildCIA "%inputPath%" "!baseName!" "!typeLabel!" "!titleVer!"
    exit /b 0
)

:: DLC - category 008c
if /i "!Category!"=="008c" (
    echo %date% - %time:~0,-3% = [i] CIA file "!baseName!" [!titleId! v!titleVer!] is a DLC title >> "!logfile!"
    set "CIAType=1"
    set "typeLabel=DLC"
    call :decryptAndRebuildCIA "%inputPath!" "!baseName!" "!typeLabel!" "!titleVer!" "dlc"
    exit /b 0
)

:: Unknown type
if "!CIAType!"=="0" (
    echo %date% - %time:~0,-3% = [^^!] Could not determine CIA type [!baseName!.cia] >> "!logfile!"
    echo %date% - %time:~0,-3% = [^^!] Please report !titleId! v!titleVer! to the developer >> "!logfile!"
    set /a failedCIA+=1
)

exit /b 0

:: ============================================================================
:: FUNCTION: Decrypt and Rebuild CIA
:: ============================================================================
:decryptAndRebuildCIA
set "inputPath=%~1"
set "baseName=%~2"
set "typeLabel=%~3"
set "titleVer=%~4"
set "isDLC=%~5"

:: Copy to bin\ before decrypting
copy "%inputPath%" "bin\temp_decrypt.cia" >nul 2>&1

:: Decrypt in bin\ directory
pushd bin
echo.| decrypt.exe "temp_decrypt.cia" --no-verbose >nul 2>&1
popd

:: Clean temp file
del "bin\temp_decrypt.cia" >nul 2>&1

:: Rename to tmp format
call :renameNCCHFiles

:: Build arguments
set "ARG="
set /a "i=0"
for %%f in ("bin\tmp.*.ncch") do (
    set "ARG=!ARG! -i "%%f:!i!:!i!""
    set /a i+=1
)

:: Build CIA with makerom
set "finalCIA=!baseName! !typeLabel!!suffix!.cia"

if "!autoMode!"=="0" echo [BUILD] Creating CIA...
echo %date% - %time:~0,-3% = [i] Calling makerom for !typeLabel! CIA >> "!logfile!"

:: Capture makerom errors and check exit code
if /i "!isDLC!"=="dlc" (
    "!MakeROM!" -f cia -dlc -ignoresign -target p -o "!finalCIA!"!ARG! -ver !titleVer! >nul 2>bin\makerom_error.txt
) else (
    "!MakeROM!" -f cia -ignoresign -target p -o "!finalCIA!"!ARG! -ver !titleVer! >nul 2>bin\makerom_error.txt
)

:: Check makerom result
if !errorlevel! neq 0 (
    if "!autoMode!"=="0" echo [FAIL] makerom failed
    echo %date% - %time:~0,-3% = [^^!] makerom failed for !typeLabel! CIA [!TitleId! v!titleVer!] >> "!logfile!"
    type bin\makerom_error.txt >> "!logfile!"
    del bin\makerom_error.txt >nul 2>&1
    set /a failedCIA+=1
    exit /b 1
)

:: Clean error log if successful
if exist "bin\makerom_error.txt" del "bin\makerom_error.txt" >nul 2>&1

:: Check result
if exist "!finalCIA!" (
    if "!autoMode!"=="0" echo [ OK ] !finalCIA! created
    echo %date% - %time:~0,-3% = [i] Decrypting succeeded [!TitleId! v!titleVer!] >> "!logfile!"
    
    :: Convert to CCI if requested
    if "!convertToCCI!"=="1" (
        call :convertCIAtoCCI "!finalCIA!" "!baseName! !typeLabel!!suffix!" "!typeLabel!"
    ) else (
        set /a successCIA+=1
        set /a finalCount+=1
    )
) else (
    if "!autoMode!"=="0" echo [FAIL] Decryption failed
    echo %date% - %time:~0,-3% = [^^!] Decrypting failed [!TitleId! v!titleVer!] >> "!logfile!"
    set /a failedCIA+=1
)

exit /b 0

:: ============================================================================
:: FUNCTION: Process TWL Title
:: ============================================================================
:processTWLTitle
set "inputPath=%~1"
set "baseName=%~2"
set "outputPath=%~3"
set "titleId=%~4"
set "titleVer=%~5"

:: Check for TWL using category detection
set "TWLCheck=!titleId:~0,5!"
if not "!TWLCheck!"=="00048" exit /b 0

:: Log TWL title type
call :logTWLType "!titleId!" "!baseName!" "!titleVer!"

:: Extract TWL content using ctrtool
bin\ctrtool.exe --contents=bin\00000000.app --meta=bin\00000000.app "%inputPath%" >nul 2>&1

:: Rename extracted file
if exist "bin\00000000.app.0000.00000000" (
    ren "bin\00000000.app.0000.00000000" "00000000.app" >nul 2>&1
)

:: Build TWL CIA
if exist "bin\00000000.app" (
    if "!autoMode!"=="0" echo [BUILD] Creating TWL CIA...
    echo %date% - %time:~0,-3% = [i] Calling makerom for TWL CIA [!titleId! v!titleVer!] >> "!logfile!"
    
    set "finalCIA=!baseName! TWL!suffix!.cia"
    
    :: Capture makerom errors
    "!MakeROM!" -srl "bin\00000000.app" -f cia -ignoresign -target p -o "!finalCIA!" -ver !titleVer! >nul 2>bin\makerom_error.txt
    
    :: Clean temp file
    if exist "bin\00000000.app" del "bin\00000000.app" >nul 2>&1
    
    :: Check result
    if !errorlevel! neq 0 (
        if "!autoMode!"=="0" echo [FAIL] TWL makerom failed
        echo %date% - %time:~0,-3% = [^^!] TWL makerom failed [!titleId! v!titleVer!] >> "!logfile!"
        type bin\makerom_error.txt >> "!logfile!"
        del bin\makerom_error.txt >nul 2>&1
        set /a failedCIA+=1
        exit /b 1
    )
    
    if exist "bin\makerom_error.txt" del "bin\makerom_error.txt" >nul 2>&1
    
    if exist "!finalCIA!" (
        if "!autoMode!"=="0" echo [ OK ] !finalCIA! created (TWL)
        echo %date% - %time:~0,-3% = [i] Decrypting succeeded [!titleId! v!titleVer!] >> "!logfile!"
        set /a successCIA+=1
        set /a finalCount+=1
    ) else (
        if "!autoMode!"=="0" echo [FAIL] TWL decryption failed
        echo %date% - %time:~0,-3% = [^^!] Decrypting failed [!titleId! v!titleVer!] >> "!logfile!"
        set /a failedCIA+=1
    )
) else (
    if "!autoMode!"=="0" echo [FAIL] Could not extract TWL content
    echo %date% - %time:~0,-3% = [^^!] Could not extract TWL content [!titleId! v!titleVer!] >> "!logfile!"
    set /a failedCIA+=1
)

exit /b 0

:: ============================================================================
:: FUNCTION: Convert Existing CIA to CCI
:: ============================================================================
:convertExistingCIAtoCCI
set "baseName=%~1"

:: Find the decrypted CIA file
for %%a in ("!baseName!*!suffix!.cia") do (
    set "ciaFile=%%~nxa"
    set "ciaName=%%~na"
    
    :: Analyze to get Title ID
    bin\ctrtool.exe --seeddb=bin\seeddb.bin "!ciaFile!" >"!content!" 2>&1
    
    :: Extract Title ID correctly
    for /f "tokens=2 delims=: " %%x in ('findstr /c:"Title id:" "!content!"') do (
        set "TitleId=%%x"
        set "TitleId=!TitleId: =!"
    )
    for /f "tokens=3 delims= " %%z in ('findstr /c:"Title version:" "!content!"') do set "TitleVersion=%%z"
    
    call :convertCIAtoCCI "!ciaFile!" "!ciaName!" ""
)

exit /b 0

:: ============================================================================
:: FUNCTION: Convert CIA to CCI
:: ============================================================================
:convertCIAtoCCI
set "ciaPath=%~1"
set "baseName=%~2"
set "typeLabel=%~3"

:: Extract category from Title ID for checking
set "Category=!TitleId:~4,4!"

:: Check if conversion is supported (games only - category 0000)
if not "!Category!"=="0000" (
    :: Title type doesn't support CCI conversion
    if "!autoMode!"=="0" echo [ OK ] !ciaPath! created (CCI not supported)
    echo %date% - %time:~0,-3% = [~] Converting to CCI for this title is not supported [!TitleId! v!TitleVersion!] >> "!logfile!"
    set /a successCIA+=1
    set /a finalCount+=1
    exit /b 0
)

:: Convert to CCI
set "cciPath=!baseName!.cci"
if "!autoMode!"=="0" echo [CONVERT] Creating CCI...
echo %date% - %time:~0,-3% = [i] Converting to CCI [!ciaPath!] >> "!logfile!"

:: Capture makerom errors
"!MakeROM!" -ciatocci "!ciaPath!" -o "!cciPath!" >nul 2>bin\makerom_error.txt

if !errorlevel! neq 0 (
    if "!autoMode!"=="0" echo [ OK ] !ciaPath! created (CCI conversion failed)
    echo %date% - %time:~0,-3% = [^^!] Converting to CCI failed [!ciaPath!] >> "!logfile!"
    type bin\makerom_error.txt >> "!logfile!"
    del bin\makerom_error.txt >nul 2>&1
    set /a successCIA+=1
    set /a finalCount+=1
    exit /b 0
)

if exist "bin\makerom_error.txt" del "bin\makerom_error.txt" >nul 2>&1

if exist "!cciPath!" (
    :: Delete source CIA after successful conversion
    del "!ciaPath!" >nul 2>&1
    if "!autoMode!"=="0" echo [ OK ] !cciPath! created
    echo %date% - %time:~0,-3% = [i] Converting to CCI succeeded [!cciPath!] >> "!logfile!"
    set /a successCIA+=1
    set /a finalCount+=1
) else (
    if "!autoMode!"=="0" echo [ OK ] !ciaPath! created (CCI conversion failed)
    echo %date% - %time:~0,-3% = [^^!] Converting to CCI failed [!ciaPath!] >> "!logfile!"
    set /a successCIA+=1
    set /a finalCount+=1
)

exit /b 0

:: ============================================================================
:: FUNCTION: Log CIA System Type
:: ============================================================================
:logCIASystemType
set "checkId=%~1"
set "fileName=%~2"
set "version=%~3"

set "Category=!checkId:~4,4!"

if /i "!Category!"=="0010" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system application >> "!logfile!"
if /i "!Category!"=="001b" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system data archive >> "!logfile!"
if /i "!Category!"=="00db" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system data archive >> "!logfile!"
if /i "!Category!"=="0030" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system applet >> "!logfile!"
if /i "!Category!"=="009b" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a shared data archive >> "!logfile!"
if /i "!Category!"=="0130" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system module >> "!logfile!"
if /i "!Category!"=="0138" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a system firmware >> "!logfile!"

exit /b 0

:: ============================================================================
:: FUNCTION: Log TWL Type
:: ============================================================================
:logTWLType
set "checkId=%~1"
set "fileName=%~2"
set "version=%~3"

set "Category=!checkId:~4,4!"

if /i "!Category!"=="8005" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a TWL title [System Application] >> "!logfile!"
if /i "!Category!"=="800f" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a TWL title [System Data Archive] >> "!logfile!"
if /i "!Category!"=="8004" echo %date% - %time:~0,-3% = [i] CIA file "!fileName!" [!checkId! v!version!] is a TWL title [3DS DSiWare Ports] >> "!logfile!"

exit /b 0

:: ============================================================================
:: FUNCTION: Show Progress Bar
:: ============================================================================
:showProgressBar
set "current=%~1"
set "total=%~2"

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
echo  File !current! of !total!
echo  ================================================================

exit /b 0

:: ============================================================================
:: FUNCTION: Check Golf Title (Satoru Iwata Tribute)
:: ============================================================================
:checkGolfTitle
set "checkTitleId=%~1"

if "!autoMode!"=="1" exit /b 0

:: Check for Golf game titles
:: 0004000000042D00 = Golf (USA)
:: 0004000000042B00 = Golf (EUR)
:: 0004000000181B00 = Golf (JPN)
if /i "!checkTitleId!"=="0004000000042d00" call :showGolfTribute
if /i "!checkTitleId!"=="0004000000042b00" call :showGolfTribute
if /i "!checkTitleId!"=="0004000000181b00" call :showGolfTribute

exit /b 0

:: ============================================================================
:: FUNCTION: Show Golf Tribute
:: ============================================================================
:showGolfTribute
if "!golfEvent!"=="1" exit /b 0

cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo.
echo         ######      ######    ##          ##########
echo       ##########  ##########  ##          ##########
echo       ##      ##  ##      ##  ##          ##
echo       ##          ##      ##  ##          ########
echo       ##    ####  ##      ##  ##          ########
echo       ##      ##  ##      ##  ##          ##
echo       ##########  ##########  ##########  ##
echo         ########    ######    ##########  ##
echo.
echo.
echo   "On my business card, I am a corporate president.
echo    In my mind, I am a game developer. But in my heart,
echo    I am a gamer."
echo.
echo                          - Satoru Iwata [1959 - 2015]
echo.
echo.
timeout /t 5 >nul
set "golfEvent=1"

:: Return to decrypting screen
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo Decrypting...
echo.

exit /b 0

:: ============================================================================
:: FUNCTION: Show Results
:: ============================================================================
:showResults
cls
echo ================================================================
echo   DECRYPTION COMPLETE
echo ================================================================
echo.

:: Calculate totals
set /a totalSuccess=success3DS+successCIA
set /a totalFailed=failed3DS+failedCIA
set /a totalSkipped=skipped3DS+skippedCIA

echo  Success: %totalSuccess%  ^|  Failed: %totalFailed%  ^|  Skipped: %totalSkipped%
echo.
echo ================================================================

if %totalSuccess% GTR 0 (
    echo.
    echo  [SUCCESS] %totalSuccess% file^(s^) decrypted^^!
    echo.
    
    if %success3DS% GTR 0 (
        echo  3DS/CCI Files: %success3DS% decrypted
        if "!convert3DStoCIA!"=="1" (
            echo    Format: CIA ^(installable^)
        ) else (
            echo    Format: CCI ^(cartridge^)
        )
    )
    
    if %successCIA% GTR 0 (
        echo  CIA Files: %successCIA% decrypted
        if "!convertToCCI!"=="1" (
            echo    Format: CCI ^(where supported^)
        ) else (
            echo    Format: CIA ^(installable^)
        )
    )
)

if %totalFailed% GTR 0 (
    echo.
    echo  [ERROR] %totalFailed% file^(s^) failed
    if %failed3DS% GTR 0 echo    3DS/CCI Files: %failed3DS% failed
    if %failedCIA% GTR 0 echo    CIA Files: %failedCIA% failed
    echo.
    echo  Check log: !logfile!
)

if %totalSkipped% GTR 0 (
    echo.
    echo  [INFO] %totalSkipped% file^(s^) skipped
    if %skipped3DS% GTR 0 echo    3DS/CCI Files: %skipped3DS% skipped
    if %skippedCIA% GTR 0 echo    CIA Files: %skippedCIA% skipped
    echo.
    echo  Reasons: Already decrypted or output exists
)

echo.
echo ================================================================
echo.
echo Log file: !logfile!
echo.

echo %date% - %time:~0,-3% = [i] Decryption process completed. Success: %totalSuccess%, Failed: %totalFailed%, Skipped: %totalSkipped% >> "!logfile!"
echo %date% - %time:~0,-3% = [i] Script execution ended >> "!logfile!"

if "!autoMode!"=="0" (
    pause
) else (
    timeout /t 3 >nul
)

exit /b 0

:: ============================================================================
:: CLEANUP AND EXIT
:: ============================================================================
:cleanup
:: Clean any remaining temp files
for %%a in (bin\*.ncch) do del "%%a" >nul 2>&1
if exist "!content!" del "!content!" >nul 2>&1
if exist "bin\makerom_error.txt" del "bin\makerom_error.txt" >nul 2>&1
if exist "bin\temp_decrypt.3ds" del "bin\temp_decrypt.3ds" >nul 2>&1
if exist "bin\temp_decrypt.cia" del "bin\temp_decrypt.cia" >nul 2>&1

endlocal
exit /b 0

:: ============================================================================
:: ERROR HANDLER: No Files Found
:: ============================================================================
:noFiles
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo No CIA or 3DS files found^^!
echo.
if "!addDecryptedSuffix!"=="1" (
    echo NOTE: Files with "!suffix!" suffix are skipped.
    echo.
)
echo Please review "!logfile!" for more details.
echo.
echo ================================================================
echo.
echo %date% - %time:~0,-3% = [~] No CIA or 3DS files found >> "!logfile!"
echo %date% - %time:~0,-3% = [i] Script execution ended >> "!logfile!"
pause
endlocal
exit

:: ============================================================================
:: ERROR HANDLER: Missing Tools
:: ============================================================================
:missingTools
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo [ERROR] Missing Required Files
echo.
echo REQUIRED tools in bin folder:
echo.
if not exist "bin\decrypt.exe" echo   [MISSING] decrypt.exe
if not exist "bin\makerom.exe" if not exist "bin\makerom_x86.exe" echo   [MISSING] makerom.exe
if not exist "bin\ctrtool.exe" echo   [MISSING] ctrtool.exe
echo.
echo OPTIONAL but RECOMMENDED:
echo.
if not exist "bin\seeddb.bin" (
    echo   [MISSING] seeddb.bin
    echo             Required for seed-encrypted games ^(newer titles^)
    echo             Download: https://github.com/matiffeder/3ds/
    echo.
)
echo.
echo Download required tools from:
echo   https://github.com/3DSGuy/Project_CTR/releases
echo.
echo Installation:
echo   1. Extract all tools
echo   2. Place in: %cd%\bin\
echo   3. Restart this script
echo.
echo ================================================================
echo.
echo %date% - %time:~0,-3% = [^^!] Missing required tools >> "!logfile!"
echo %date% - %time:~0,-3% = [i] Script execution ended >> "!logfile!"
pause
endlocal
exit

:: ============================================================================
:: ERROR HANDLER: Unsupported System
:: ============================================================================
:unsupported
cls
echo ================================================================
echo   Batch CIA 3DS Decryptor Redux !Version!
echo ================================================================
echo.
echo [ERROR] Unsupported Operating System
echo.
echo The current operating system is incompatible.
echo Please run the script on the following systems:
echo.
echo   - Windows 7 SP1 [x64] or higher
echo   - Windows Server 2008 R2 SP1 [x64] or higher
echo.
echo Script execution halted^^!
echo.
echo ================================================================
echo.
echo %date% - %time:~0,-3% = [^^!] 32-bit or unsupported OS detected >> "!logfile!"
echo %date% - %time:~0,-3% = [i] Script execution ended >> "!logfile!"
pause
endlocal
exit