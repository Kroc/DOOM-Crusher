@ECHO OFF & SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM # optimize_pk3.bat
REM ====================================================================================================================
REM # optimizes a PK3 (DOOM WAD) file. This is a zip-file containing DOOM resources.

REM # %1 - filepath to a PK3 file

REM --------------------------------------------------------------------------------------------------------------------
CALL :init

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"
SET "DO_WAD=1"
SET "ZSTORE=0"
SET "USE_CACHE=1"
REM # if PNG/JPG/WAD files are being skipped but this PK3 doesn't
REM # contain any then we can still add the PK3 to the cache
SET "ANY_PNG=0"
SET "ANY_JPG=0"
SET "ANY_WAD=0"
REM # if the PK3 optimisation or optimisation of internal WAD/JPG/PNG files fail we do *not* add
REM # the PK3 to the cache so that it will always be retried in the future until there are no errors
REM # (we do not want to write off a PK3 as "done" when there are potential savings remaining)
SET "ERROR=0"

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_pk3.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_pk3.bat [options] ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a PK3 file without any reduction in quality.
	ECHO     This includes PNG, JPG and WAD optimization.
	ECHO:
	ECHO     "options" can be any of:
	ECHO:	 
	ECHO     /NOPNG  : Skip processing PNG files
	ECHO     /NOJPG  : Skip processing JPG files
	ECHO     /NOWAD  : Skip processing WAD files
	ECHO:
	ECHO     /ZSTORE : Use no compression when re-packing PK3s.
	ECHO               Whilst the PK3 file will be larger than before,
	ECHO               it will boot faster.
	ECHO:
	ECHO               If you are compressing a number of PK3s together,
	ECHO               then using /ZSTORE on them might drastically improve
	ECHO               the final size of .7Z and .RAR archives when using
	ECHO               a very large dictionary size ^(256 MB or more^).
	EXIT /B 0
)

