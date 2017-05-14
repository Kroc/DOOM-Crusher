@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # optimize_png.bat
REM ====================================================================================================================
REM # optimizes a single PNG file
REM #
REM # 	%1 - filepath to a PNG file

REM # init
REM --------------------------------------------------------------------------------------------------------------------
REM # path of this script:
REM # (must be done before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # check for an echo parameter (enables ECHO)
SET "ECHO="
IF /I "%~1" == "/ECHO" (
	REM # the "/ECHO" parameter will be passed to all called scripts too
	SET "ECHO=/ECHO"
	REM # re-enable ECHO
	ECHO ON
	REM # remove the parameter
	SHIFT
)

REM # logging commands:
SET LOG="%HERE%\log.bat" %ECHO%
SET LOG_ECHO="%HERE%\log_echo.bat" %ECHO%


REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_png.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_png.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a PNG file without any reduction in quality.
    	ECHO     Retains the "grAb" and "alPh" chunks specifically for
    	ECHO     compatibility with DOOM engines.
	ECHO:
	GOTO:EOF
)

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO optimize_png.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     optimize_png.bat %*
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
	EXIT /B 1
)

REM ====================================================================================================================
REM # absolute path of the PNG file
SET "PNG_FILE=%~f1"
REM # if any of the PNG passes failed return an error state; if the PNG was from a WAD or PK3 then these
REM # will *not* be cached so that they will always be retried in the future until there are no errors
REM # (we do not want to write off a WAD or PK3 as "done" when there are potential savings remaining)
SET "ERROR=0"

REM --------------------------------------------------------------------------------------------------------------------

REM # detect 32-bit or 64-bit Windows
SET "WINBIT=32"
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET "WINBIT=64"	& REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET "WINBIT=64"	& REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET "WINBIT=64"	& REM # 32-bit CMD on a 64-bit system (WOW64)

REM # optipng:
SET "BIN_OPTIPNG=%HERE%\optipng\optipng.exe"
REM # -clobber  : overwrite input file
REM # -fix	: try to fix/work-around CRC errors
REM # -07       : maximum compression level
REM # -i0       : non-interlaced
SET EXEC_OPTIPNG="%BIN_OPTIPNG%" -clobber -fix -o7 -i0 -- "%PNG_FILE%"

REM # pngout:
SET "BIN_PNGOUT=%HERE%\pngout\pngout.exe"
REM # /k...	: keep chunks
REM # /y	: assume yes (overwrite)
REM # /q	: quiet
SET EXEC_PNGOUT="%BIN_PNGOUT%" "%PNG_FILE%" /kgrAb,alPh /y /q

REM # pngcrush:
IF "%WINBIT%" == "64" SET "BIN_PNGCRUSH=%HERE%\pngcrush\pngcrush_w64.exe"
IF "%WINBIT%" == "32" SET "BIN_PNGCRUSH=%HERE%\pngcrush\pngcrush_w32.exe"
REM # -nobail	: don't stop trials if the filesize hasn't improved (yet)
REM # -blacken  : sets background-color of fully-transparent pixels to 0 (black); aids in compressability
REM # -brute	: tries 148 different methods for maximum compression (slow)
REM # -keep ...	: keep chunks
REM # -l 9	: maximum compression level
REM # -noforce	: make certain not to overwrite smaller file with larger one
REM # -ow	: overwrite the original file
REM # -reduce	: try reducing colour-depth if possible
SET EXEC_PNGCRUSH="%BIN_PNGCRUSH%" -nobail -blacken -brute -keep grAb -keep alPh -l 9 -noforce -ow -reduce "%PNG_FILE%"

REM # deflopt:
SET "BIN_DEFLOPT=%HERE%\deflopt\DeflOpt.exe"
REM # /a	: examine the file contents to determine if it's compressed (rather than extension alone)
REM # /k	: keep extra chunks (we must preserve "grAb" and "alPh" for DOOM)
SET EXEC_DEFLOPT="%BIN_DEFLOPT%" /a /k "%PNG_FILE%"

REM # display file name and current file size
CALL :display_status_left "%PNG_FILE%"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
REM # hashing commands:
SET HASH_TRY="%HERE%\hash_check.bat" %ECHO% "png"
SET HASH_ADD="%HERE%\hash_add.bat" %ECHO% "png"

REM # check the file in the hash-cache
CALL %HASH_TRY% "%PNG_FILE%"
REM # the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	CALL :display_status_msg ": skipped (cache)"
	EXIT /B 0
)

:optipng
REM --------------------------------------------------------------------------------------------------------------------
REM # skip if not present
IF NOT EXIST "%BIN_OPTIPNG%" GOTO :pngout

REM # execute optipng
%EXEC_OPTIPNG%  >NUL 2>&1
REM # if this fails:
IF %ERRORLEVEL% NEQ 0 (
	REM # cap the status line
	CALL :display_status_msg "! error <optipng>"
	REM # reprint the status line for the next iteration
	CALL :display_status_left "%PNG_FILE%"
	REM # if any of the PNG tools fail, do not add the file to the cache
	SET "ERROR=1"
)

