@ECHO OFF

REM # doom-cruncher.bat
REM ====================================================================================================================
REM # optimize DOOM-related files: PK3 / WAD / PNG / JPG

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO doom-crusher.bat: v0 - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     Drag-and-drop file^(s^) and/or folder^(s^) onto "doom-crusher.bat".
	ECHO:
	ECHO Methods:
	ECHO: 
	ECHO     JPEG files are optimized, without loss of quality, by "jpegtran".
	ECHO     PNG files are ran through several optimizers: "optipng", "pngout",
	ECHO     "pngcrush" and "deflopt".
	ECHO:
	ECHO     WAD files are first optimized by "wadptr" and then the contents
	ECHO     are optimized as above.
	ECHO:
	ECHO     PK3 files are unpacked and all contents are optimized as above,
	ECHO     then repacked into PK3 using 7Zip.
	ECHO:
	PAUSE & EXIT
)

ECHO:
ECHO doom-crusher.bat
ECHO:

REM # path of this script
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # our component scripts
SET "OPTIMIZE_PK3=%HERE%\bin\optimize_pk3.bat"
SET "OPTIMIZE_WAD=%HERE%\bin\optimize_wad.bat"
SET "OPTIMIZE_PNG=%HERE%\bin\optimize_png.bat"
SET "OPTIMIZE_JPG=%HERE%\bin\optimize_jpg.bat"

REM # process parameter list
REM ====================================================================================================================
:next_param
REM # is this a directory?
SET "ATTR=%~a1"
IF /I "%ATTR:~0,1%" == "d" (
	REM #
)
REM # PK3 file:
IF /I "%~x1" == ".PK3" (
	CALL "%OPTIMIZE_PK3%" "%~1"
	IF ERRORLEVEL 1 GOTO :end
)
REM # WAD file:
IF /I "%~x1" == ".WAD" (
	CALL "%OPTIMIZE_WAD%" "%~1"
	IF ERRORLEVEL 1 GOTO :end
)
REM # PNG file:
IF /I "%~x1" == ".PNG" (
	CALL "%OPTIMIZE_PNG%" "%~1"
	IF ERRORLEVEL 1 GOTO :end
)
REM # JPG file:
IF /I "%~x1" == ".JPG" (
	CALL "%OPTIMIZE_JPG%" "%~1"
	IF ERRORLEVEL 1 GOTO :end
)
IF /I "%~x1" == ".JPEG" (
	CALL "%OPTIMIZE_JPG%" "%~1"
	IF ERRORLEVEL 1 GOTO :end
)

REM # no file extension, or not a known file extension -- examine contents


:end
ECHO:
PAUSE