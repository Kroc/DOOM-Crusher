@ECHO OFF & SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM # optimize_wad.bat
REM ====================================================================================================================
REM # optimizes a DOOM WAD file (which may contain embedded JPG, PNG and other WAD files)
REM # this script recursively optimizes, so WADs within WADs will automatically be handled

REM # %1 - filepath to a WAD file. for ".PK3" WADs use "optimize_pk3.bat" instead

REM # TODO : handle different lumps with the same name? (use the lump ids for positioning)
REM # TODO : handle lump names that would be invalid file names, e.g. "*"

REM --------------------------------------------------------------------------------------------------------------------
CALL :init

REM # default options
SET "DO_PNG=1"
SET "DO_JPG=1"
SET "USE_CACHE=1"
REM # if PNG/JPG files are being skipped but this PK3 doesn't
REM # contain any then we can still add the PK3 to the cache
SET "ANY_PNG=0"
SET "ANY_JPG=0"
REM # if the WAD optimisation or optimisation of internal JPG/PNG files fail, return an error state; if the WAD was
REM # from a PK3 then it will *not* be cached so that it will always be retried in the future until there are no errors
REM # (we do not want to write off a PK3 as "done" when there are potential savings remaining)
SET "ERROR=0"

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_wad.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_wad.bat [options] ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a DOOM WAD file ^(which may contain embedded JPG and PNG files^).
	ECHO:
	ECHO     "options" can be any of:
	ECHO:	 
	ECHO     /NOPNG  : Skip processing PNG files
	ECHO     /NOJPG  : Skip processing JPG files
	ECHO:
	EXIT /B 0
)

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

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO optimize_wad.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     optimize_wad.bat %0
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
	EXIT /B 1
)

REM ====================================================================================================================
REM # absolute path of the given WAD file
SET "WAD_FILE=%~f1"

REM # location of the wadptr executable
SET BIN_WADPTR="%HERE%\wadptr\wadptr.exe"
REM # location of the lumpmod executable
SET BIN_LUMPMOD="%HERE%\lumpmod\lumpmod.exe"

REM # our component scripts
SET OPTIMIZE_PNG="%HERE%\optimize_png.bat"
SET OPTIMIZE_JPG="%HERE%\optimize_jpg.bat"

REM # display file name and current file size
CALL :display_status_left "%WAD_FILE%"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
REM # hashing commands:
SET HASH_TRY="%HERE%\hash_check.bat" "wad"
SET HASH_ADD="%HERE%\hash_add.bat" "wad"

REM # check the file in the hash-cache
CALL %HASH_TRY% "%WAD_FILE%"
REM # if the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	CALL :display_status_msg ": skipped (cache)"
	EXIT /B 0
)

REM # do not process IWADs
REM --------------------------------------------------------------------------------------------------------------------
REM # we do NOT want to modify the original DOOM IWADs (DOOM.WAD / DOOM2.WAD etc.) as the extact file-sizes
REM # and checksums are used to detect particular IWADs in various DOOM engines

REM # READ the first 1021 bytes of a file. a truly brilliant solution, thanks to:
REM # http://stackoverflow.com/a/7827243
SET "HEADER=" & SET /P HEADER=< "%WAD_FILE%"

REM # a WAD file will begin with "IWAD" or "PWAD" respectively
IF "%HEADER:~0,4%" == "IWAD" (
	CALL :display_status_msg ": skipped (IWAD)"
	EXIT /B 0
)

REM # clean up any previous attempt
REM --------------------------------------------------------------------------------------------------------------------
REM # wadptr is extremely buggy and might just decide to process every WAD in the same folder even though you gave it
REM # a single file name. to make this process more reliable we'll set up a temporary sub-folder and copy the WAD into
REM # there to isolate it from other WAD files and stuff.
SET "TEMP_DIR=%TEMP%\%~nx1"
SET "TEMP_FILE=%TEMP_DIR%\%~nx1"

IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" (
	REM # attempt a second time, this is intentional:
	REM # http://stackoverflow.com/questions/22948189/batch-getting-the-directory-is-not-empty-on-rmdir-command
	RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	REM # could not clean up?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "^! error <rmdir>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not remove directory:"
		CALL %LOG_ECHO% "%TEMP_DIR%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

REM # create the temporary directory
IF NOT EXIST "%TEMP_DIR%" (
	REM # try create the directory
	MKDIR "%TEMP_DIR%"  >NUL 2>&1
	REM # failed?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "^! error <mkdir>"
		CALL %LOG_ECHO% "==============================================================================="
		CALL %LOG_ECHO%
		CALL %LOG_ECHO% "ERROR: Could not create directory:"
		CALL %LOG_ECHO% "%TEMP_DIR%"
		CALL %LOG_ECHO%
		EXIT /B 1
	)
)

