@ECHO OFF

REM # optimize_pk3.bat
REM ====================================================================================================================
REM # optimizes a PK3 (DOOM WAD) file. This is a zip-file containing DOOM resources.

REM # %1 - filepath to a PK3 file

REM # path of this script
REM # (do this before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"
SET "DO_WAD=1"
SET "USE_CACHE=1"

:options
REM --------------------------------------------------------------------------------------------------------------------
REM # use "/NOPNG" to disable PNG processing (the slowest part)
IF /I "%~1" == "/NOPNG" (
	REM # turn off PNG processing
	SET "DO_PNG=0"
	REM # if PNGs are being skipped, DON'T add the crushed PK3 to the cache!
	SET "USE_CACHE=0"
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOJPG" to disable JPEG processing
IF /I "%~1" == "/NOJPG" (
	REM # turn off JPEG processing
	SET "DO_JPG=0"
	REM # if JPGs are being skipped, DON'T add the crushed PK3 to the cache!
	SET "USE_CACHE=0"
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOWAD" to disable WAD processing
IF /I "%~1" == "/NOWAD" (
	REM # turn off WAD processing
	SET "DO_WAD=0"
	REM # if WADs are being skipped, DON'T add the crushed PK3 to the cache!
	SET "USE_CACHE=0"
	REM # check for more options
	SHIFT & GOTO :options
)

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_pk3.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_pk3.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a PK3 file without any reduction in quality.
	ECHO     This includes PNG, JPG and WAD optimization.
	ECHO:
	GOTO:EOF
)

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO optimize_pk3.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     optimize_pk3.bat %0
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
	EXIT /B 1
)


REM ====================================================================================================================
REM # we cannot get the updated size of the file without just-in-time variable expansion
SETLOCAL ENABLEDELAYEDEXPANSION

REM # absolute path of the PK3 file
SET "PK3_FILE=%~f1"
REM # temporary folder used to extract the PK3/WAD
SET "TEMP_DIR=%TEMP%\%~nx1"
REM # temporary file used during repacking;
REM # this must use a ZIP extension or 7ZIP borks
SET "TEMP_FILE=%TEMP_DIR%\%~n1.zip"

REM # detect 32-bit or 64-bit Windows
SET "WINBIT=32"
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET "WINBIT=64"	& REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET "WINBIT=64"	& REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET "WINBIT=64"	& REM # 32-bit CMD on a 64-bit system (WOW64)

REM # select 7Zip executable
IF "%WINBIT%" == "64" SET BIN_7ZA="%HERE%\7za\7za_x64.exe"
IF "%WINBIT%" == "32" SET BIN_7ZA="%HERE%\7za\7za.exe"

REM # our component scripts
SET OPTIMIZE_WAD="%HERE%\optimize_wad.bat"
SET OPTIMIZE_PNG="%HERE%\optimize_png.bat"
SET OPTIMIZE_JPG="%HERE%\optimize_jpg.bat"

REM # if we're skipping PNGs/JPGs, pass this requirement on to the WAD handler
IF %DO_PNG% EQU 0 SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOPNG
IF %DO_JPG% EQU 0 SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOJPG

REM # display file name and current file size
CALL :status_oldsize "%~f1"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
IF %USE_CACHE% EQU 1 (
	REM # check the file in the hash-cache
	CALL "%HERE%\hash_check.bat" "%PK3_FILE%"
	REM # if the file is in the hash-cache, we can skip it
	IF !ERRORLEVEL! EQU 0 (
		ECHO : skipped ^(cache^)
		EXIT /B 0
	)
)

REM # clean up any previous attempt
REM --------------------------------------------------------------------------------------------------------------------
REM # remove the zip file created when repacking -- we do not want to "update" this file
IF EXIST "%TEMP_FILE%" (
	REM # try remove the file
	DEL /F "%TEMP_FILE%"  >NUL 2>&1
	REM # if that failed:
	IF !ERRORLEVEL! GEQ 1 (
		ECHO ^^!! error ^<del^>
		ECHO ===============================================================================
		ECHO:
		ECHO ERROR: Could not remove file:
		ECHO %TEMP_FILE%
		ECHO:
		EXIT /B 1
	)
)

REM # remove the temporary directory where the PK3 was unpacked to
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%" >NUL 2>&1
IF EXIST "%TEMP_DIR%" (
	REM # attempt a second time, this is intentional:
	REM # http://stackoverflow.com/questions/22948189/batch-getting-the-directory-is-not-empty-on-rmdir-command
	RMDIR /S /Q "%TEMP_DIR%" >NUL 2>&1
	REM # could not clean up?
	IF ERRORLEVEL 1 (
		ECHO ^^!! error ^<rmdir^>
		ECHO ===============================================================================
		ECHO:
		ECHO ERROR: Could not remove directory:
		ECHO %TEMP_DIR%
		ECHO:
		EXIT /B 1
	)
)

