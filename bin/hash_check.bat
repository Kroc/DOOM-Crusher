@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # hash_check.bat
REM ====================================================================================================================
REM # check if a file hash is listed in hashes.txt
REM #
REM # 	%1 - optional suffix for "hashes.txt", allowing you to separate hash sets, e.g. "hashes_png.txt"
REM # 	%2 - filepath of file to check the hash of in hashes.txt

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
	ECHO hash_check.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     hash_check.bat [suffix] ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Hashes a file using SHA256 and checks for presence of the hash in
	ECHO     "hashes.txt". If present returns ERRORLEVEL 0, otherwise ERRORLEVEL 1.
	ECHO:
	EXIT /B 0
)

REM # cache directory
SET "CACHEDIR=%HERE%\cache"
REM # if it doesn't exist create it
IF NOT EXIST "%CACHEDIR%" (
	MKDIR "%CACHEDIR%"  >NUL 2>&1
	REM # there's no cache to check!
	EXIT /B 1
)

REM # detect 32-bit or 64-bit Windows
SET "WINBIT=32"
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET "WINBIT=64"	& REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET "WINBIT=64"	& REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET "WINBIT=64"	& REM # 32-bit CMD on a 64-bit system (WOW64)

REM # sha256deep:
IF "%WINBIT%" == "64" SET BIN_HASH="%HERE%\md5deep\sha256deep64.exe"
IF "%WINBIT%" == "32" SET BIN_HASH="%HERE%\md5deep\sha256deep.exe"

REM # has a suffix been specified?
IF "%~2" == "" (
	REM # cacnonical location of the hash-cache
	SET HASHFILE="%CACHEDIR%\hashes.txt"
	SET "FILE=%~f1"
	SET "NAME=%~nx1"
) ELSE (
	SET HASHFILE="%CACHEDIR%\hashes_%~1.txt"
	SET "FILE=%~f2"
	SET "NAME=%~nx2"
)

REM # if there is no hash file we can leave now
IF NOT EXIST %HASHFILE% EXIT /B 1

REM # check if the same file name is found in the hashes:
REM # (use of quotes in a FOR command here is fraught with complications:
REM #  http://stackoverflow.com/questions/22636308)
FOR /F "eol=* tokens=* delims=" %%A IN ('^" %BIN_HASH% -m %HASHFILE% -b "%FILE%" ^"') DO (
	IF /I "%%A" == "%NAME%" EXIT /B 0
)
EXIT /B 1