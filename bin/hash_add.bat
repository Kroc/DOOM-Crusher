@ECHO OFF

REM # hash_add.bat
REM ====================================================================================================================
REM # hash a file and add to the hashes.txt file

REM # %1 - filepath of file to hash

REM # path of this script
REM # (do this before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO hash_add.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     hash_add.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Hashes a file using SHA256 and adds the hash to "hashes.txt"
	ECHO:
	GOTO:EOF
)

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO hash_add.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     hash_add.bat %0
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

REM # check if the same file name is found in the hashes:
IF EXIST %HASHFILE% (
	REM # (use of quotes in a FOR command here is fraught with complications:
	REM #  http://stackoverflow.com/questions/22636308)
	FOR /F "eol=* tokens=* delims=" %%A IN ('^"%BIN_HASH% -m %HASHFILE% -b "%~f1"^"') DO (
		REM # if the file is already in the hash-cache, skip
		IF /I "%%A" == "%~nx1" EXIT /B 0
	)
)

REM # hash the file:
REM # the output of the command is full of problems that make it difficult to parse in Batch,
REM # from padding-spaces to multiple space gaps between columns, we need to normalise it first

REM # sha256deep:
REM # -s	: silent, don't include non-hash text in the output
REM # -q	: no filename

REM # use of quotes in a FOR command here is fraught with complications:
REM # http://stackoverflow.com/questions/22636308
FOR /F "eol=* delims=" %%A IN ('^""%HERE%\md5deep\sha256deep64.exe" -s -q "%~f1"^"') DO @SET "HASH=%%A"
REM # compact multiple spaces into a single colon
SET "HASH=%HASH:  =:%"
SET "HASH=%HASH:::=:%"
SET "HASH=%HASH:::=:%"
REM # now split the columns
FOR /F "eol=* tokens=1-2 delims=:" %%A IN ("%HASH%") DO (
        REM # write the hash to the hash-cache
        ECHO %%A  %~nx1>>%HASHFILE%
)