:options
REM --------------------------------------------------------------------------------------------------------------------
REM # use "/NOPNG" to disable PNG processing (the slowest part)
IF /I "%~1" == "/NOPNG" (
	REM # turn off PNG processing
	SET "DO_PNG=0"
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOJPG" to disable JPEG processing
IF /I "%~1" == "/NOJPG" (
	REM # turn off JPEG processing
	SET "DO_JPG=0"
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOWAD" to disable WAD processing
IF /I "%~1" == "/NOWAD" (
	REM # turn off WAD processing
	SET "DO_WAD=0"
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/ZSTORE" to disable compression of the PK3 file
IF /I "%~1" == "/ZSTORE" (
	REM # enable the relevant flag
	SET "ZSTORE=1"
	REM # check for more options
	SHIFT & GOTO :options
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
REM # absolute path of the PK3 file
SET "PK3_FILE=%~f1"

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

REM # display file name and current file size before optimisation
CALL :display_status_left "%~f1"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
REM # hashing commands:
SET HASH_TRY="%HERE%\hash_check.bat"
SET HASH_ADD="%HERE%\hash_add.bat"
REM # if storing PK3 files uncompressed, use a different hash file so that we can easily identify PK3 files that
REM # may have been crushed before with maximum compression, but which will need to be repacked without compression
IF %ZSTORE% EQU 1 (
	SET HASH_TRY=%HASH_TRY% "pk3_zstore"
	SET HASH_ADD=%HASH_ADD% "pk3_zstore"
) ELSE (
	REM # normal file for PK3 file hashes
	SET HASH_TRY=%HASH_TRY% "pk3"
	SET HASH_ADD=%HASH_ADD% "pk3"
)

REM # check the file in the hash-cache
CALL %HASH_TRY% "%PK3_FILE%"
REM # if the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	CALL :display_status_msg ": skipped (cache)"
	EXIT /B 0
)

REM # clean up any previous attempt
REM --------------------------------------------------------------------------------------------------------------------
REM # temporary folder used to extract the PK3/WAD
REM # TODO: potential clash with more than one instance of doom-crusher running?
SET "TEMP_DIR=%TEMP%\%~nx1"
REM # temporary file used during repacking;
REM # this must use a ZIP extension or 7ZIP borks
SET "TEMP_FILE=%TEMP_DIR%\%~n1.zip"

REM # remove the zip file created when repacking -- we do not want to "update" this file
IF EXIST "%TEMP_FILE%" (
	REM # try remove the file
	DEL /F "%TEMP_FILE%"  >NUL 2>&1
	REM # if that failed:
	IF !ERRORLEVEL! GEQ 1 (
		CALL :display_status_msg "^! error <del>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not remove file:"
		CALL %LOG_ECHO% "%TEMP_FILE%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

REM # remove the temporary directory where the PK3 was unpacked to
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" (
	REM # attempt a second time, this is intentional:
	REM # http://stackoverflow.com/questions/22948189/batch-getting-the-directory-is-not-empty-on-rmdir-command
	RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	REM # could not clean up?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "^! error <rmdir>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not remove directory:"
		CALL %LOG_ECHO% "%TEMP_DIR%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

REM # create the temporary directory
IF NOT EXIST "%TEMP_DIR%" (
	REM # try create the directory
	MKDIR "%TEMP_DIR%"  >NUL 2>&1
	REM # failed?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "^! error <mkdir>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not create directory:"
		CALL %LOG_ECHO% "%TEMP_DIR%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

REM # unpack PK3:
REM --------------------------------------------------------------------------------------------------------------------
REM # display something on the console to indicate what's happening
SET "STATUS_LEFT=%STATUS_LEFT%: unpacking... "
<NUL (SET /P "$=: unpacking... ")

%BIN_7ZA% x -aos -o"%TEMP_DIR%" -tzip -- "%PK3_FILE%"  >NUL 2>&1

IF ERRORLEVEL 1 (
	REM # cap the status line
	CALL :display_status_msg "err^!"
	CALL %LOG_ECHO% "==============================================================================="
	
	%BIN_7ZA% x -aos -o"%TEMP_DIR%" -tzip -- "%PK3_FILE%"
	
	REM # clean up the temporary directory
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	
	REM # quit with error level set
	EXIT /B 1
) ELSE (
	REM # cap the status line to say that the unpacked succeeded
	REM # (not actually an error)
	CALL :display_status_msg "done"
	REM # underscore the PK3 to show we're exploring the contents
	CALL %LOG_ECHO% "  ============================================================================="
)

REM --------------------------------------------------------------------------------------------------------------------

REM # find all optimizable files:
REM # (you can't use variables in the `FOR /R` parameter)
PUSHD "%TEMP_DIR%"

FOR /R "." %%Z IN (*.jpg;*.jpeg;*.png;*.wad;*.) DO (
	REM # JPEG files:
	IF /I "%%~xZ" == ".jpg" (
		REM # if JPG optimisation is enabled, process the file
		IF %DO_JPG% EQU 1 (
			CALL %OPTIMIZE_JPG% "%%~fZ"
			REM # if that errored we won't cache the PK3
			SET "ERROR=!ERRORLEVEL!"
		)
		REM # mark the PK3 as containing at least one JPG file;
		REM # this will prevent the PK3 file being cached if JPG files are being skipped
		SET "ANY_JPG=1"
	)
	IF /I "%%~xZ" == ".jpeg" (
		IF %DO_JPG% EQU 1 (
			CALL %OPTIMIZE_JPG% "%%~fZ"
			SET "ERROR=!ERRORLEVEL!"
		)
		SET "ANY_JPG=1"
	)
	REM # PNG files:
	IF /I "%%~xZ" == ".png" (
		REM # if PNG optimisation is enabled, process the file
		IF %DO_PNG% EQU 1 (
			CALL %OPTIMIZE_PNG% "%%~fZ"
			REM # if that errored we won't cache the PK3
			SET "ERROR=!ERRORLEVEL!"
		)
		REM # mark the PK3 as containing at least one PNG file;
		REM # this will prevent the PK3 file being cached if JPG files are being skipped
		SET "ANY_PNG=1"
	)
	REM # WAD files:
	IF /I "%%~xZ" == ".wad" (
		REM # if WAD optimisation is enabled, process the file
		IF %DO_WAD% EQU 1 (
			CALL %OPTIMIZE_WAD% "%%~fZ"
			REM # if that errored we won't cache the PK3
			SET "ERROR=!ERRORLEVEL!"
		)
		REM # mark the PK3 as containing at least one WAD file;
		REM # this will prevent the PK3 file being cached if WAD files are being skipped
		SET "ANY_WAD=1"
	)
	REM # files without an extension:
	IF "%%~xZ" == "" (
		REM # READ the first 1021 bytes of the lump.
		REM # a truly brilliant solution, thanks to:
		REM # http://stackoverflow.com/a/7827243
		SET "HEADER=" & SET /P HEADER=< "%%~fZ"
		
		REM # a JPEG file?
		REM # IMPORTANT: these bytes are "0xFF,0xD8"
		IF "!HEADER:~0,2!" == "ÿØ" (
			REM # if JPG optimisation is enabled, process the file
			IF %DO_JPG% EQU 1 (
				CALL %OPTIMIZE_JPG% "%%~fZ"
				REM # if that errored we won't cache the PK3
				SET "ERROR=!ERRORLEVEL!"
			)
			REM # mark the PK3 as containing at least one JPG file;
			REM # this will prevent the PK3 file being cached if JPG files are being skipped
			SET "ANY_JPG=1"
		)
		REM # a PNG file?
		IF "!HEADER:~1,3!" == "PNG" (
			REM # if PNG optimisation is enabled, process the file
			IF %DO_PNG% EQU 1 (
				CALL %OPTIMIZE_PNG% "%%~fZ"
				REM # if that errored we won't cache the PK3
				SET "ERROR=!ERRORLEVEL!"
			)
			REM # mark the PK3 as containing at least one PNG file;
			REM # this will prevent the PK3 file being cached if PNG files are being skipped
			SET "ANY_PNG=1"
		)
		REM # a WAD file?
		IF "!HEADER:~1,3!" == "WAD" (
			REM # if WAD optimisation is enabled, process the file
			IF %DO_WAD% EQU 1 (
				CALL %OPTIMIZE_WAD% "%%~fZ"
				REM # if that errored we won't cache the PK3
				SET "ERROR=!ERRORLEVEL!"
			)
			REM # mark the PK3 as containing at least one WAD file;
			REM # this will prevent the PK3 file being cached if WAD files are being skipped
			SET "ANY_WAD=1"
		)
	)
)
REM # finished with the PK3 file contents
CALL %LOG_ECHO% "  ============================================================================="
POPD


REM # repack PK3:
REM ====================================================================================================================
REM # switch to the temporary directory so that the PK3 files are
REM # at the base of the ZIP file rather than in a sub-folder
PUSHD "%TEMP_DIR%"

REM # are we using compression or not?
REM # PRO TIP: a PK3 file made without compression will boot faster in your DOOM engine of choice,
REM # and will aid compression of multiple PK3s together in 7Zip / WinRAR when using a large (256+MB) dictionary
IF %ZSTORE% EQU 1 (
	REM # use no compression
	SET REPACK_PK3=%BIN_7ZA% a "%TEMP_FILE%" -bso0 -bsp1 -bse0 -tzip -r -mx0 -- *
) ELSE (
	REM # use maximum compression
	SET REPACK_PK3=%BIN_7ZA% a "%TEMP_FILE%" -bso0 -bsp1 -bse0 -tzip -r -mx9 -mfb258 -mpass15 -- *
)

%REPACK_PK3%
IF ERRORLEVEL 1 (
	CALL %LOG_ECHO%
	CALL %LOG_ECHO% "ERROR: Could not repack the PK3."
	CALL %LOG_ECHO%
	
	%REPACK_PK3%
	
	POPD
	EXIT /B 1
)

REM # display the original file size before replacing with the new one
CALL :display_status_left "%PK3_FILE%"

REM # replace the original PK3 file with the new one
COPY /Y "%TEMP_FILE%" "%PK3_FILE%"  >NUL 2>&1
IF ERRORLEVEL 1 (
	CALL :display_status_msg "^! error <copy>"
	CALL %LOG_ECHO%
	CALL %LOG_ECHO% "ERROR: Could not replace the original PK3 with the new version."
	CALL %LOG_ECHO%
	POPD
	EXIT /B 1
)

REM # deflopt the PK3:
REM --------------------------------------------------------------------------------------------------------------------
REM # no need to deflopt the PK3 if it's uncompressed!
IF %ZSTORE% EQU 0 (
	REM # deflopt location
	SET "BIN_DEFLOPT=%HERE%\deflopt\DeflOpt.exe"
	REM # running deflopt can shave a few more bytes off of any DEFLATE-based content
	"%BIN_DEFLOPT%" /a "%PK3_FILE%"  >NUL 2>&1
	REM # if that errored we won't cache the PK3
	SET "ERROR=!ERRORLEVEL!"
)

REM # cap the status line with the new file size
CALL :display_status_right "%PK3_FILE%"

REM # add the file to the hash-cache?
IF %ERROR% EQU 1 SET "USE_CACHE=0"
IF %DO_JPG% EQU 0 (
	IF %ANY_JPG% EQU 1 SET "USE_CACHE=0"
)
IF %DO_PNG% EQU 0 (
	IF %ANY_PNG% EQU 1 SET "USE_CACHE=0"
)
IF %DO_WAD% EQU 0 (
	IF %ANY_WAD% EQU 1 SET "USE_CACHE=0"
)
IF %USE_CACHE% EQU 1 CALL %HASH_ADD% "%PK3_FILE%"


REM # clean-up:
REM ====================================================================================================================
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
		CALL %LOG_ECHO% "^! error <rmdir>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not remove directory:"
		CALL %LOG_ECHO% "%TEMP_DIR%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

CALL %LOG_ECHO%
EXIT /B %ERROR%


REM functions:
REM ====================================================================================================================

:init
	REM # path of this script:
	REM # (must be done before using `SHIFT`)
	SET "HERE=%~dp0"
	REM # always remove trailing slash
	IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"
	REM # logging commands:
	SET LOG="%HERE%\log.bat"
	SET LOG_ECHO="%HERE%\log_echo.bat"
	GOTO:EOF

:filesize
	REM # get a file size (in bytes):
	REM # 	%1 = variable name to set
	REM # 	%2 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	SET "%~1=%~z2"
	GOTO:EOF

:display_status_left
	REM # outputs the status line up to the original file's size:
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # prepare the columns for output
	SET "COLS=                                                                               "
	SET "COL1_W=45"
	SET "COL1=!COLS:~0,%COL1_W%!"
	REM # prepare the status line
	SET "LINE=%~nx1%COL1%"
	REM # get the current file size
	CALL :filesize SIZE_OLD "%~1"
	REM # right-align it
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # formulate the line
	SET "STATUS_LEFT=* !LINE:~0,%COL1_W%! %LINE_OLD% "
	REM # output the status line (without carriage-return)
	<NUL (SET /P "$=%STATUS_LEFT%")
	GOTO:EOF

:display_status_right
	REM # assuming that the left-hand status is already displayed,
	REM # append the size-reduction in percentage and new file size,
	REM # and output the complete status line to the log
	REM #
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # get the updated file size
	CALL :filesize SIZE_NEW "%~1"
	REM # if the filesize increased:
	IF %SIZE_NEW% GTR %SIZE_OLD% (
		SET /A "SAVED=100*SIZE_NEW/SIZE_OLD,SAVED-=100"
		SET "SAVED=   !SAVED!"
		SET "SAVED=+!SAVED:~-3!"
	) ELSE (
		IF %SIZE_NEW% EQU %SIZE_OLD% (
			REM # avoid dividing by zero
			SET /A SAVED=0
			SET "SAVED==  0"
		) ELSE (
			SET /A "SAVED=100-100*SIZE_NEW/SIZE_OLD"
			SET "SAVED=   !SAVED!"
			SET "SAVED=-!SAVED:~-3!"
		)
	)
	REM # format & right-align the new file size
	CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
	REM # formulate the line
	SET "STATUS_RIGHT=%SAVED%%% = %LINE_NEW% "
	REM # output the remainder of the status line and log the complete status line
	ECHO %STATUS_RIGHT%
	CALL %LOG% "%STATUS_LEFT%%STATUS_RIGHT%"
	GOTO:EOF
	
:display_status_msg
	REM # append a message to the status line and also output it to the log whole:
	REM # 	%1 = message
	REM ------------------------------------------------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"
	REM # now allow the parameter string to be displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # (note that the status line is displayed in two parts in the console, before and after file optimisation,
	REM #  but needs to be output to the log file as a single line)
	ECHO !ECHO!
	CALL %LOG% "%STATUS_LEFT%!ECHO!"
	ENDLOCAL & GOTO:EOF
	
:format_filesize_bytes
	REM ------------------------------------------------------------------------------------------------------------
	SETLOCAL
	REM # add the thousands separators to the number
	CALL :format_number_thousands RESULT %~2
	REM # right-align the number
	SET "RESULT=           %RESULT%"
	SET "RESULT=%RESULT:~-11%"
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF
	
:format_number_thousands
	REM ------------------------------------------------------------------------------------------------------------
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