REM # copy the WAD to the temporary directory; we could save a lot of I/O if we moved it and then moved it back when
REM # we were done, but if the script is stopped or crashes we don't want to misplace the original files.
COPY /Y "%WAD_FILE%" "%TEMP_FILE%"  >NUL 2>&1
REM # did the copy fail?
IF ERRORLEVEL 1 (
	REM # cap the status line to say that the copy errored
	CALL :display_status_msg "^! error <copy>"
	REM # remove the temporary directory (duplicate on purpose)
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
	REM # clean-up and error-out so any script calling this one can also clean-up etc.
	EXIT /B 1
)

REM # examine the WAD contents for optimizable files (PNG/JPG/WAD)
REM ====================================================================================================================
REM # we'll avoid displaying the split-line if the WAD doesn't contain any lumps we can optimise
SET "ANY=0"

REM # list the WAD contents and get the name and length of each lump,
REM # lumpmod.exe has been modified to also provide the filetype, with thanks to _mental_
REM # (use of quotes in a FOR command here is fraught with complications:
REM #  http://stackoverflow.com/questions/22636308)
FOR /F "tokens=1-4" %%A IN ('^" "%BIN_LUMPMOD%" "%TEMP_FILE%" list -v "^"') DO (
	REM # lumps of length 0 are just markers and can be skipped
	IF NOT "%%C" == "0" (
		REM # only process JPG or PNG lumps
		IF NOT "%%D" == "LMP" (
			REM # ensure the lump name can be written to disk
			REM # (may contain invalid file-system characters)
			REM # TODO : handle astrisk, very difficult to do properly
			SET "LUMP=%%B"
			SET "LUMP=!LUMP:<=_!"
			SET "LUMP=!LUMP:>=_!"
			SET "LUMP=!LUMP::=_!"
			SET 'LUMP=!LUMP:"=_!'
			SET "LUMP=!LUMP:/=_!"
			SET "LUMP=!LUMP:\=_!"
			SET "LUMP=!LUMP:|=_!"
			SET "LUMP=!LUMP:?=_!"
			REM # this is where the lump will go
			SET "LUMP=%TEMP_DIR%\!LUMP!.lmp"
			
			REM # extract the lump to disk to optimize it
			%BIN_LUMPMOD% "%TEMP_FILE%" extract %%B "!LUMP!" >NUL 2>&1
			REM # only continue if this succeeded
			IF !ERRORLEVEL! EQU 0 (
				REM # a PNG file?
				IF "%%D" == "PNG" (
					REM # mark the WAD as containing at least one PNG file; this will
					REM # preven the WAD file being cached if PNG files are being skipped
					SET "ANY_PNG=1"
					REM # is PNG processing enabled?
					IF %DO_PNG% EQU 1 (
						REM # display the split-line to indicate WAD contents
						CALL :any_ok
						CALL %OPTIMIZE_PNG% "!LUMP!"
						REM # if that errored we won't cache the WAD
						SET "ERROR=!ERRORLEVEL!"
					)
				)
				REM # a JPEG file?
				IF "%%D" == "JPG" (
					REM # mark the WAD as containing at least one JPG file; this will
					REM # preven the WAD file being cached if JPG files are being skipped
					SET "ANY_JPG=1"
					REM # is JPEG processing enabled?
					IF %DO_JPG% EQU 1 (
						REM # display the split-line to indicate WAD contents
						CALL :any_ok
						CALL %OPTIMIZE_JPG% "!LUMP!"
						REM # if that errored we won't cache the WAD
						SET "ERROR=!ERRORLEVEL!"
					)
				)
				REM # was the lump omptimized?
				REM # (the orginal lump size is already in `%%C`)
				CALL :filesize LUMP_SIZE "!LUMP!"
				REM # compare sizes
				IF !LUMP_SIZE! LSS %%C (
					REM # put the lump back into the WAD
					%BIN_LUMPMOD% "%TEMP_FILE%" update "%%B" "!LUMP!" >NUL 2>&1
					REM # if that errored we won't cache the WAD
					IF !ERRORLEVEL! NEQ 0 SET "ERROR=1"
					REM # TODO: display the file status line to show a lumpmod error?
				)
				
			REM # extracting the lump did not succeed:
			) ELSE (
				REM # do not allow the WAD file to be cache,
				REM # or any parent PK3 file
				SET "ERROR=1"
				REM # TODO: display the file status line to show a lumpmod error
			)
		)
	)
)

REM # restore the previous working directory
POPD

REM # mark the end of WAD contents if any lump was optimised
IF %ANY% EQU 1 (
	CALL %LOG_ECHO% "  -----------------------------------------------------------------------------"
	CALL :display_status_left "%WAD_FILE%"
)


REM # use wadptr to optimize a WAD:
REM ====================================================================================================================
REM # change to the temporary directory, wadptr is prone to choking on absolute/relative paths,
REM # it's best to give it a single file name within the current directory
PUSHD "%TEMP_DIR%"

