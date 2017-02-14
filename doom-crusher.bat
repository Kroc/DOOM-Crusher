@ECHO OFF & SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM # doom-crusher.bat : v1.3
REM ====================================================================================================================
REM # optimize DOOM-related files: PK3 / WAD / PNG / JPG

REM # path of this script:
REM # (must be done before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"
REM # logging commands:
SET LOG="%HERE%\bin\log.bat"
SET LOG_ECHO="%HERE%\bin\log_echo.bat"
SET LOG_CLEAR="%HERE%\bin\log_clear.bat"

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"
SET "DO_WAD=1"
SET "DO_PK3=1"
SET "ZSTORE=0"

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
REM # use "/NOPK3" to disable PK3 processing
IF /I "%~1" == "/NOPK3" (
	REM # turn off PK3 processing
	SET "DO_PK3=0"
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

REM # any file/folder parameters?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO doom-crusher.bat: v1.3 - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     Drag-and-drop file^(s^) and/or folder^(s^) onto "doom-crusher.bat",
	ECHO     or use from a command-line / batch-file:
	ECHO:
	ECHO         doom-crusher.bat [options] folder-or-file [...]
	ECHO:
	ECHO     "options" can be any of:
	ECHO:	 
	ECHO     /NOPNG  : Skip processing PNG files
	ECHO     /NOJPG  : Skip processing JPG files
	ECHO     /NOWAD  : Skip processing WAD files
	ECHO     /NOPK3  : Skip processing PK3 files
	ECHO:
	ECHO     /ZSTORE : Use no compression when re-packing PK3s.
	ECHO               Whilst the PK3 file will be larger than before,
	ECHO               it will boot faster.
	ECHO:
	ECHO               If you are compressing a number of PK3s together,
	ECHO               then using /ZSTORE on them might drastically improve
	ECHO               the final size of .7Z and .RAR archives when using
	ECHO               a very large dictionary size ^(256 MB or more^).
	ECHO:
	EXIT /B 0
)

REM ====================================================================================================================
REM # initialize log file
CALL %LOG_CLEAR%

ECHO:
CALL %LOG_ECHO% "# doom-crusher : v1.3"
CALL %LOG_ECHO% "#     feedback : <github.com/Kroc/DOOM-Crusher> or <kroc+doom@camendesign.com>"
REM # display which options have been set
SET "OPTIONS="
IF %DO_PNG% EQU 0 SET "OPTIONS=%OPTIONS%/NOPNG "
IF %DO_JPG% EQU 0 SET "OPTIONS=%OPTIONS%/NOJPG "
IF %DO_WAD% EQU 0 SET "OPTIONS=%OPTIONS%/NOWAD "
IF %DO_PK3% EQU 0 SET "OPTIONS=%OPTIONS%/NOPK3 "
IF %ZSTORE% EQU 1 SET "OPTIONS=%OPTIONS%/ZSTORE"
IF NOT "%OPTIONS%" == "" (
	SET     "OPTIONS=#      options : %OPTIONS%"
	CALL %LOG_ECHO% "!OPTIONS!"
)
CALL %LOG_ECHO% "###############################################################################"

REM # our component scripts:
SET OPTIMIZE_PK3="%HERE%\bin\optimize_pk3.bat"
SET OPTIMIZE_WAD="%HERE%\bin\optimize_wad.bat"
SET OPTIMIZE_PNG="%HERE%\bin\optimize_png.bat"
SET OPTIMIZE_JPG="%HERE%\bin\optimize_jpg.bat"

REM # are we skipping PNGs?
IF %DO_PNG% EQU 0 (
	REM # pass that on to PK3/WAD processing as they may contain PNGs also
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /NOPNG
	SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOPNG
)
REM # are we skipping JPGs?
IF %DO_JPG% EQU 0 (
	REM # pass that on to PK3/WAD processing as they may contain JPGs also
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /NOJPG
	SET OPTIMIZE_WAD=%OPTIMIZE_WAD% /NOJPG
)
REM # are we skipping WADs?
IF %DO_WAD% EQU 0 (
	REM # pass that on to the PK3 processing as they may contain WADs also
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /NOWAD
)
REM # do we want the PK3s uncompressed?
IF %ZSTORE% EQU 1 (
	REM # likewise, pass this requirement on
	SET OPTIMIZE_PK3=%OPTIMIZE_PK3% /ZSTORE
)


REM # process parameter list:
REM ====================================================================================================================
:process_param
REM # is this a directory?
SET "ATTR=%~a1"
IF /I "%ATTR:~0,1%" == "d" (
	REM # the `FOR /R` loop works most reliably from the directory in question
	PUSHD "%~f1"
	REM # scan the directory given for crushable files
	REM # note that "*." is a special term to select all files *without* an extension
	FOR /R "." %%Z IN (*.jpg;*.jpeg;*.png;*.wad;*.pk3;*.lmp;*.) DO (
		REM # optimize known file types:
		IF %DO_JPG% EQU 1 (
			IF /I "%%~xZ" == ".JPG"  CALL %OPTIMIZE_JPG% "%%~fZ"
			IF /I "%%~xZ" == ".JPEG" CALL %OPTIMIZE_JPG% "%%~fZ"
		)
		IF %DO_PNG% EQU 1 (
			IF /I "%%~xZ" == ".PNG"  CALL %OPTIMIZE_PNG% "%%~fZ"
		)
		IF %DO_WAD% EQU 1 (
			IF /I "%%~xZ" == ".WAD"  CALL %OPTIMIZE_WAD% "%%~fZ"
		)
		IF %DO_PK3% EQU 1 (
			IF /I "%%~xZ" == ".PK3"  CALL %OPTIMIZE_PK3% "%%~fZ"
		)
		REM # files with "lmp" exetension or no extension at all
		REM # must be examined to determine their type
		SET "IS_LUMP=0"
		IF /I "%%~xZ" == ".lmp" SET "IS_LUMP=1"
		IF "%%~xZ" == "" SET "IS_LUMP=1"
		IF "!IS_LUMP!" == "1" (
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
	)
	REM # put that thing back where it came from, or so help me
	POPD
	REM # don't try process the parameter again
	GOTO :next_param
)

REM # PK3 file:
IF /I "%~x1" == ".PK3" (
	IF %DO_PK3% EQU 1 CALL %OPTIMIZE_PK3% "%~f1"
)
REM # WAD file:
IF /I "%~x1" == ".WAD" (
	IF %DO_WAD% EQU 1 CALL %OPTIMIZE_WAD% "%~f1"
)
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
	IF %DO_WAD% EQU 1 (
		IF "!HEADER:~1,3!" == "WAD" CALL %OPTIMIZE_WAD% "%~f1"
	)
)


:next_param
REM ====================================================================================================================
REM # is there another parameter?
SHIFT
IF NOT "%~1" == "" (
	GOTO :process_param
)

CALL %LOG_ECHO% "###############################################################################"
CALL %LOG_ECHO% "# complete"
ECHO:
PAUSE
EXIT /B 0