REM # create the temporary directory
IF NOT EXIST "%TEMP_DIR%" (
	REM # try create the directory
	MKDIR "%TEMP_DIR%" >NUL 2>&1
	REM # failed?
	IF ERRORLEVEL 1 (
		ECHO ^^!! error ^<mkdir^>
		ECHO ===============================================================================
		ECHO:
		ECHO ERROR: Could not create directory:
		ECHO %TEMP_DIR%
		ECHO:
		EXIT /B 1
	)
)

REM # use 7zip to unpack the PK3 file
REM --------------------------------------------------------------------------------------------------------------------
<NUL (SET /P "$=: unpacking...")
%BIN_7ZA% x -aos -o"%TEMP_DIR%" -tzip -- "%PK3_FILE%" >NUL 2>&1
IF ERRORLEVEL 1 (
	REM # cap the status line
	ECHO  err^^!!
	ECHO ===============================================================================
	REM # retry with output visible
	ECHO:
	%BIN_7ZA% x -aos -o"%TEMP_DIR%" -tzip -- "%PK3_FILE%"
	ECHO:
	REM # clean up the temporary directory
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	REM # quit with error level set
	EXIT /B 1
) ELSE (
	REM # cap the status line to say that the unpacked succeeded
	ECHO  done
	REM # underscore the PK3 to show we're exploring the contents
	ECHO ===============================================================================
)

REM --------------------------------------------------------------------------------------------------------------------

REM # find all optimizable files:
REM # you can't use variables in the `FOR /R` parameter
PUSHD "%TEMP_DIR%"
REM # JPEG files:
IF %DO_JPG% EQU 1 (
	FOR /R "." %%Z IN (*.jpg;*.jpeg) DO CALL %OPTIMIZE_JPG% "%%~fZ"
)
REM # PNG files:
IF %DO_PNG% EQU 1 (
	FOR /R "." %%Z IN (*.png) DO CALL %OPTIMIZE_PNG% "%%~fZ"
)
REM # WAD files:
IF %DO_WAD% EQU 1 (
	FOR /R "." %%Z IN (*.wad) DO CALL %OPTIMIZE_WAD% "%%~fZ"
)
REM # files without an extension:
FOR /R "." %%Z IN (*.) DO (
	REM # READ the first 1021 bytes of the lump.
	REM # a truly brilliant solution, thanks to:
	REM # http://stackoverflow.com/a/7827243
	SET "HEADER=" & SET /P HEADER=< "%%~Z"
	REM # a JPEG file?
	IF %DO_JPG% EQU 1 (
		IF "!HEADER:~0,2!" == "ÿØ"  CALL %OPTIMIZE_JPG% "%%~fZ"
	)
	REM # a PNG file?
	IF %DO_PNG% EQU 1 (
		IF "!HEADER:~1,3!" == "PNG" CALL %OPTIMIZE_PNG% "%%~fZ"
	)
	REM # a WAD file?
	IF %DO_WAD% EQU 1 (
		IF "!HEADER:~1,3!" == "WAD" CALL %OPTIMIZE_WAD% "%%~fZ"
	)
)

POPD

REM # repack PK3:
REM --------------------------------------------------------------------------------------------------------------------
REM # switch to the temporary directory so that the PK3 files are
REM # at the base of the ZIP file rather than in a sub-folder
PUSHD "%TEMP_DIR%"
REM # use 7Zip to do the ZIP compression as it has options to maximize compression
REM %BIN_7ZA% a "%TEMP%\%~n1.zip" -bso0 -bsp1 -tzip -r -mx9 -mfb258 -mpass15 -- *
%BIN_7ZA% a "%TEMP%\%~n1.zip" -bso0 -bsp1 -bse0 -tzip -r -mx0 -- *
IF ERRORLEVEL 1 (
	ECHO:
	ECHO ERROR: Could not repack the PK3.
	ECHO:
	EXIT /B 1
)
COPY /Y "%TEMP%\%~n1.zip" "%PK3_FILE%"  >NUL 2>&1
IF ERRORLEVEL 1 (
	ECHO:
	ECHO ERROR: Could not replace the original PK3 with the new version.
	ECHO:
	EXIT /B 1
)

REM # finished with the PK3 file contents
ECHO ===============================================================================

