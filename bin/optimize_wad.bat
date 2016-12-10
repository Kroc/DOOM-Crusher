@ECHO OFF

REM # optimize_wad.bat
REM ====================================================================================================================
REM # optimizes a DOOM WAD file (which may contain embedded JPG, PNG and other WAD files)
REM # this script recursively optimizes, so WADs within WADs will automatically be handled

REM # %1 - filepath to a WAD file. for ".PK3" / ".PK7" WADs use "optimize_pk3.bat" instead

REM # TODO : handle different lumps with the same name (use the lump ids for positioning)
REM # TODO : handle lump names that would be invalid file names, e.g. "\"

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_wad.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_wad.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a DOOM WAD file ^(which may contain embedded JPG and PNG files^).
	ECHO:
	GOTO:EOF
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
REM # we cannot get the updated size of the file without just-in-time variable expansion
SETLOCAL ENABLEDELAYEDEXPANSION

REM # path of this script
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # absolute path of the WAD file
SET "FILE=%~dpnx1"

REM # location of the wadptr executable
SET "BIN_WADPTR=%HERE%\wadptr\wadptr.exe"
REM # location of the lumpmod executable
SET "BIN_LUMPMOD=%HERE%\lumpmod\lumpmod.exe"

REM # status line:
REM --------------------------------------------------------------------------------------------------------------------
REM # display file name and current file size
CALL :status_oldsize "%~1"

REM # create backup first:
REM --------------------------------------------------------------------------------------------------------------------
REM # wadptr is extremely buggy and might just decide to process every WAD in the same folder even though you gave it
REM # a single file name. to make this process more reliable we'll set up a temporary sub-folder and copy the WAD into
REM # there to isolate it from other WAD files and stuff.
SET "TEMP_DIR=%~dp1._%~n1"
IF NOT EXIST "%TEMP_DIR%" MKDIR "%TEMP_DIR%"

REM # copy the WAD to the temporary directory; we could save a lot of I/O if we moved it and then moved it back when
REM # we were done, but if the script is stopped or crashes we don't want to misplace original files.
SET "TEMP_FILE=%TEMP_DIR%\%~nx1"
COPY /Y "%FILE%" "%TEMP_FILE%" >NUL
REM # did the copy fail?
IF ERRORLEVEL 1 (
	REM # cap the status line to say that the copy errored
	ECHO ^^!! error ^<copy^>
	REM # remove the temporary directory (duplicate on purpose)
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"
	IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"
	REM # clean-up and error-out so any script calling this one can also clean-up etc.
	EXIT /B 1
)

REM # change to the temporary directory, wadptr is prone to choking on absolute/relative paths
PUSHD "%TEMP_DIR%"

REM # use wadptr to optimize a WAD:
REM ====================================================================================================================
REM # check if WAD is an IWAD or PWAD; we can't use wadptr to optimize IWADs (it asks for confirmation and there isn't
REM # a way to automate the response due to the binary being old / partially 16-bit?)

REM # READ the first 1021 bytes of a file. a truly brilliant solution, thanks to:
REM # http://stackoverflow.com/a/7827243
SET "HEADER=" & SET /P HEADER=< "%TEMP_FILE%"

REM # a WAD file will begin with "IWAD" or "PWAD" respectively
IF "%HEADER:~0,4%" == "PWAD" (
	REM # do the wadptr compression.
	"%BIN_WADPTR%" -c "%~nx1"  >NUL 2>&1
	REM # if this errors, the WAD won't have been changed so we can continue
	IF !ERRORLEVEL! NEQ 0 (
		REM # cap the status line to say that wadptr errored,
		REM # but otherwise continue
		ECHO ^^!! error ^<wadptr^>
	) ELSE (
		REM # cap status line with the new file size
		CALL :status_newsize "%TEMP_FILE%"
	)
)

REM # examine the WAD contents for optimizable files (PNG/JPG/WAD)
REM ====================================================================================================================
REM # if no lumps within the wad are relevant, we skip printing some uneccessary lines
SET "ANY=0"

REM # list the WAD contents and get the name and length of each lump
FOR /F "skip=3 tokens=1-3" %%A IN ('%BIN_LUMPMOD% "%TEMP_FILE%" list -v') DO (
	REM # lumps of length 0 are just markers and can be skipped
	IF NOT "%%C" == "0" (
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

		REM # the lump name cannot tell us the file type in the lump,
		REM # we need to save out the lump and examine its contents
		%BIN_LUMPMOD% "%TEMP_FILE%" extract %%B "!LUMP!" >NUL
		REM # only continue if this succeeded
		IF !ERRORLEVEL! EQU 0 (
			REM # READ the first 1021 bytes of the lump.
			REM # a truly brilliant solution, thanks to:
			REM # http://stackoverflow.com/a/7827243
			SET "HEADER=" & SET /P HEADER=< "!LUMP!"
			
			REM # a PNG file?
			IF "!HEADER:~1,3!" == "PNG" (
				REM # underscore the WAD to show we're exploring the contents
				IF "!ANY!" == "0" (
					ECHO -------------------------------------------------------------------------------
					SET "ANY=1"
				)
				REM # optimize it!
				CALL %HERE%\optimize_png.bat "!LUMP!"
			)
			REM # a JPEG file?
			IF "!HEADER:~0,2!" == "ÿØ" (
				REM # underscore the WAD to show we're exploring the contents
				IF "!ANY!" == "0" (
					ECHO -------------------------------------------------------------------------------
					SET "ANY=1"
				)
				REM # optimize it!
				CALL %HERE%\optimize_jpg.bat "!LUMP!"
			)
			
			REM # was the lump omptimized?
			REM # (the orginal lump size is already in %%C)
			FOR %%F IN ("!LUMP!") DO SET "LUMP_SIZE=%%~zF"
			REM # compare sizes
			IF !LUMP_SIZE! LSS %%C (
				REM # put the lump back into the WAD
				%BIN_LUMPMOD% "%TEMP_FILE%" update %%B "!LUMP!" >NUL
			)
		)
		REM # remove the lump file
		IF EXIST "!LUMP!" DEL "!LUMP!"
	)
)

REM clean-up:
REM ====================================================================================================================
REM # temporary WAD has been optimized, replace the original
REM # (if this were to error just continue with the clean-up)
COPY /Y "%TEMP_FILE%" "%FILE%"  >NUL 2>&1

REM --------------------------------------------------------------------------------------------------------------------
IF "%ANY%" == "1" (
	REM # get the new file size (we need this dummy for-loop to force re-reading the file size)
	FOR %%F IN ("%FILE%") DO SET "SIZE_NEW=%%~zF"
	REM # right-align the number
	CALL :format_filesize_bytes LINE_NEW !SIZE_NEW!
	REM # calculate percentage change
	SET /A SAVED=100-100*SIZE_NEW/SIZE_OLD
	SET "SAVED=   !SAVED!%%"

	IF "%ANY%" == "1" (
		ECHO -------------------------------------------------------------------------------
		ECHO = %LINE:~0,45% %LINE_OLD% - !SAVED:~-3! = !LINE_NEW!
		ECHO:
	)
)

REM # restore the previous working directory
POPD
REM # remove the temporary directory (intentional duplicate)
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1

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
	<NUL (SET /P "$=+ !LINE:~0,%COL1_W%! %LINE_OLD% ")
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