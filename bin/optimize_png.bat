@ECHO OFF

REM # optimize_png.bat
REM ====================================================================================================================
REM # optimizes a single PNG file

REM # %1 - filepath to a PNG file

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
	ECHO     optimize_png.bat %0
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

REM # detect 32-bit or 64-bit Windows
SET "WINBIT=32"
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET "WINBIT=64"	& REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET "WINBIT=64"	& REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET "WINBIT=64"	& REM # 32-bit CMD on a 64-bit system (WOW64)

REM # path of this script
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # optipng:
SET "BIN_OPTIPNG=%HERE%\optipng\optipng.exe"
REM # -clobber  : overwrite input file
REM # -07       : maximum compression level
REM # -i0       : non-interlaced
SET EXEC_OPTIPNG="%BIN_OPTIPNG%" -clobber -o7 -i0 -- "%~1"

REM # pngout:
SET "BIN_PNGOUT=%HERE%\pngout\pngout.exe"
REM # /k...	: keep chunks
REM # /y	: assume yes (overwrite)
SET EXEC_PNGOUT="%BIN_PNGOUT%" "%~1" /kgrAb,alPh /y

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
SET EXEC_PNGCRUSH="%BIN_PNGCRUSH%" -nobail -blacken -brute -keep grAb -keep alPh -l 9 -noforce -ow -reduce "%~1"

REM # deflopt
SET "BIN_DEFLOPT=%HERE%\deflopt\DeflOpt.exe"
REM # /k	: keep extra chunks (we must preserve "grAb" and "alPh" for DOOM)
SET EXEC_DEFLOPT="%BIN_DEFLOPT%" /k "%~1"

REM # display file name and current file size
CALL :status_oldsize "%~1"

REM # optipng:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_OPTIPNG%" (
	REM # execute optipng
	%EXEC_OPTIPNG%  >NUL 2>&1
	REM # if this fails do it again so as to show the output
	IF ERRORLEVEL 1 (
		REM # cap the status line
		ECHO ^^!! error ^<optipng^>
		ECHO:
		%EXEC_OPTIPNG%
		ECHO:
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%~1"
	)
)

REM # pngout:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_PNGOUT%" (
	REM # execute pngout
	REM # /q : quiet
	%EXEC_PNGOUT% /q  >NUL 2>&1
	REM # if this fails do it again so as to show the output
	IF %ERRORLEVEL% EQU 1 (
		REM # cap the status line
		ECHO ^^!! error ^<pngout^>
		ECHO:
		REM # /v : verbose
		%EXEC_PNGOUT% /v
		ECHO:
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%~1"
	)
)

REM # pngcrush:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_PNGCRUSH%" (
	REM # execute pngcrush
	%EXEC_PNGCRUSH%  >NUL 2>&1
	REM # if this fails do it again so as to show the output
	IF ERRORLEVEL 1 (
		REM # cap the status line
		ECHO ^^!! error ^<pngcrush^>
		ECHO:
		%EXEC_PNGCRUSH%
		ECHO:
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%~1"
	)
)

REM # deflate optimization:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_DEFLOPT%" (
	REM # execute deflopt
	%EXEC_DEFLOPT%  >NUL 2>&1
	REM # if this fails do it again so as to show the output
	IF ERRORLEVEL 1 (
		REM # cap the status line
		ECHO ^^!! error ^<deflopt^>
		ECHO:
		%EXEC_DEFLOPT%
		ECHO:
		GOTO:EOF
	)
)

REM # cap status line with the new file size
CALL :status_newsize "%~1"

GOTO:EOF

REM ====================================================================================================================

:status_oldsize
	REM # prepare the columns for output
	SET "COLS=                                                                               "
	SET "COL1_W=45"
	SET "COL1=!COLS:~0,%COL1_W%!"
	REM # prepare the status line
	SET "LINE=%~nx1%COL1%"
	REM # get the current file size
	SET "SIZE_OLD=%~z1"
	REM # right-align it
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # output the status line (without new line)
	<NUL (SET /P "$=- !LINE:~0,%COL1_W%! %LINE_OLD% ")
	GOTO:EOF

:status_newsize
	SET "SIZE_NEW=%~z1"
	REM # right-align the number
	CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
	REM # calculate percentage change
	SET /A SAVED=100-100*SIZE_NEW/SIZE_OLD
	SET "SAVED=   %SAVED%%%"
	ECHO - %SAVED:~-3% = %LINE_NEW%
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