REM # deflopt the PK3:
REM --------------------------------------------------------------------------------------------------------------------
REM # display the original file size before deflopt
REM # (the new file size will be added to the end)
<NUL (SET /P "$=- %PK3_LINE:~0,45% %PK3_LINE_OLD% ")
REM # deflopt location
SET "BIN_DEFLOPT=%HERE%\deflopt\DeflOpt.exe"
REM # running deflopt can shave a few more bytes off of any DEFLATE-based content
REM # if this failed, just continue, the original won't have been overwritten
"%BIN_DEFLOPT%" /a "%PK3_FILE%"  >NUL 2>&1

REM # clean-up:
REM --------------------------------------------------------------------------------------------------------------------
REM # leave the temporary directory before we delete it
POPD
REM # delete the temp folder
REM # NB: http://stackoverflow.com/questions/22948189/batch-getting-the-directory-is-not-empty-on-rmdir-command
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" (
	REM # attempt a second time, this is intentional:
	REM # http://stackoverflow.com/questions/22948189/batch-getting-the-directory-is-not-empty-on-rmdir-command
	RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	REM # could not clean up?
	IF ERRORLEVEL 1 (
		ECHO ^^!! error ^<rmdir^>
		ECHO ===============================================================================
		ECHO:
		ECHO ERROR: Could not remove directory:
		ECHO %TEMP_DIR%
		ECHO:
		RMDIR /Q "%TEMP_DIR%"
		EXIT /B 1
	)
)

REM # cap the status line with the new file size
CALL :status_newsize "%PK3_FILE%"

REM # add the file to the hash-cache
IF %USE_CACHE% EQU 1 CALL "%HERE%\hash_add.bat" "%WAD_FILE%"

GOTO:EOF

REM ====================================================================================================================

:status_oldsize
	REM # prepare the columns for output
	SET "PK3_COLS=                                                                               "
	SET "PK3_COL1_W=45"
	SET "PK3_COL1=!PK3_COLS:~0,%PK3_COL1_W%!"
	REM # prepare the status line
	SET "PK3_LINE=%~nx1%PK3_COL1%"
	REM # get the current file size
	SET "PK3_SIZE_OLD=%~z1"
	REM # right-align it
	CALL :format_filesize_bytes PK3_LINE_OLD %PK3_SIZE_OLD%
	REM # output the status line (without new line)
	<NUL (SET /P "$=+ !PK3_LINE:~0,%PK3_COL1_W%! %PK3_LINE_OLD% ")
	GOTO:EOF

:status_newsize
	SET "PK3_SIZE_NEW=%~z1"
	REM # right-align the number
	CALL :format_filesize_bytes PK3_LINE_NEW %PK3_SIZE_NEW%
	REM # calculate percentage change
	IF "%PK3_SIZE_NEW%" == "%PK3_SIZE_OLD%" (
		SET /A PK3_SAVED=0
	) ELSE (
		SET /A PK3_SAVED=100-100*PK3_SIZE_NEW/PK3_SIZE_OLD
	)
	REM # align and print
	SET "PK3_SAVED=   %PK3_SAVED%%%"
	ECHO - %PK3_SAVED:~-3% = %PK3_LINE_NEW%
	GOTO:EOF
	
:format_filesize_bytes
	SETLOCAL
	REM # add the thousands separators to the number
	CALL :format_number_thousands RESULT %~2
	REM # right-align the number
	SET "RESULT=           %RESULT%"
	SET "RESULT=%RESULT:~-11%"
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF
	
:format_number_thousands
	SETLOCAL
	SET "RESULT="
	SET "NUMBER=%~2"
	:number_thousands_loop
	SET "RESULT=%NUMBER:~-3%%RESULT%"
	SET "NUMBER=%NUMBER:~0,-3%"
	IF DEFINED NUMBER SET "RESULT=,%RESULT%" & GOTO :number_thousands_loop 
	SET "%~1=%RESULT%" 
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF

:file_size_string
	SET "FILESIZESTRING="
	IF %1 GEQ 1073741824 (SET /A "FILESIZESTRING=%~1/1073741824" && SET "FILESIZESTRING=!FILESIZESTRING! GB" && EXIT /B)
	IF %1 GEQ 1048576 (SET /A "FILESIZESTRING=%~1/1048576" && SET "FILESIZESTRING=!FILESIZESTRING! MB" && EXIT /B)
	IF %1 GEQ 1024 (SET /A "FILESIZESTRING=%~1/1024" && SET "FILESIZESTRING=!FILESIZESTRING! KB" && EXIT /B)
	IF %1 LSS 1024 SET "FILESIZESTRING=%~1 B "
	EXIT /B