:pngout
REM --------------------------------------------------------------------------------------------------------------------
REM # skip if not present
IF NOT EXIST "%BIN_PNGOUT%" GOTO :pngcrush

REM # execute pngout
%EXEC_PNGOUT%  >NUL 2>&1
REM # if this fails:
REM # NOTE: pngout returns 2 for "unable to compress further", technically not an error!
IF %ERRORLEVEL% EQU 1 (
	REM # cap the status line
	CALL :display_status_msg "! error <pngout>"
	REM # reprint the status line for the next iteration
	CALL :display_status_left "%PNG_FILE%"
	REM # if any of the PNG tools fail, do not add the file to the cache
	SET "ERROR=1"
)

:pngcrush
REM --------------------------------------------------------------------------------------------------------------------
REM # skip if not present
IF NOT EXIST "%BIN_PNGCRUSH%" GOTO :deflopt

REM # execute pngcrush
%EXEC_PNGCRUSH%  >NUL 2>&1
REM # if this fails:
IF %ERRORLEVEL% NEQ 0 (
	REM # cap the status line
	CALL :display_status_msg "! error <pngcrush>"
	REM # reprint the status line for the next iteration
	CALL :display_status_left "%PNG_FILE%"
	REM # if any of the PNG tools fail, do not add the file to the cache
	SET "ERROR=1"
)

:deflopt
REM --------------------------------------------------------------------------------------------------------------------
REM # skip if not present
IF NOT EXIST "%BIN_DEFLOPT%" GOTO :finish

REM # execute deflopt
%EXEC_DEFLOPT%  >NUL 2>&1
REM # if this fails:
IF %ERRORLEVEL% NEQ 0 (
	REM # cap the status line
	CALL :display_status_msg "! error <deflopt>"
	REM # exit with error so that any containing PK3/WAD
	REM # is not written off as permenantly "done"
	EXIT /B 1
)

:finish
REM # add the file to the hash-cache
IF %ERROR% EQU 0 CALL %HASH_ADD% "%PNG_FILE%"

REM # cap status line with the new file size
CALL :display_status_right "%PNG_FILE%"

REM # if any of the PNG passes failed return an error state; if the PNG was from a WAD or PK3 then these
REM # will *not* be cached so that they will always be retried in the future until there are no errors
REM # (we do not want to write off a WAD or PK3 as "done" when there are potential savings remaining)
EXIT /B %ERROR%


REM # functions:
REM ====================================================================================================================

:filesize
	REM # get a file size, in bytes:
	REM #
	REM # 	%1 = variable name to set
	REM # 	%2 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	SET "%~1=%~z2"
	GOTO:EOF

:display_status_left
	REM # outputs the status line up to the original file's size:
	REM #
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # get the current file size
	CALL :filesize SIZE_OLD "%~1"
	REM # prepare the status line (column is 45-wide)
	SET "LINE_NAME=%~nx1                                             "
	SET "LINE_NAME=%LINE_NAME:~0,45%"
	REM # right-align the file size
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # formulate the line
	SET "STATUS_LEFT=* %LINE_NAME% %LINE_OLD% "
	REM # output the status line (without carriage-return)
	<NUL (SET /P "STATUS_LEFT=%STATUS_LEFT%")
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
	REM # no change in size?
	IF %SIZE_NEW% EQU %SIZE_OLD% (
		SET "STATUS_RIGHT==  0%% : same size"
		GOTO :display_status_right__echo
	)
	REM # calculate the perctange difference
	CALL "%HERE%\get_percentage.bat" %ECHO% SAVED %SIZE_OLD% %SIZE_NEW%
	SET "SAVED=   %SAVED%"
	REM # increase or decrease in size?
	IF %SIZE_NEW% GTR %SIZE_OLD% SET "SAVED=+%SAVED:~-3%"
	IF %SIZE_NEW% LSS %SIZE_OLD% SET "SAVED=-%SAVED:~-3%"
	REM # format & right-align the new file size
	CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
	REM # formulate the line
	SET "STATUS_RIGHT=%SAVED%%% = %LINE_NEW% "
	
	:display_status_right__echo
	REM # output the remainder of the status line and log the complete status line
	ECHO %STATUS_RIGHT%
	CALL %LOG% "%STATUS_LEFT%%STATUS_RIGHT%"
	GOTO:EOF
	
:display_status_msg
	REM # append a message to the status line and also output it to the log whole:
	REM #
	REM # 	%1 = message
	REM ------------------------------------------------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "TEXT=%~1"
	REM # now allow the parameter string to be displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # (note that the status line is displayed in two parts in the console, before and after file optimisation,
	REM #  but needs to be output to the log file as a single line)
	ECHO !TEXT!
	CALL %LOG% "%STATUS_LEFT%!TEXT!"
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