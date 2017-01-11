@ECHO OFF

REM # hash_check.bat
REM ====================================================================================================================
REM # check if a file hash is listed in hashes.txt

REM # %1 - filepath of file to check the hash of in hashes.txt

REM # path of this script
REM # (do this before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO hash_check.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     hash_check.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Hashes a file using SHA256 and checks for presence of the hash in
	ECHO     "hashes.txt". If present returns ERRORLEVEL 0, otherwise ERRORLEVEL 1.
	ECHO:
	GOTO:EOF
)

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO hash_check.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     hash_check.bat %0
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
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
REM # cacnonical location of the hash-cache
SET HASHFILE="%HERE%\hashes.txt"

REM # if there is no hash file we can leave now
IF NOT EXIST %HASHFILE% EXIT /B 1

REM # check if the same file name is found in the hashes:
REM # (use of quotes in a FOR command here is fraught with complications:
REM #  http://stackoverflow.com/questions/22636308)
FOR /F "eol=* tokens=* delims=" %%A IN ('^"%BIN_HASH% -m %HASHFILE% -b "%~f1"^"') DO (
	IF /I "%%A" == "%~nx1" EXIT /B 0
)
EXIT /B 1