REM # do the wadptr compression:
REM # -c	: compress
REM # -nopack	: skip sidedef packing as this can cause glitches in maps
%BIN_WADPTR% -c -nopack "%~nx1"  >NUL 2>&1
REM # if this errors, the WAD won't have been changed so we can continue
IF !ERRORLEVEL! NEQ 0 (
	REM # cap the status line to say that wadptr errored,
	REM # but otherwise continue
	CALL :display_status_msg "^! error <wadptr>"
	REM # note error state so that the WAD will not be cached
	SET "ERROR=1"
) ELSE (
	REM # cap status line with the new file size
	CALL :display_status_right "%TEMP_FILE%"
)

REM # can leave the directory now
REM # (the copy below uses absolute paths)
POPD

REM # temporary WAD has been optimized, replace the original
REM # (if this were to error just continue with the clean-up)
COPY /Y "%TEMP_FILE%" "%WAD_FILE%"  >NUL 2>&1
IF ERRORLEVEL 1 (
	CALL %LOG_ECHO%
	CALL %LOG_ECHO% "ERROR: Could not replace the original WAD with the new version."
	CALL %LOG_ECHO%
	EXIT /B 1
)


REM # clean-up:
REM ====================================================================================================================

REM # remove the temporary directory (intentional duplicate)
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1

REM # add the file to the hash-cache?
IF %ERROR% EQU 1 SET "USE_CACHE=0"
IF %DO_JPG% EQU 0 (
	IF %ANY_JPG% EQU 1 SET "USE_CACHE=0"
)
IF %DO_PNG% EQU 0 (
	IF %ANY_PNG% EQU 1 SET "USE_CACHE=0"
)
IF %USE_CACHE% EQU 1 CALL %HASH_ADD% "%WAD_FILE%"

EXIT /B %ERROR%


REM # functions:
REM ====================================================================================================================

:init
	REM # path of this script:
	REM # (must be done before using `SHIFT`)
	SET "HERE=%~dp0"
	REM # always remove trailing slash
	IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"
	REM # logging commands:
	SET LOG="%HERE%\log.bat"
	SET LOG_ECHO="%HERE%\log_echo.bat"
	GOTO:EOF

:any_ok
	REM # only display the split line for a WAD if there any lumps that will be optimised in the WAD
	REM ------------------------------------------------------------------------------------------------------------
	IF %ANY% EQU 0 (
		CALL :display_status_msg ": processing..."
		CALL %LOG_ECHO% "  -----------------------------------------------------------------------------"
		SET "ANY=1"
	)
	GOTO:EOF

:filesize
	REM # get a file size (in bytes):
	REM # 	%1 = variable name to set
	REM # 	%2 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	SET "%~1=%~z2"
	GOTO:EOF

:display_status_left
	REM # outputs the status line up to the original file's size:
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # prepare the columns for output
	SET "COLS=                                                                               "
	SET "COL1_W=45"
	SET "COL1=!COLS:~0,%COL1_W%!"
	REM # prepare the status line
	SET "LINE=%~nx1%COL1%"
	REM # get the current file size
	CALL :filesize SIZE_OLD "%~1"
	REM # right-align it
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # formulate the line
	SET "STATUS_LEFT=* !LINE:~0,%COL1_W%! %LINE_OLD% "
	REM # output the status line (without carriage-return)
	<NUL (SET /P "$=%STATUS_LEFT%")
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
	REM # if the filesize increased:
	IF %SIZE_NEW% GTR %SIZE_OLD% (
		SET /A "SAVED=100*SIZE_NEW/SIZE_OLD,SAVED-=100"
		SET "SAVED=   !SAVED!"
		SET "SAVED=+!SAVED:~-3!"
	) ELSE (
		IF %SIZE_NEW% EQU %SIZE_OLD% (
			REM # avoid dividing by zero
			SET /A SAVED=0
			SET "SAVED==  0"
		) ELSE (
			SET /A "SAVED=100-100*SIZE_NEW/SIZE_OLD"
			SET "SAVED=   !SAVED!"
			SET "SAVED=-!SAVED:~-3!"
		)
	)
	REM # format & right-align the new file size
	CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
	REM # formulate the line
	SET "STATUS_RIGHT=%SAVED%%% = %LINE_NEW% "
	REM # output the remainder of the status line and log the complete status line
	ECHO %STATUS_RIGHT%
	CALL %LOG% "%STATUS_LEFT%%STATUS_RIGHT%"
	GOTO:EOF
	
:display_status_msg
	REM # append a message to the status line and also output it to the log whole:
	REM # 	%1 = message
	REM ------------------------------------------------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"
	REM # now allow the parameter string to be displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # (note that the status line is displayed in two parts in the console, before and after file optimisation,
	REM #  but needs to be output to the log file as a single line)
	ECHO !ECHO!
	CALL %LOG% "%STATUS_LEFT%!ECHO!"
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