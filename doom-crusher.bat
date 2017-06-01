@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # doom-crusher.bat : v2.0
REM ====================================================================================================================
REM # optimize DOOM-related files: PK3 / WAD / PNG / JPG

SET "VER=2.0"

REM # path of this script:
REM # (must be done before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"


REM # any file/folder parameters?
IF "%~1" == "" (
	ECHO doom-crusher.bat: v%VER% - Kroc Camen
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

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"
SET "DO_WAD=1"
SET "DO_PK3=1"
SET "ZSTORE=0"

:options
REM --------------------------------------------------------------------------------------------------------------------
REM # check for an echo parameter (enables ECHO)
SET "ECHO="
IF /I "%~1" == "/ECHO" (
	REM # re-enable ECHO
	ECHO ON
	REM # check for more options
	SHIFT & GOTO :options
)

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


REM ====================================================================================================================
REM # init
REM --------------------------------------------------------------------------------------------------------------------
REM # binaries path
SET "BIN=%HERE%\bin"

REM # location of log file
SET LOG_FILE="%BIN%\log.txt"
REM # clear the log file
IF EXIST "%LOG_FILE%" DEL /F "%LOG_FILE%" >NUL 2>&1
REM # failed?
IF ERRORLEVEL 1 (
	ECHO Could not clear the log file at:
	ECHO %LOG_FILE%
	EXIT /B 1
)
SET DOT=0

ECHO:
CALL :log_echo "# doom-crusher : v%VER%"
CALL :log_echo "#     feedback : <github.com/Kroc/DOOM-Crusher> or <kroc+doom@camendesign.com>"
REM # display which options have been set
SET "OPTIONS="
IF %DO_PNG% EQU 0 SET "OPTIONS=%OPTIONS%/NOPNG "
IF %DO_JPG% EQU 0 SET "OPTIONS=%OPTIONS%/NOJPG "
IF %DO_WAD% EQU 0 SET "OPTIONS=%OPTIONS%/NOWAD "
IF %DO_PK3% EQU 0 SET "OPTIONS=%OPTIONS%/NOPK3 "
IF %ZSTORE% EQU 1 SET "OPTIONS=%OPTIONS%/ZSTORE"
IF NOT "%OPTIONS%" == "" (
	CALL :log_echo "#      options : %OPTIONS%"
)
CALL :log_echo "###############################################################################"

REM # detect 32-bit or 64-bit Windows
SET "WINBIT=32"
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET "WINBIT=64"	& REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET "WINBIT=64"	& REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET "WINBIT=64"	& REM # 32-bit CMD on a 64-bit system (WOW64)

REM # cache directory
SET "CACHEDIR=%BIN%\cache"
REM # if it doesn't exist create it
IF NOT EXIST "%CACHEDIR%" MKDIR "%CACHEDIR%"  >NUL 2>&1

REM # sha256deep:
IF "%WINBIT%" == "64" SET BIN_HASH="%BIN%\md5deep\sha256deep64.exe"
IF "%WINBIT%" == "32" SET BIN_HASH="%BIN%\md5deep\sha256deep.exe"

REM # select 7Zip executable
IF "%WINBIT%" == "64" SET BIN_7ZA="%BIN%\7za\7za_x64.exe"
IF "%WINBIT%" == "32" SET BIN_7ZA="%BIN%\7za\7za.exe"

REM # jpegtran:
SET "BIN_JPEG=%BIN%\jpegtran\jpegtran.exe"

REM # our component scripts:
SET OPTIMIZE_PK3="%BIN%\optimize_pk3.bat"
SET OPTIMIZE_WAD="%BIN%\optimize_wad.bat"
SET OPTIMIZE_PNG="%BIN%\optimize_png.bat"


REM # process parameter list:
REM ====================================================================================================================
:params

SET "DOT=0"

REM # check if parameter is a directory
REM # (this returns the file attributes, a "d" is added for directories)
SET "ATTR=%~a1"
IF /I "%ATTR:~0,1%" == "d" (
	CALL :param_dir "%~f1"
) ELSE (
	REM # otherwise, it's a file path
	CALL :process_file "%~f1"
)

:param_next
REM --------------------------------------------------------------------------------------------------------------------
REM # is there another parameter?
SHIFT
IF NOT "%~1" == "" GOTO :params

CALL :log_echo "###############################################################################"
CALL :log_echo "# complete"
ECHO:
PAUSE
EXIT /B 0


:param_dir
	REM ------------------------------------------------------------------------------------------------------------
	REM # the `FOR /R` loop works most reliably from the directory in question
	PUSHD "%~f1"
	REM # scan the directory given for crushable files:
	REM # note that "*." is a special term to select all files *without* an extension
	FOR /R "." %%Z IN (*.jpg;*.jpeg;*.png;*.wad;*.pk3;*.lmp;*.) DO CALL :param_file "%%~fZ"
	REM # put that thing back where it came from, or so help me
	POPD
	GOTO:EOF

:param_file
	REM # determine the file type of a file and process it accordingly
	REM #
	REM #	%1 = full path of file to process
	REM ------------------------------------------------------------------------------------------------------------
	
	REM # determine the file type
	CALL :get_filetype "%~f1"
	REM # if not a recognised file type, skip the file
	IF "%TYPE%" == "" GOTO :param_skip
	
	REM # TODO: if WAD, check if IWAD first to allow skipping without hashing?
	
	REM # check the cache
	CALL :hash_check "%~f1"
	REM # if in the cache, skip the file
	IF %ERRORLEVEL% EQU 0 GOTO :param_skip
	
	REM # which file type?
	IF "%TYPE%" == "jpg"  GOTO :param_jpg
	IF "%TYPE%" == "png"  GOTO :param_png
	IF "%TYPE%" == "wad"  GOTO :param_wad
	IF "%TYPE%" == "pk3"  GOTO :param_pk3
		
	REM # this would be an error where `:get_filetype`
	REM # returned something other than the above
	ECHO "Internal error! `:get_filetype` return type unhandled."
	EXIT /B 1
	
	:param_skip
	CALL :dot
	GOTO:EOF
	
	:param_jpg
	REM # skip file is JPG optimization is disabled
	IF %DO_JPG% EQU 0 GOTO :param_skip
	IF %DOT% GTR 0 ECHO: & SET "DOT=0"
	CALL :optimize_jpg "%~f1"
	GOTO:EOF
	
	REM # PNG files:
	:param_png
	REM # skip file is JPG optimization is disabled
	IF %DO_PNG% EQU 0 GOTO :param_skip
	IF %DOT% GTR 0 ECHO: & SET "DOT=0"
	CALL %OPTIMIZE_PNG% "%~f1"
	GOTO:EOF
	
	REM # WAD files:
	:param_wad
	REM # skip file is JPG optimization is disabled
	IF %DO_WAD% EQU 0 GOTO :param_skip
	IF %DOT% GTR 0 ECHO: & SET "DOT=0"
	CALL %OPTIMIZE_WAD% "%~f1"
	GOTO:EOF
	
	REM # PK3 files:
	:param_pk3
	REM # skip file is JPG optimization is disabled
	IF %DO_PK3% EQU 0 GOTO :param_skip
	IF %DOT% GTR 0 ECHO: & SET "DOT=0"
	CALL %OPTIMIZE_PK3% "%~f1"
	GOTO:EOF
	
:get_filetype
	REM # determines the type of a file by its extension,
	REM # and if that's not possible, examines the file header
	REM #
	REM #	%1 = File path
	REM #
	REM # returns "jpg", "png", "wad", "pk3" for known types,
	REM # or "" for unknown type in the `%TYPE%` variable
	REM ------------------------------------------------------------------------------------------------------------
	REM # by default, return blank
	SET "TYPE="
	
	REM # simple file extension check
	IF /I "%~x1" == ".jpg"  SET "TYPE=jpg" & GOTO:EOF
	IF /I "%~x1" == ".jpeg" SET "TYPE=jpg" & GOTO:EOF
	IF /I "%~x1" == ".png"  SET "TYPE=png" & GOTO:EOF
	IF /I "%~x1" == ".wad"  SET "TYPE=wad" & GOTO:EOF
	IF /I "%~x1" == ".pk3"  SET "TYPE=pk3" & GOTO:EOF
	
	REM # files with "lmp" exetension or no extension at all
	REM # must be examined to determine their type
	SET "IS_LUMP=0"
	IF /I "%~x1" == ".lmp" SET "IS_LUMP=1"
	IF    "%~x1" == ""     SET "IS_LUMP=1"
	REM # if not a lump file, return blank
	IF "%IS_LUMP%" == "0" GOTO:EOF
	
	REM # READ the first 1021 bytes of a file. a truly brilliant solution, thanks to:
	REM # http://stackoverflow.com/a/7827243
	SET "HEADER=" & SET /P HEADER=< "%~f1"
	
	REM # sometimes these bytes can glitch the parser,
	REM # so we delay their insertion until runtime:
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # a JPEG file?
	REM # IMPORTANT: these bytes are "0xFF,0xD8"
	IF "!HEADER:~0,2!" == "ÿØ"  ENDLOCAL & SET "TYPE=jpg" & GOTO:EOF
	REM # a PNG file?
	IF "!HEADER:~1,3!" == "PNG" ENDLOCAL & SET "TYPE=png" & GOTO:EOF
	REM # a WAD file?
	IF "!HEADER:~1,3!" == "WAD" ENDLOCAL & SET "TYPE=wad" & GOTO:EOF
	
	REM # not a file type we deal with, return blank
	ENDLOCAL
	GOTO:EOF

:hash_check
	REM # check if a file already exists in the cache
	REM #
	REM #	%1 = file-path
	REM #
	REM # returns ERRORLEVEL 0 if the file is in the cache,
	REM # ERRORLEVEL 1 for any other reason
	REM ------------------------------------------------------------------------------------------------------------
	REM # get the path for the hash-cache file
	CALL :hash_name "%~f1"
	
	REM # (use of quotes in a FOR command here is fraught with complications:
	REM #  http://stackoverflow.com/questions/22636308)
	FOR /F "eol=* tokens=* delims=" %%A IN ('^" %BIN_HASH% -s -m %HASHFILE% -b "%~f1" ^"') DO (
		IF /I "%%A" == "%~nx1" EXIT /B 0
	)
	EXIT /B 1

:hash_add
	REM # add a file to the hash-cache
	REM #
	REM #	%1 = file-path
	REM ------------------------------------------------------------------------------------------------------------
	REM # get the path for the hash-cache file
	CALL :hash_name "%~f1"
	
	REM # hash the file:
	REM # the output of the command is full of problems that make it difficult to parse in Batch,
	REM # from padding-spaces to multiple space gaps between columns, we need to normalise it first

	REM # sha256deep:
	REM # 	-s	: silent, don't include non-hash text in the output
	REM # 	-q	: no filename
	REM # use of quotes in a FOR command here is fraught with complications:
	REM # http://stackoverflow.com/questions/22636308
	FOR /F "eol=* delims=" %%A IN ('^" %BIN_HASH% -s -q "%~f1" ^"') DO @SET "HASH=%%A"
	REM # compact multiple spaces into a single colon
	SET "HASH=%HASH:  =:%"
	SET "HASH=%HASH:::=:%"
	SET "HASH=%HASH:::=:%"
	REM # now split the columns
	FOR /F "eol=* tokens=1-2 delims=:" %%A IN ("%HASH%") DO (
		REM # write the hash to the hash-cache
		ECHO %%A  %~nx1>>%HASHFILE%
	)
	GOTO:EOF

:hash_name
	REM # gets the file-path to the hash-cache to use for the given file
	REM #
	REM #	%1 = file-path to file that will be hashed
	REM #
	REM # sets `%HASHFILE%` with full path to the hash-cache file to use
	REM ------------------------------------------------------------------------------------------------------------
	REM # the different file-types are separated into different hash buckets.
	REM # this is to avoid unecessary slow-down from large buckets (png) affecting smaller ones (jpg)
	CALL :get_filetype "%~f1"
	
	REM # pick the filename for the hash-cache
	SET "HASHFILE=%CACHEDIR%\hashes_%TYPE%.txt"
	REM # when the /ZSTORE option is enabled, PK3 files use a different hash file
	IF %ZSTORE% EQU 1 (
		IF "%TYPE%" == "pk3" SET "HASHFILE=%CACHEDIR%\hashes_pk3_zstore.txt"
	)
	GOTO:EOF
	
	
REM ====================================================================================================================

:optimize_jpg
	REM # display file name and current file size
	CALL :display_status_left "%~f1"
	
	REM # jpegtran:
	REM #	-optimize	: optimize without quality loss
	REM # 	-copy none	: don't keep any metadata
	"%BIN_JPEG%" -optimize -copy none "%~f1" "%~f1"  >NUL 2>&1
	IF ERRORLEVEL 1 (
		REM # cap the status line
		CALL :display_status_msg "! error <jpegtran>"
		REM # if JPG optimisation failed return an error state; if the JPG was from a WAD or PK3 then these
		REM # will *not* be cached so that they will always be retried in the future until there are no errors
		REM # (we do not want to write off a WAD or PK3 as "done" when there are potential savings remaining)
		EXIT /B 1
	) ELSE (
		REM # add the file to the hash-cache
		CALL :hash_add "%~f1"
		REM # cap status line with the new file size
		CALL :display_status_right "%~f1"
	)
	GOTO:EOF


REM # common functions
REM ====================================================================================================================
:log
	REM # write message to log-file only
	REM #
	REM #	%1 - message
	REM ------------------------------------------------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"

	REM # now allow the parameter string to be written without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION

	REM # check for blank line
	IF "!ECHO!" == "" (
		ECHO:>> %LOG_FILE%
	) ELSE (
		ECHO !ECHO!>> %LOG_FILE%
	)
	ENDLOCAL
	GOTO:EOF

:log_echo
	REM # write to log-file and screen
	REM #
	REM #	%1 - message
	REM ------------------------------------------------------------------------------------------------------------
	IF %DOT% GTR 0 ECHO: & SET "DOT=0"
	
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"
	
	REM # now allow the parameter string to be displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION

	REM # check for blank line
	IF "!ECHO!" == "" (
		ECHO:
		ECHO:>> %LOG_FILE%
	) ELSE (
		ECHO !ECHO!
		ECHO !ECHO!>> %LOG_FILE%
	)
	ENDLOCAL
	GOTO:EOF

:dot
	REM # display a dot on screen to indicate progress; these are batched together into lines
	REM ------------------------------------------------------------------------------------------------------------
	REM # increase current dot count
	SET /A DOT=DOT+1
	REM # line wrap?
	IF %DOT% EQU 78 SET "DOT=1" & ECHO:
	REM # new line?
	IF %DOT% EQU 1 (
		<NUL (SET /P "$=- .")
	) ELSE (
		REM # display dot, without moving to the next line
		<NUL (SET /P "$=.")
	)
	GOTO:EOF
	
:filesize
	REM # get a file size (in bytes):
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
	CALL "%BIN%\get_percentage.bat" SAVED %SIZE_OLD% %SIZE_NEW%
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
	CALL :log "%STATUS_LEFT%%STATUS_RIGHT%"
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
	CALL :log "%STATUS_LEFT%!TEXT!"
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