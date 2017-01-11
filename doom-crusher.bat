@ECHO OFF

REM # doom-crusher.bat : v1.1
REM ====================================================================================================================
REM # optimize DOOM-related files: PK3 / WAD / PNG / JPG

REM # path of this script
REM # (do this before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"

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

REM # any file/folder parameters?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO doom-crusher.bat: v1.1 - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     Drag-and-drop file^(s^) and/or folder^(s^) onto "doom-crusher.bat",
	ECHO     or use from a command-line / batch-file:
	ECHO:
	ECHO         doom-crusher.bat [/NOPNG] [/NOJPG] folder-or-file [...]
	ECHO:
	ECHO     /NOPNG : Skip processing PNG files
	ECHO     /NOJPG : Skip processing JPG files
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
	PAUSE & EXIT /B 0
)

REM ====================================================================================================================
ECHO:
ECHO # doom-crusher : v1.1
ECHO #     feedback : ^<github.com/Kroc/DOOM-Crusher^> or ^<kroc+doom@camendesign.com^>
ECHO ###############################################################################

REM # our component scripts
SET OPTIMIZE_PK3="%HERE%\bin\optimize_pk3.bat"
SET OPTIMIZE_WAD="%HERE%\bin\optimize_wad.bat"
SET OPTIMIZE_PNG="%HERE%\bin\optimize_png.bat"
SET OPTIMIZE_JPG="%HERE%\bin\optimize_jpg.bat"

REM # if we're skipping PNGs/JPGs, pass this requirement on to the PK3/WAD handlers
IF %DO_PNG% EQU 0 (
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /NOPNG
	SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOPNG
)
IF %DO_JPG% EQU 0 (
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /NOJPG
	SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOJPG
)

REM # process parameter list
REM ====================================================================================================================
:process_param
REM # is this a directory?
SET "ATTR=%~a1"
IF /I "%ATTR:~0,1%" == "d" (
	REM # the for loop works most reliably from the directory in question
	PUSHD "%~dp1"
	REM # scan the directory given for crushable files
	FOR /R "." %%Z IN (*.jpg;*.jpeg;*.png;*.wad;*.pk3;*.) DO (
		REM # optimize known file types:
		IF %DO_JPG% EQU 1 (
			IF /I "%%~xZ" == ".JPG"  CALL %OPTIMIZE_JPG% "%%~fZ"
			IF /I "%%~xZ" == ".JPEG" CALL %OPTIMIZE_JPG% "%%~fZ"
		)
		IF %DO_PNG% EQU 1 (
			IF /I "%%~xZ" == ".PNG"  CALL %OPTIMIZE_PNG% "%%~fZ"
		)
		IF /I "%%~xZ" == ".WAD"  CALL %OPTIMIZE_WAD% "%%~fZ"
		IF /I "%%~xZ" == ".PK3"  CALL %OPTIMIZE_PK3% "%%~fZ"
		REM # files without an extension
		IF "%%~xZ" == "" (
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
			IF "!HEADER:~1,3!" == "WAD" CALL %OPTIMIZE_WAD% "%%~fZ"
		)
	)
	REM # put that thing back where it came from, or so help me
	POPD
	REM # don't try process the parameter again
	GOTO :next_param
)
REM # PK3 file:
IF /I "%~x1" == ".PK3" CALL %OPTIMIZE_PK3% "%~f1"
REM # WAD file:
IF /I "%~x1" == ".WAD" CALL %OPTIMIZE_WAD% "%~f1"
REM # PNG file:
IF /I "%~x1" == ".PNG" (
	IF %DO_PNG% EQU 1 CALL %OPTIMIZE_PNG% "%~f1"
)
REM # JPG file:
IF %DO_JPG% EQU 1 (
	IF /I "%~x1" == ".JPG"  CALL %OPTIMIZE_JPG% "%~f1"
	IF /I "%~x1" == ".JPEG" CALL %OPTIMIZE_JPG% "%~f1"
)

REM # no file extension, or not a known file extension? -- examine contents
REM --------------------------------------------------------------------------------------------------------------------
IF "%~x1" == "" (
	REM # READ the first 1021 bytes of the lump.
	REM # a truly brilliant solution, thanks to:
	REM # http://stackoverflow.com/a/7827243
	SET "HEADER=" & SET /P HEADER=< "%~f1"
	REM # a JPEG file?
	IF %DO_JPG% EQU 1 (
		IF "!HEADER:~0,2!" == "ÿØ"  CALL %OPTIMIZE_JPG% "%~f1"
	)
	REM # a PNG file?
	IF %DO_PNG% EQU 1 (
		IF "!HEADER:~1,3!" == "PNG" CALL %OPTIMIZE_PNG% "%~f1"
	)
	REM # a WAD file?
	IF "!HEADER:~1,3!" == "WAD" CALL %OPTIMIZE_WAD% "%~f1"
)


:next_param
REM ====================================================================================================================
REM # is there another parameter?
SHIFT
IF NOT "%~1" == "" (
	ECHO:
	GOTO :process_param
)

ECHO ###############################################################################
ECHO # complete
ECHO:
PAUSE