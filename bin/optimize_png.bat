@ECHO OFF

REM # optimize_png.bat
REM ====================================================================================================================
REM # optimizes a single PNG file

REM # %1 - filepath to a PNG file

REM # path of this script
REM # (do this before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

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

REM # absolute path of the PNG file
SET "PNG_FILE=%~f1"
REM # after optimisation, the PNG file will be added to the cache so it can be skipped in the future
SET "USE_CACHE=1"

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
CALL :status_oldsize "%PNG_FILE%"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
CALL "%HERE%\hash_check.bat" "%PNG_FILE%"
REM # the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	ECHO : skipped ^(cache^)
	EXIT /B 0
)

REM # optipng:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_OPTIPNG%" (
	REM # execute optipng
	%EXEC_OPTIPNG% >NUL 2>&1
	REM # if this fails:
	IF !ERRORLEVEL! NEQ 0 (
		REM # cap the status line
		ECHO ^^!! error ^<optipng^>
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%PNG_FILE%"
		REM # if any of the PNG tools fail, do not add the file to the cache
		SET "USE_CACHE=0"
	)
)

REM # pngout:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_PNGOUT%" (
	REM # execute pngout
	%EXEC_PNGOUT% >NUL 2>&1
	REM # if this fails:
	REM # NOTE: pngout returns 2 for "unable to compress further", technically not an error!
	IF !ERRORLEVEL! EQU 1 (
		REM # cap the status line
		ECHO ^^!! error ^<pngout^>
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%PNG_FILE%"
		REM # if any of the PNG tools fail, do not add the file to the cache
		SET "USE_CACHE=0"
	)
)

REM # pngcrush:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_PNGCRUSH%" (
	REM # execute pngcrush
	%EXEC_PNGCRUSH% >NUL 2>&1
	REM # if this fails:
	IF !ERRORLEVEL! NEQ 0 (
		REM # cap the status line
		ECHO ^^!! error ^<pngcrush^>
		REM # reprint the status line for the next iteration
		CALL :status_oldsize "%PNG_FILE%"
		REM # if any of the PNG tools fail, do not add the file to the cache
		SET "USE_CACHE=0"
	)
)

REM # deflate optimization:
REM --------------------------------------------------------------------------------------------------------------------
IF EXIST "%BIN_DEFLOPT%" (
	REM # execute deflopt
	%EXEC_DEFLOPT% >NUL 2>&1
	REM # if this fails:
	IF !ERRORLEVEL! NEQ 0 (
		REM # cap the status line
		ECHO ^^!! error ^<deflopt^>
		EXIT /B 0
	)
)

REM # add the file to the hash-cache
IF %USE_CACHE% EQU 1 CALL "%HERE%\hash_add.bat" "%PNG_FILE%"

REM # cap status line with the new file size
CALL :status_newsize "%PNG_FILE%"

EXIT /B 0

REM ====================================================================================================================
	
:status_oldsize
	REM # prepare the columns for output
	SET "PNG_COLS=                                                                               "
	SET "PNG_COL1_W=45"
	SET "PNG_COL1=!PNG_COLS:~0,%PNG_COL1_W%!"
	REM # prepare the status line
	SET "PNG_LINE=%~nx1%PNG_COL1%"
	REM # get the current file size
	SET "PNG_SIZE_OLD=%~z1"
	REM # right-align it
	CALL :format_filesize_bytes PNG_LINE_OLD %PNG_SIZE_OLD%
	REM # output the status line (without new line)
	<NUL (SET /P "$=- !PNG_LINE:~0,%PNG_COL1_W%! %PNG_LINE_OLD% ")
	GOTO:EOF

:status_newsize
	SET "PNG_SIZE_NEW=%~z1"
	REM # right-align the number
	CALL :format_filesize_bytes PNG_LINE_NEW %PNG_SIZE_NEW%
	REM # calculate percentage change
	IF "%PNG_SIZE_NEW%" == "%PNG_SIZE_OLD%" (
		SET /A PNG_SAVED=0
	) ELSE (
		SET /A PNG_SAVED=100-100*PNG_SIZE_NEW/PNG_SIZE_OLD
	)
	REM # align and print
	SET "PNG_SAVED=   %PNG_SAVED%%%"
	ECHO - %PNG_SAVED:~-3% = %PNG_LINE_NEW%
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