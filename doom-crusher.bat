@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # doom-crusher.bat : v2.2
REM ============================================================================
REM # optimize DOOM-related files: PK3 / WAD / PNG / JPG

SET "VER=2.2"

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
	ECHO     /NOPNG   : Skip processing PNG files
	ECHO     /NOJPG   : Skip processing JPG files
	ECHO     /NOWAD   : Skip processing WAD/IWAD files
	ECHO     /NOPK3   : Skip processing PK3/IPK3/PKE/EPK/KART files
	ECHO:
	ECHO     /LOSSY   : Uses additional methods to reduce file size.
	ECHO                WARNING: PERMENANTLY REDUCES IMAGE QUALITY!
	ECHO                Never use on an original file, always make a copy!
	ECHO:
	ECHO     /ZSTORE  : Use no compression when re-packing PK3s.
	ECHO                Whilst the PK3 file will be larger than before,
	ECHO                it will boot faster.
	ECHO:
	ECHO                If you are compressing a number of PK3s together,
	ECHO                then using /ZSTORE on them might drastically improve
	ECHO                the final size of .7Z and .RAR archives when using
	ECHO                a very large dictionary size ^(128 MB or more^).
	ECHO:
	ECHO     /NOCACHE : Do not skip files based on the cached file hashes
	ECHO:
	EXIT /B 0
)

REM # initialise some numeric variables
SET ERROR=0
SET ANY=0
SET DOT=0

REM # default options
SET DO_PNG=1
SET DO_JPG=1
SET DO_WAD=1
SET DO_PK3=1
SET LOSSY=0
SET ZSTORE=0
SET CACHE=1

:options
REM ----------------------------------------------------------------------------
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
	SET DO_PNG=0
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOJPG" to disable JPEG processing
IF /I "%~1" == "/NOJPG" (
	REM # turn off JPEG processing
	SET DO_JPG=0
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOWAD" to disable WAD processing
IF /I "%~1" == "/NOWAD" (
	REM # turn off WAD processing
	SET DO_WAD=0
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOPK3" to disable PK3 processing
IF /I "%~1" == "/NOPK3" (
	REM # turn off PK3 processing
	SET DO_PK3=0
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/LOSSY" to enale lossy compression
IF /I "%~1" == "/LOSSY" (
	REM # enable the relevant flag
	SET LOSSY=1
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/ZSTORE" to disable compression of the PK3 file
IF /I "%~1" == "/ZSTORE" (
	REM # enable the relevant flag
	SET ZSTORE=1
	REM # check for more options
	SHIFT & GOTO :options
)
REM # use "/NOCACHE" to disable use of file-hashing
IF /I "%~1" == "/NOCACHE" (
	REM # turn off caching
	SET "CACHE="
	REM # check for more options
	SHIFT & GOTO :options
)

REM ============================================================================
REM # binaries
REM ----------------------------------------------------------------------------
REM # binaries path
SET "BIN=%HERE%\bin"

REM # detect 32-bit or 64-bit Windows
SET WINBIT=32
IF /I "%PROCESSOR_ARCHITECTURE%" == "EM64T" SET WINBIT=64 & REM # Itanium
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" SET WINBIT=64 & REM # Regular x64
IF /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET WINBIT=64 & REM # 32-bit CMD on a 64-bit system (WOW64)

REM # cache directory
SET "CACHEDIR=%BIN%\cache"
REM # if it doesn't exist create it
IF NOT EXIST "%CACHEDIR%" MKDIR "%CACHEDIR%"  >NUL 2>&1
REM # failed, somehow?
IF ERRORLEVEL 1 (
	ECHO ERROR! Could not create cache directory:
	ECHO "%CACHEDIR%"
	EXIT /B 1
)

REM # program for identifying file-types:
SET BIN_FILETYPE="%BIN%\filetype\filetype.exe"

REM # program for generating and verifying checksums:
IF %WINBIT% EQU 64 SET BIN_HASH="%BIN%\md5deep\sha1deep64.exe"
IF %WINBIT% EQU 32 SET BIN_HASH="%BIN%\md5deep\sha1deep.exe"

REM # select 7Zip executable:
IF %WINBIT% EQU 64 SET BIN_7ZA="%BIN%\7za\7za_x64.exe"
IF %WINBIT% EQU 32 SET BIN_7ZA="%BIN%\7za\7za.exe"

REM # jpegtran:
SET BIN_JPEG="%BIN%\jpegtran\jpegtran.exe"

REM # pngquant
SET BIN_PNGQUANT="%BIN%\pngquant\pngquant.exe"
REM # optipng:
SET BIN_OPTIPNG="%BIN%\optipng\optipng.exe"
REM # pngout:
SET BIN_PNGOUT="%BIN%\pngout\pngout.exe"
REM # pngcrush:
IF %WINBIT% EQU 64 SET BIN_PNGCRUSH="%BIN%\pngcrush\pngcrush_w64.exe"
IF %WINBIT% EQU 32 SET BIN_PNGCRUSH="%BIN%\pngcrush\pngcrush_w32.exe"

REM # location of the deflopt executable
SET BIN_DEFLOPT="%BIN%\deflopt\DeflOpt.exe"
REM # location of the wadptr executable
SET BIN_WADPTR="%BIN%\wadptr\wadptr.exe"
REM # location of the lumpmod executable
SET BIN_LUMPMOD="%BIN%\lumpmod\lumpmod.exe"

REM # logging:
REM ----------------------------------------------------------------------------
REM # location of log file
SET LOG_FILE="%BIN%\log.txt"
REM # clear the log file
IF EXIST "%LOG_FILE%" DEL /F "%LOG_FILE%" >NUL 2>&1
REM # failed?
IF ERRORLEVEL 1 (
	ECHO ERROR! Could not clear the log file at:
	ECHO "%LOG_FILE%"
	EXIT /B 1
)

ECHO:
CALL :log_echo "# doom-crusher : v%VER%"
CALL :log_echo "#     feedback : <github.com/Kroc/DOOM-Crusher> or <kroc@camendesign.com>"
REM # display which options have been set
SET "OPTIONS="
IF %DO_PNG% EQU 0 SET "OPTIONS=%OPTIONS%/NOPNG "
IF %DO_JPG% EQU 0 SET "OPTIONS=%OPTIONS%/NOJPG "
IF %DO_WAD% EQU 0 SET "OPTIONS=%OPTIONS%/NOWAD "
IF %DO_PK3% EQU 0 SET "OPTIONS=%OPTIONS%/NOPK3 "
IF %LOSSY%  EQU 1 SET "OPTIONS=%OPTIONS%/LOSSY "
IF %ZSTORE% EQU 1 SET "OPTIONS=%OPTIONS%/ZSTORE "
IF NOT DEFINED CACHE SET "OPTIONS=%OPTIONS%/NOCACHE"
IF DEFINED OPTIONS (
	CALL :log_echo "#      options : %OPTIONS%"
)
CALL :log_echo "###############################################################################"

REM # create a temporary folder for all temp files this process creates.
REM # this will allow (though it's not recommended) more than one instance
REM # of doom-crusher.bat to run simultaneously

REM # generate a unique ID by stripping the
REM # non-digit characters from the current time
SET "TEMP_SLUG=%TIME%"
SET "TEMP_SLUG=%TEMP_SLUG::=%"
SET "TEMP_SLUG=%TEMP_SLUG:,=%"
SET "TEMP_SLUG=%TEMP_SLUG:.=%"
SET "TEMP_SLUG=%TEMP_SLUG: =%"
REM # now add a random number, just-in-case
SET "TEMP_SLUG=%TEMP_SLUG%.%RANDOM%"
REM # package it up into a full path
SET "TEMP_DIR=%TEMP%\doom-crusher~%TEMP_SLUG%"

REM # try create the directory
MKDIR "%TEMP_DIR%"  >NUL 2>&1
REM # did that fail?
IF ERRORLEVEL 1 (
	ECHO ERROR! Could not create temporary directory:
	ECHO "%TEMP_DIR%"
	EXIT /B 1
)

REM # we'll change the window title during processing
SET "TITLE=doom-crusher.bat"
TITLE %TITLE%

REM # process parameter list:
REM ============================================================================
:params

REM # check if parameter is a directory
REM # (this returns the file attributes, a "d" is added for directories)
SET "ATTR=%~a1"
IF /I "%ATTR:~0,1%" == "d" (
	CALL :optimize_dir "%~f1"
) ELSE (
	REM # otherwise, it's a file path
	SET FILE="%~f1"	
	CALL :optimize_file
)

:param_next
REM # is there another parameter?
SHIFT
IF NOT "%~1" == "" GOTO :params

CALL :log_echo "###############################################################################"
CALL :log_echo "# complete"
ECHO:

REM # clean-up:
REM # remove the temporary directory (intentional duplicate)
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1
IF EXIST "%TEMP_DIR%" RMDIR /S /Q "%TEMP_DIR%"  >NUL 2>&1

PAUSE
REM # clear the title
TITLE %COMSPEC%
EXIT /B 0

	
REM ============================================================================

:optimize_dir
	REM # search a directory (and sub-directories) for optimisable files
	REM #
	REM #	1 = directory-path
	REM #
	REM # returns ERRORLEVEL 0 if there were no errors in any of the files
	REM # optimised, otherwise ERRORLEVEL 1 where any file could not be
	REM # optimised (this includes skipped files)
	REM --------------------------------------------------------------------
	REM # localise this routine so variables don't conflict
	REM # for files within files, e.g. PK3>WAD>PNG
	SETLOCAL
	SET ERROR=0
	
	REM # the `FOR /R` loop works most reliably
	REM # from the directory in question
	PUSHD %1
	REM # scan the directory given for crushable files:
	REM # note that "*." is a special term to select all files *without* an
	REM # extension, but will also pick up files that begin with a dot
	REM # (e.g. ".gitignore")
	FOR /R "." %%G IN (*.jpg;*.jpeg;*.png;*.wad;*.iwad;*.pk3;*.ipk3;*.pke;*.epk;*.kart;*.lmp;*.) DO (
		SET FILE="%%G"
		CALL :optimize_dir__file
	)
	REM # put that thing back where it came from, or so help me
	POPD
	
	REM # return result
	(ENDLOCAL
		REM # this variable needs to remain "global"
		SET DOT=%DOT%
	) & 	EXIT /B %ERROR%
	
:optimize_dir__file
	REM --------------------------------------------------------------------
	REM # optimize individual file -- PK3 files will be unpacked and the
	REM # contents optimized recursively
	CALL :optimize_file
	REM # if any one file errors, we do continue with the scan
	REM # but will pass back a final ERRORLEVEL of 1
	IF ERRORLEVEL 1 SET ERROR=1
	GOTO:EOF

:optimize_file
	REM # determine the file type of a file and process it accordingly
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if optimisation succeeded,
	REM # ERRORLEVEL 1 if it failed or was skipped
	REM --------------------------------------------------------------------
	REM # localise this routine so variables don't conflict
	REM # for files within files, e.g. PK3>WAD>PNG
	SETLOCAL
	SET ERROR=0
	REM # remember the current title to return to afterwards;
	REM # this allows us to easily display nested file names
	SET "OLDTITLE=%TITLE%"
	
	REM # determine the file type
	CALL :get_filetype
	REM # if not a recognised file type, skip the file
	IF "%TYPE%" == "" GOTO :file_skip
	
	REM # we skip (classic) IWADs to avoid breaking
	REM # detection routines in various DOOM engines
	REM # TODO: should show a specific skip message for IWADs?
	IF "%TYPE%" == "iwad" GOTO :file_skip
	
	REM # we won't waste time hashing
	REM # files that we are automatically skipping
	IF "%TYPE%-%DO_JPG%" == "jpg-0" GOTO :file_ignored
	IF "%TYPE%-%DO_PNG%" == "png-0" GOTO :file_ignored
	IF "%TYPE%-%DO_WAD%" == "wad-0" GOTO :file_ignored
	IF "%TYPE%-%DO_PK3%" == "pk3-0" GOTO :file_ignored
	
	REM # check the cache
	CALL :hash_check
	REM # if in the cache, skip the file
	IF %ERRORLEVEL% EQU 0 GOTO :file_skip
	
	REM # get the current file-size before optimisation
	FOR %%G IN (%FILE%) DO (
		SET FILESIZE_OLD=%%~zG
		SET "TITLE=%TITLE% : %%~nxG"
	)
	TITLE %TITLE%
	
	REM # call the sub-routine for the particular type
	CALL :optimize_%TYPE%
	REM # did that fail in some way?
	IF ERRORLEVEL 1 SET ERROR=1 & GOTO :file_return
	
	REM # get the new file-size, post optimisation
	FOR %%G IN (%FILE%) DO SET FILESIZE_NEW=%%~zG
	REM # file increased in size?
	IF %FILESIZE_NEW% GTR %FILESIZE_OLD% GOTO :file_return
	
	REM # file has changed, add to the cache
	CALL :hash_add
	GOTO :file_return
	
	:file_ignored
	REM # mark as an error so that any container (PK3/WAD) won't be cached
	SET ERROR=1
	:file_skip
	REM # display a progress dot
	CALL :dot
	:file_return
	REM # restore the title to its previous value
	TITLE %OLDTITLE%
	(ENDLOCAL
		REM # this variable needs to remain "global"
		SET DOT=%DOT%
	) & 	EXIT /B %ERROR%

:optimize_pk3
	REM # optimise a PK3 file, and its contents
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if optimisation
	REM # succeeded, ERRORLEVEL 1 if it failed
	REM --------------------------------------------------------------------
	REM # localise this routine so variables don't conflict
	REM # for files within files, e.g. PK3>WAD>PNG
	SETLOCAL
	SET ERROR=0
	REM # we'll avoid displaying the split-line if the PK3
	REM # doesn't contain any files we can optimise
	SET ANY=0
	
	REM # display file name and current file size
	CALL :display_status_left
	
	REM # get the file name without losing special characters
	FOR %%G IN (%FILE%) DO SET FILE_NAME=%%~nxG
	REM # remove the special characters
	SET "FILE_NAME=%FILE_NAME:!=_%"
	SET "FILE_NAME=%FILE_NAME: =_%"
	SET "FILE_NAME=%FILE_NAME:[=_%"
	SET "FILE_NAME=%FILE_NAME:]=_%"
	SET "FILE_NAME=%FILE_NAME:(=_%"
	SET "FILE_NAME=%FILE_NAME:)=_%"
	SET "FILE_NAME=%FILE_NAME:{=_%"
	SET "FILE_NAME=%FILE_NAME:}=_%"
	SET "FILE_NAME=%FILE_NAME:;=_%"
	SET "FILE_NAME=%FILE_NAME:'=_%"
	SET "FILE_NAME=%FILE_NAME:&=_%"
	SET "FILE_NAME=%FILE_NAME:^=_%"
	SET "FILE_NAME=%FILE_NAME:$=_%"
	SET "FILE_NAME=%FILE_NAME:#=_%"
	SET "FILE_NAME=%FILE_NAME:@=_%"

	REM # we'll unpack the PK3 to a temporary directory
	SET "TEMP_PK3DIR=%TEMP_DIR%\%FILE_NAME%~%RANDOM%"
	SET "TEMP_PK3=%TEMP_PK3DIR%\%FILE_NAME%"
	REM # attempt to create the temporary folder...
	MKDIR "%TEMP_PK3DIR%"  >NUL 2>&1
	REM # failed?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "! error <mkdir>"
		CALL :log_echo "###############################################################################"
		CALL :log_echo
		CALL :log_echo "ERROR: Could not create temporary directory:"
		CALL :log_echo "%TEMP_PK3DIR%"
		CALL :log_echo
		GOTO :die
	)
	
	REM # unpack the PK3:
	
	REM # display something on the console to indicate what's happening
	SET "STATUS_LEFT=%STATUS_LEFT%: unpacking... "
	<NUL (SET /P "$=: unpacking... ")
	
	REM # 7zip:
	REM #	x		: "extract" (with subfolders)
	REM #	-aos		: overwrite files
	REM #	-o"..."		: output folder
	REM #	-tzip		: assume ZIP file, despite file-extension
	REM #	--		: stop processing switches, source-file follows
	%BIN_7ZA% x -aos -o"%TEMP_PK3DIR%" -tzip -x@"%BIN%\pk3_ignore.lst" -- %FILE%  >NUL 2>&1
	
	IF ERRORLEVEL 1 (
		REM # cap the status line
		CALL :display_status_msg "err!"
		CALL :log_echo "==============================================================================="
		
		REM # if a PK3 file cannot be unpacked at all, add it to the
		REM # error cache to be ignored automatically in the future
		CALL :hash_add_error

		REM # redo the decompression, displaying results on screen
		REM # TODO: should be capturing this to the log file during the first run
		%BIN_7ZA% x -aos -o"%TEMP_PK3DIR%" -tzip -x@"%BIN%\pk3_ignore.lst" -- %FILE%
		
		ECHO: & PAUSE & ECHO:

		REM # quit with error level set
		SET ERROR=1 & GOTO :optimize_pk3__return
	)
	
	REM # cap the status line to say that the unpacked succeeded
	CALL :display_status_msg "done"
	REM # underscore the PK3 to show we're exploring the contents
	CALL :log_echo "  ============================================================================="
	
	REM # with the PK3 unpacked, we can optimise the directory like any
	REM # other. note that this will set the `ANY_*` variables according
	REM # to which file-types are encountered
	CALL :optimize_dir "%TEMP_PK3DIR%"
	REM # if any individual file failed to optimize, we will repack
	REM # the PK3, but not add it to the cache so that it will be
	REM # retried in the future
	IF ERRORLEVEL 1 SET ERROR=1
	
	CALL :log_echo "  ============================================================================="
	
	REM # repack the PK3:
	REM # switch to the temporary directory so that the PK3 files are
	REM # at the base of the ZIP file rather than in a sub-folder
	PUSHD "%TEMP_PK3DIR%"
	
	REM # are we using compression or not?
	REM # PRO TIP: a PK3 file made without compression will boot faster in
	REM #          your DOOM engine of choice, and will aid compression of
	REM #          multiple PK3s together in 7Zip / WinRAR when using
	REM #          a large (128+MB) dictionary
	IF %ZSTORE% EQU 1 (
		REM # use no compression
		SET REPACK_PK3=%BIN_7ZA% a "%TEMP_PK3%" -bso0 -bsp1 -bse0 -tzip -r -mx0 -x@"%BIN%\pk3_ignore.lst" -- *
	) ELSE (
		REM # use maximum compression (for a standard zip file)
		SET REPACK_PK3=%BIN_7ZA% a "%TEMP_PK3%" -bso0 -bsp1 -bse0 -tzip -r -mx9 -mfb258 -mpass15 -x@"%BIN%\pk3_ignore.lst" -- *
	)
	
	%REPACK_PK3%
	IF ERRORLEVEL 1 (
		CALL :log_echo
		CALL :log_echo "ERROR: Could not repack the PK3."
		CALL :log_echo
		
		REM # if a PK3 file cannot be repacked at all, add it to the
		REM # error cache to be ignored automatically in the future
		CALL :hash_add_error

		%REPACK_PK3%
		
		POPD
		SET ERROR=1 & GOTO :optimize_pk3__return
	)
	
	REM # display the original file size before replacing with the new one
	CALL :display_status_left
	
	REM # replace the original PK3 file with the new one
	COPY /Y "%TEMP_PK3%" %FILE%  >NUL 2>&1
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "! error <copy>"
		CALL :log_echo
		CALL :log_echo "ERROR: Could not replace the original PK3 with the new version."
		CALL :log_echo
		
		POPD
		SET ERROR=1 & GOTO :optimize_pk3__return
	)
	
	REM # deflopt the PK3:
	REM # no need to deflopt the PK3 if it's uncompressed!
	IF %ZSTORE% EQU 1 GOTO :optimize_pk3__end
	
	REM # running deflopt can shave off a few more
	REM # bytes off of any DEFLATE-based content
	CALL :optimize_deflopt
	REM # if that errored we won't cache the PK3
	IF ERRORLEVEL 1 SET ERROR=1
	
	:optimize_pk3__end
	REM # display the new file-size
	CALL :display_status_right
	
	:optimize_pk3__return
	ENDLOCAL & SET DOT=0 & EXIT /B %ERROR%
	
:optimize_wad
	REM # optimise the given WAD file
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if optimisation
	REM # succeeded, ERRORLEVEL 1 if it failed
	REM --------------------------------------------------------------------
	REM # localise this routine so variables don't conflict
	REM # for files within files, e.g. PK3>WAD>PNG
	SETLOCAL
	REM # we'll avoid displaying the split-line if the WAD doesn't
	REM # contain any lumps we can optimise
	SET ANY=0
	REM # if the WAD or internal JPG/PNG optimisation fails, return an
	REM # error state; if the WAD was from a PK3 then it will *not* be
	REM # cached so that it will always be retried in the future until
	REM # there are no errors (we do not want to write off a PK3 as
	REM # "done" when there are potential savings remaining)
	SET ERROR=0
	
	REM # display file name and current file size
	CALL :display_status_left
	
	REM # get the file name without special characters breaking parsing
	FOR %%G IN (%FILE%) DO SET WAD_NAME=%%~nxG
	REM # remove the special characters
	SET "WAD_NAME=%WAD_NAME:!=_%"
	SET "WAD_NAME=%WAD_NAME: =_%"
	SET "WAD_NAME=%WAD_NAME:[=_%"
	SET "WAD_NAME=%WAD_NAME:]=_%"
	SET "WAD_NAME=%WAD_NAME:(=_%"
	SET "WAD_NAME=%WAD_NAME:)=_%"
	SET "WAD_NAME=%WAD_NAME:{=_%"
	SET "WAD_NAME=%WAD_NAME:}=_%"
	SET "WAD_NAME=%WAD_NAME:;=_%"
	SET "WAD_NAME=%WAD_NAME:'=_%"
	SET "WAD_NAME=%WAD_NAME:&=_%"
	SET "WAD_NAME=%WAD_NAME:^=_%"
	SET "WAD_NAME=%WAD_NAME:$=_%"
	SET "WAD_NAME=%WAD_NAME:#=_%"
	SET "WAD_NAME=%WAD_NAME:@=_%"
	
	REM # wadptr is extremely buggy and might just decide to process every
	REM # WAD in the same folder even though you gave it a single file
	REM # name. to make this process more reliable we'll set up a temporary
	REM # sub-folder and copy the WAD into there to isolate it from other
	REM # WAD files and stuff
	SET "TEMP_WADDIR=%TEMP_DIR%\%WAD_NAME:.=_%~%RANDOM%"
	SET TEMP_WAD="%TEMP_WADDIR%\%WAD_NAME%"
	REM # attempt to create the temporary folder...
	MKDIR "%TEMP_WADDIR%"  >NUL 2>&1
	REM # failed?
	IF ERRORLEVEL 1 (
		CALL :display_status_msg "! error <mkdir>"
		CALL :log_echo "###############################################################################"
		CALL :log_echo
		CALL :log_echo "ERROR: Could not create temporary directory:"
		CALL :log_echo "%TEMP_WADDIR%"
		CALL :log_echo
		GOTO :die
	)
	REM # copy the WAD to the temporary directory; we could save a lot of
	REM # I/O if we moved it and then moved it back when we were done,
	REM # but if the script is stopped or crashes we don't want to
	REM # misplace the original files
	COPY /Y %FILE% %TEMP_WAD%  >NUL 2>&1
	REM # did the copy fail?
	IF ERRORLEVEL 1 (
		REM # cap the status line to say that the copy errored
		CALL :display_status_msg "! error <copy>"
		CALL :log_echo "###############################################################################"
		CALL :log_echo
		CALL :log_echo "ERROR: Could not copy WAD:
		CALL :log_echo %FILE%
		CALL :log_echo
		CALL :log_echo "to temporary copy:"
		CALL :log_echo %TEMP_WAD%
		CALL :log_echo
		GOTO :die
	)
	
	REM # list the WAD contents and get the name and length of each lump:
	REM # lumpmod.exe has been modified to also provide the filetype, with
	REM # thanks to _mental_. Kroc has modified lumpmod.exe to wrap the
	REM # lump name with quotes to be able to handle lump names containing
	REM # spaces, these cannot be passed as a parameter so we have to pass
	REM # by variable instead
	
	REM # NB: use of quotes in a FOR command here is fraught with
	REM #     complications: http://stackoverflow.com/questions/22636308
	FOR /F "eol= delims=" %%G IN (
		'^" %BIN_LUMPMOD% %TEMP_WAD% list -v "^"'
	) DO SET "LUMPINFO=%%G" & CALL :optimize_lump
	
	REM # mark the end of WAD contents if any lump was optimised
	IF %ANY% EQU 1 (
		CALL :log_echo "  -----------------------------------------------------------------------------"
		CALL :display_status_left
	)
	
	TITLE %OLDTITLE%
	
	REM # use wadptr to optimize a WAD:
	
	REM # change to the temporary directory, wadptr is prone to choking on
	REM # absolute/relative paths, it's best to give it a single file name
	REM # within the current directory
	PUSHD "%TEMP_WADDIR%"

	REM # wadptr:
	REM # 	-c	: compress
	REM # 	-nopack	: skip sidedef packing as this can cause map glitches
	%BIN_WADPTR% -c -nopack "%WAD_NAME%"  >NUL 2>&1
	REM # if this errors, the WAD won't have been changed so we can continue
	IF ERRORLEVEL 1 (
		REM # cap the status line to say that wadptr errored,
		REM # but otherwise continue
		CALL :display_status_msg "! error <wadptr>"
		REM # note error state so that the WAD will not be cached
		SET ERROR=1
		REM # add file to the error cache,
		REM # this can be used to ignore faulty files in the future
		CALL :hash_add_error

		%BIN_WADPTR% -c -nopack "%WAD_NAME%"
		PAUSE
	)
	REM # can leave the directory now
	REM # (the copy below uses absolute paths)
	POPD
	
	REM # TODO: if no change the WAD occurred,
	REM #       do not copy it back nor re-add to the cache
	
	IF %ERROR% EQU 0 (
		REM # temporary WAD has been optimized, replace the original
		REM # (if this were to error just continue with the clean-up)
		COPY /Y %TEMP_WAD% %FILE%  >NUL 2>&1
		IF ERRORLEVEL 1 (
			CALL :display_status_msg "! error <copy>"
			CALL :log_echo
			CALL :log_echo "ERROR: Could not replace the original WAD with the new version."
			CALL :log_echo
			ENDLOCAL & SET DOT=0 & EXIT /B 1
		) ELSE (
			REM # cap status line with the new file size
			CALL :display_status_right
		)
	)
	
	REM # remove the temporary directory (intentional duplicate)
	IF EXIST "%TEMP_WADDIR%" RMDIR /S /Q "%TEMP_WADDIR%"  >NUL 2>&1
	IF EXIST "%TEMP_WADDIR%" RMDIR /S /Q "%TEMP_WADDIR%"  >NUL 2>&1
	
	ENDLOCAL & SET DOT=0 & EXIT /B %ERROR%
	
:optimize_lump
	REM # optimize a WAD lump
	REM #
	REM #	`TEMP_WAD` contains the path of the source wad file
	REM #	`LUMPINFO` contains a lump record from lumpmod.exe
	REM #
	REM # returns ERRORLEVEL 0 if successful, or ERRORLEVEL 1 for any
	REM # failure. if a lump is skipped because it is not optimisable,
	REM # ERRORLEVEL 0 is still returned
	REM --------------------------------------------------------------------
	SETLOCAL ENABLEDELAYEDEXPANSION
	SET ERROR=0
	
	REM # extract size of lump in bytes from record
	SET "LUMP_SIZE=!LUMPINFO:~17,9!"
	REM # lumps of length 0 are just markers and can be skipped
	IF "%LUMP_SIZE%" == "0"   GOTO :lump_skip
	
	REM # extract lump data type from record ("PNG", "JPG" or "LMP")
	SET "LUMP_TYPE=!LUMPINFO:~27,3!"
	REM # only process JPG or PNG lumps
	IF "%LUMP_TYPE%" == "LMP" GOTO :lump_skip
	REM # are we ignoring JPG / PNGs?
	IF "%LUMP_TYPE%-%DO_JPG%" == "JPG-0" GOTO :lump_skip
	IF "%LUMP_TYPE%-%DO_PNG%" == "PNG-0" GOTO :lump_skip
	
	REM # extract fields from the lumpmod record:
	SET LUMP_ID=!LUMPINFO:~0,5!
	SET LUMP_NAME=!LUMPINFO:~6,10!
	REM # remove the wrapping quotes (but not any quotes within)
	CALL :remove_quotes LUMP_NAME !LUMP_NAME!
	
	REM # ensure the lump name can be written to disk
	REM # (may contain invalid file-system characters)
	REM # TODO : handle astrisk, very difficult to do properly
	SET "FILE=!LUMP_NAME!"
	SET "FILE=%FILE:<=_%"
	SET "FILE=%FILE:>=_%"
	SET "FILE=%FILE: =_%"
	SET "FILE=%FILE:.=_%"
	SET "FILE=%FILE:[=_%"
	SET "FILE=%FILE:]=_%"
	SET "FILE=%FILE:(=_%"
	SET "FILE=%FILE:)=_%"
	SET "FILE=%FILE:{=_%"
	SET "FILE=%FILE:}=_%"
	SET "FILE=%FILE::=_%"
	SET "FILE=%FILE:;=_%"
	SET 'FILE=%FILE:"=_%'
	SET "FILE=%FILE:/=_%"
	SET "FILE=%FILE:\=_%"
	SET "FILE=%FILE:|=_%"
	SET "FILE=%FILE:?=_%"
	SET "FILE=%FILE:!=_%"
	SET "FILE=%FILE:&=_%"
	SET "FILE=%FILE:^=_%"
	SET "FILE=%FILE:$=_%"
	SET "FILE=%FILE:#=_%"
	SET "FILE=%FILE:@=_%"
	REM # this is where the lump will go
	SET FILE="%TEMP_DIR%\%FILE%.%LUMP_TYPE%"
	
	REM # extract the lump to disk to optimize it
	%BIN_LUMPMOD% %TEMP_WAD% extract "!LUMP_NAME!" %FILE%  >NUL 2>&1
	REM # only continue if this succeeded:
	REM # (do not allow a containing PK3/WAD file to be cached)
	REM # TODO: display the file status line to show a lumpmod error?
	IF ERRORLEVEL 1 (
		REM # since the lump has not actually been processed yet,
		REM # its name isn't on screen
		CALL :display_status_left
		CALL :display_status_msg "^! error <lumpmod>"
		CALL :log_echo
		CALL :log_echo "ERROR: Could not extract lump:"
		CALL :log_echo "!LUMP_NAME!"
		CALL :log_echo
		CALL :log_echo "From WAD:"
		CALL :log_echo "!TEMP_WAD!"
		CALL :log_echo
		GOTO :lump_error
	)
	
	REM # display the split-line to indicate WAD contents
	CALL :any_ok
	
	REM # process the lump like any other file.
	REM # if the lump has been cached, this will return "success"
	CALL :optimize_file
	REM # return failure of optimisation
	IF ERRORLEVEL 1 GOTO :lump_error
	
	REM # was the lump omptimized?
	REM # (the orginal lump size is already in `LUMP_SIZE`)
	FOR %%G IN (%FILE%) DO SET NEWSIZE=%%~zG
	REM # compare sizes; if not smaller, leave the original file
	IF %NEWSIZE% GEQ %LUMP_SIZE% GOTO :lump_return
	
	REM # put the lump back into the WAD
	%BIN_LUMPMOD% %TEMP_WAD% update "!LUMP_NAME!" %FILE%  >NUL 2>&1
	REM # if that errored we won't cache the WAD
	IF ERRORLEVEL 1 (
		CALL :log_echo
		CALL :log_echo 'ERROR: Could not update lump: "!LUMP_NAME!" in file:'
		CALL :log_echo '!FILE!'
		CALL :log_echo
		CALL :log_echo "Into WAD file:"
		CALL :log_echo "!TEMP_WAD!"
		CALL :log_echo
		GOTO :lump_error
	)
	REM # exit with the result
	GOTO :lump_return
	
	:lump_skip
	REM # the lump can't/won't be optimized, show a dot on screen to
	REM # demonstrate progress. if the split line hasn't been shown yet,
	REM # do so now
	IF %ANY% EQU 0 CALL :any_ok
	REM # display a dot (and manage line-wrapping)
	CALL :dot
	GOTO :lump_return
	
	:lump_error
	SET ERROR=1
	REM # add file to the error cache,
	REM # this can be used to ignore faulty files in the future
	CALL :hash_add_error

	:lump_return
	REM # return our error-state
	(ENDLOCAL
		SET ANY=%ANY%
		SET DOT=%DOT%
		REM # for convenience we set the error variable of the parent,
		REM # minimizing the FOR ... DO complexity
		SET ERROR=%ERROR%
	) & EXIT /B %ERROR%

:remove_quotes
	FOR %%G IN (%2) DO SET "%1=%%~G"
	GOTO:EOF
	
:optimize_jpg
	REM # optimise the given JPG file
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if optimisation
	REM # succeeded, ERRORLEVEL 1 if it failed
	REM --------------------------------------------------------------------
	REM # display file name and current file size
	CALL :display_status_left
	
	REM # jpegtran:
	REM #	-optimize	: optimize without quality loss
	REM # 	-copy none	: don't keep any metadata
	%BIN_JPEG% -optimize -copy none %FILE% %FILE%  >NUL 2>&1
	IF ERRORLEVEL 1 (
		REM # add file to the error cache,
		REM # this can be used to ignore faulty files in the future
		CALL :hash_add_error
		REM # cap the status line
		CALL :display_status_msg "! error <jpegtran>"
		REM # if JPG optimisation failed, return an error state;
		REM # if the JPG was from a WAD or PK3 then these will *not*
		REM # be cached so that they will always be retried in the
		REM # future until there are no errors (we do not want to
		REM # write off a WAD or PK3 as "done" when there are
		REM # potential savings remaining)
		EXIT /B 1
	) ELSE (
		REM # cap status line with the new file size
		CALL :display_status_right
	)
	EXIT /B 0

:optimize_png
	REM # optimise the given PNG file
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if optimisation
	REM # succeeded, ERRORLEVEL 1 if it failed
	REM --------------------------------------------------------------------
	REM # PNG optimisation occurs over several stages and we need to be
	REM # aware if any one stage fails
	SETLOCAL
	SET ERROR=0
	SET ERRORS=0
	
	REM # display file name and current file size
	CALL :display_status_left
	
	REM # optimise with pngquant -- lossy!
	IF %LOSSY% EQU 1 CALL :optimize_pngquant

	REM # optimise with optipng:
	CALL :optimize_optipng
	REM # if that failed:
	IF ERRORLEVEL 1 (
		REM # cap the status line
		CALL :display_status_msg "! error <optipng>"
		REM # reprint the status line for the next iteration
		CALL :display_status_left
		REM # if all of the PNG tools fail,
		REM # do not add the file to the cache
		SET /A "ERRORS=ERRORS+1"
	)
	
	REM # optimise with pngout:
	CALL :optimize_pngout
	REM # if that failed:
	IF ERRORLEVEL 1 (
		REM # cap the status line
		CALL :display_status_msg "! error <pngout>"
		REM # reprint the status line for the next iteration
		CALL :display_status_left
		REM # if all of the PNG tools fail,
		REM # do not add the file to the cache
		SET /A "ERRORS=ERRORS+1"
	)
	
	REM # optimise with pngcrush:
	CALL :optimize_pngcrush
	REM # if that failed:
	IF ERRORLEVEL 1 (
		REM # cap the status line
		CALL :display_status_msg "! error <pngcrush>"
		REM # reprint the status line for the next iteration
		CALL :display_status_left
		REM # if all of the PNG tools fail,
		REM # do not add the file to the cache
		SET /A "ERRORS=ERRORS+1"
	)
	
	REM # optimise with deflopt:
	CALL :optimize_deflopt
	REM # if that failed:
	IF ERRORLEVEL 1 (
		REM # cap the status line
		REM # note: error of deflopt is not critical
		CALL :display_status_msg "! error <deflopt>"
	) ELSE (
		REM # cap status line with the new file size
		CALL :display_status_right
	)

	REM # if optimisation failed, add to the error cache.
	REM # this can be used to ignore faulty files in the future
	IF %ERRORS% EQU 3 (
		CALL :hash_add_error
		SET ERROR=1
	)
	
	REM # if all of the PNG passes failed, return an error state; if the
	REM # PNG was from a WAD or PK3 then these will *not* be cached so that
	REM # they will always be retried in the future until there are no
	REM # errors (we do not want to write off a WAD or PK3 as "done" when
	REM # there are potential savings remaining)
	ENDLOCAL & SET DOT=0 & EXIT /B %ERROR%
	
:optimize_pngquant
	REM # optimise a PNG file using pngquant
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if successful (or pngquant not present),
	REM # or ERRORLEVEL 1 for an error
	REM --------------------------------------------------------------------
	REM # skip if binary not present
	IF NOT EXIST %BIN_PNGQUANT% EXIT /B 0

	DEL /F "%TEMP_DIR%\pngquant-in.png"   >NUL 2>&1
	DEL /F "%TEMP_DIR%\pngquant-out.png"  >NUL 2>&1

	COPY /Y %FILE% "%TEMP_DIR%\pngquant-in.png"  >NUL

	%BIN_PNGQUANT% --force --output "%TEMP_DIR%\pngquant-out.png" --quality=65-100 --skip-if-larger --speed 1 256 -- "%TEMP_DIR%\pngquant-in.png"

	IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

	COPY /Y "%TEMP_DIR%\pngquant-out.png" %FILE%  >NUL
	EXIT /B %ERRORLEVEL%

:optimize_optipng
	REM # optimise a PNG file using optipng
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if successful (or optipng not present),
	REM # or ERRORLEVEL 1 for an error
	REM --------------------------------------------------------------------
	REM # skip if binary not present
	IF NOT EXIST %BIN_OPTIPNG% EXIT /B 0
	
	REM # optipng:
	REM # 	-clobber	: overwrite input file
	REM # 	-fix		: try to fix/work-around CRC errors
	REM # 	-07       	: maximum compression level
	REM # 	-i0       	: non-interlaced
	%BIN_OPTIPNG% -clobber -fix -o7 -i0 -- %FILE%  >NUL 2>&1
	REM # return the error state
	EXIT /B %ERRORLEVEL%

:optimize_pngout
	REM # optimise a PNG file using pngout
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if successful (or pngout not present),
	REM # or ERRORLEVEL 1 for an error
	REM --------------------------------------------------------------------
	REM # skip if not present
	IF NOT EXIST %BIN_PNGOUT% EXIT /B 0
	
	REM # pngout:
	REM #	/k...	: keep chunks
	REM # 	/y	: assume yes (overwrite)
	REM # 	/q	: quiet
	%BIN_PNGOUT% %FILE% /kgrAb,alPh /y /q  >NUL 2>&1
	REM # return the error state:
	REM # NOTE: pngout returns 2 for "unable to compress further",
	REM #       technically not an error!
	IF ERRORLEVEL 3 EXIT /B 1
	IF ERRORLEVEL 2 EXIT /B 0
	IF ERRORLEVEL 1 EXIT /B 1
	EXIT /B 0

:optimize_pngcrush
	REM # optimise a PNG file using pngout
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if successful (or pngcrush not present),
	REM # or ERRORLEVEL 1 for an error
	REM --------------------------------------------------------------------
	REM # skip if not present
	IF NOT EXIST %BIN_PNGCRUSH% EXIT /B 0
	
	REM # pngcrush:
	REM # 	-nobail   : don't stop trials if filesize hasn't improved (yet)
	REM # 	-blacken  : sets bg-color of fully-transparent pixels to 0
	REM # 	-brute	  : tries 148 methods for max. compression (slow)
	REM # 	-keep ... : keep chunks
	REM # 	-l 9	  : maximum compression level
	REM # 	-noforce  : do not overwrite smaller file with larger one
	REM # 	-ow	  : overwrite the original file
	REM # 	-reduce	  : try reducing colour-depth if possible
	%BIN_PNGCRUSH% -nobail -blacken -brute -keep grAb -keep alPh -l 9 -noforce -ow -reduce %FILE%  >NUL 2>&1
	REM # return the error state
	EXIT /B %ERRORLEVEL%

:optimize_deflopt
	REM # optimise any FLATE-based file type
	REM # (e.g. PNG or ZIP)
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if successful (or deflopt not present),
	REM # or ERRORLEVEL 1 for an error
	REM --------------------------------------------------------------------
	REM # skip if not present
	IF NOT EXIST %BIN_DEFLOPT% EXIT /B 0
	
	REM # deflopt:
	REM # 	/a	: examine the file contents to determine if it's
	REM #             compressed (rather than extension alone)
	REM # 	/k	: keep extra chunks (we *must* preserve "grAb"
	REM #             and "alPh" for DOOM)
	%BIN_DEFLOPT% /a /k %FILE%  >NUL 2>&1
	REM # return the error state
	EXIT /B %ERRORLEVEL%

REM ============================================================================

:get_filetype
	REM # determines the type of a file by its extension,
	REM # and if that's not possible, examines the file header
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns "jpg", "png", "wad"/"iwad", "pk3" for known types,
	REM # or "" for unknown type in the `TYPE` variable
	REM --------------------------------------------------------------------
	REM # by default, return blank
	SET "TYPE="
	
	REM # get the file-extension from the `FILE` variable
	FOR %%G IN (%FILE%) DO SET EXT=%%~xG
	
	REM # recognize modern DOOM archive files by their extension
	REM # rather than their file-header, since all are just renamed
	REM # ZIP files and we don't want to process non-DOOM ".zip" files
	IF /I "%EXT%" == ".pk3"  SET "TYPE=pk3" & GOTO:EOF
	IF /I "%EXT%" == ".ipk3" SET "TYPE=pk3" & GOTO:EOF
	IF /I "%EXT%" == ".pke"  SET "TYPE=pk3" & GOTO:EOF
	IF /I "%EXT%" == ".epk"  SET "TYPE=pk3" & GOTO:EOF
	IF /I "%EXT%" == ".kart" SET "TYPE=pk3" & GOTO:EOF
	REM # we will process ".iwad" files as even though these are WAD files
	REM # and not zip-files internally, they are modern and do not need
	REM # to be preseved exactly
	IF /I "%EXT%" == ".iwad" SET "TYPE=wad" & GOTO:EOF

	REM # use filetype.exe to examine the file-header:
	REM # we have to change to its directory for this to work
	FOR %%G IN (%BIN_FILETYPE%) DO SET BIN_FILETYPE_PATH=%%~dpG
	PUSHD %BIN_FILETYPE_PATH%

		REM # TODO: this works only because %FILE% is assumed
		REM #       to not contain brackets or speech-marks!

		REM # NB: use of quotes in a FOR command here
		REM #     is fraught with complications:
		REM #     http://stackoverflow.com/questions/22636308
		REM # NB: also, using speech-marks as delimiters:
		REM #     https://stackoverflow.com/a/13217838
		FOR /F eol^=^*^ tokens^=2^,4^ delims^=^(^)^" %%A IN (
			'^" %BIN_FILETYPE% -i %FILE% ^"'
		) DO (
			SET "FILE_EXT=%%A"
			SET "FILE_DESC=%%B"
		)
	POPD
	
	REM # map the return values of the filetype program
	IF /I "%FILE_EXT%" == ".jpg"  ENDLOCAL & SET "TYPE=jpg"  & GOTO:EOF
	IF /I "%FILE_EXT%" == ".png"  ENDLOCAL & SET "TYPE=png"  & GOTO:EOF
	REM # ignore IWAD files that contain IWAD in the file-header
	REM # (a .wad extension is not enough to detect an IWAD)
	IF /I "%FILE_DESC%" == "IWAD Archive" ENDLOCAL & SET "TYPE=iwad" & GOTO:EOF
	REM # all other WAD files (this assumes a "PWAD Archive" description)
	IF /I "%FILE_EXT%" == ".wad"  ENDLOCAL & SET "TYPE=wad"  & GOTO:EOF
	REM # not a file type we deal with, return blank
	GOTO:EOF

:hash_check
	REM # check if a file already exists in the cache
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns ERRORLEVEL 0 if the file is in the cache,
	REM # ERRORLEVEL 1 for any other reason
	REM --------------------------------------------------------------------
	REM # if cache is disabled always return as "file not in cache"
	IF NOT DEFINED CACHE EXIT /B 1
	
	REM # get the path for the hash-cache file
	CALL :hash_name
	
	REM # use of quotes in a FOR command here is fraught with
	REM # complications: http://stackoverflow.com/questions/22636308
	FOR /F "eol=* tokens=* delims=" %%G IN ('^" %BIN_HASH% -s -m %HASHFILE% -m %CACHEDIR%\hashes_error.txt -b %FILE% ^"') DO EXIT /B 0
	EXIT /B 1

:hash_get
	REM # get a hash for a file
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # returns result in `HASH` variable
	REM --------------------------------------------------------------------
	REM # sha1deep:
	REM # 	-s	: silent, don't include non-hash text in the output
	REM # 	-q	: no filename
	REM #
	REM # use of quotes in a FOR command here is fraught with
	REM # complications: http://stackoverflow.com/questions/22636308
	FOR /F "eol=* delims=" %%G IN ('^" %BIN_HASH% -s -q %FILE% ^"') DO @SET "HASH=%%G"
	GOTO:EOF

:hash_add
	REM # add a file to the hash-cache
	REM #
	REM #	`FILE` - the desired file-path
	REM --------------------------------------------------------------------
	REM # if cache is disabled, do nothing
	IF NOT DEFINED CACHE GOTO:EOF
	
	REM # get the path for the hash-cache file
	CALL :hash_name
	
	REM # hash the file:
	REM # the output of the command is full of problems that make it
	REM # difficult to parse in Batch, from padding-spaces to multiple
	REM # space gaps between columns, we need to normalise it first
	CALL :hash_get
	REM # compact multiple spaces into a single colon
	SET "HASH=%HASH:  =:%"
	SET "HASH=%HASH:::=:%"
	SET "HASH=%HASH:::=:%"
	REM # get the file name, without losing special characters
	FOR %%G IN (%FILE%) DO SET FILE_NAME=%%~nxG
	REM # now split the columns
	FOR /F "eol=* tokens=1-2 delims=:" %%G IN ("%HASH%") DO (
		REM # write the hash to the hash-cache
		SETLOCAL ENABLEDELAYEDEXPANSION
		ECHO %%G  !FILE_NAME!>>%HASHFILE%
		ENDLOCAL
	)
	GOTO:EOF

:hash_name
	REM # gets the file-path to the hash-cache to use for the given file
	REM #
	REM #	`FILE` - the desired file-path
	REM #
	REM # sets `HASHFILE` with full path to the hash-cache file to use
	REM --------------------------------------------------------------------
	REM # the different file-types are separated into different hash
	REM # buckets. this is to avoid unecessary slow-down from large buckets
	REM # (png) affecting smaller ones (jpg)
	CALL :get_filetype
	
	REM # pick the filename for the hash-cache
	SET "HASHFILE=%CACHEDIR%\hashes_%TYPE%.txt"
	REM # when the /ZSTORE option is enabled,
	REM # PK3 files use a different hash file
	IF %ZSTORE% EQU 1 (
		IF "%TYPE%" == "pk3" SET "HASHFILE=%CACHEDIR%\hashes_pk3_zstore.txt"
	)
	GOTO:EOF

:hash_add_error
	REM # add a file to the error list
	REM #
	REM #	`FILE` - the desired file-path
	REM --------------------------------------------------------------------
	CALL :hash_get
	REM # compact multiple spaces into a single colon
	SET "HASH=%HASH:  =:%"
	SET "HASH=%HASH:::=:%"
	SET "HASH=%HASH:::=:%"
	REM # get the file name, without losing special characters
	FOR %%G IN (%FILE%) DO SET FILE_NAME=%%~nxG
	REM # now split the columns
	FOR /F "eol=* tokens=1-2 delims=:" %%G IN ("%HASH%") DO (
		REM # write the hash to the hash-cache
		SETLOCAL ENABLEDELAYEDEXPANSION
		ECHO %%G  !FILE_NAME!>>%CACHEDIR%\hashes_error.txt
		ENDLOCAL
	)
	GOTO:EOF

REM ============================================================================
REM # common functions
REM ============================================================================

:log
	REM # write message to log-file only
	REM #
	REM #	%1 - message
	REM --------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"

	REM # now allow the parameter string to be
	REM # written without trying to "execute" it
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
	REM --------------------------------------------------------------------
	IF %DOT% GTR 0 ECHO: & SET DOT=0
	
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"
	
	REM # now allow the parameter string to be
	REM # displayed without trying to "execute" it
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
	REM # display a dot on screen to indicate progress;
	REM # these are batched together into lines
	REM --------------------------------------------------------------------
	REM # increase current dot count
	SET /A DOT=DOT+1
	REM # line wrap?
	IF %DOT% EQU 78 SET DOT=1 & ECHO:
	REM # new line?
	IF %DOT% EQU 1 (
		<NUL (SET /P "$=- .")
	) ELSE (
		REM # display dot, without moving to the next line
		<NUL (SET /P "$=.")
	)
	GOTO:EOF
	
:any_ok
	REM # only display the split line for a WAD
	REM # if there any lumps that will be optimised in the WAD
	IF %ANY% EQU 0 (
		CALL :display_status_msg ": processing..."
		CALL :log_echo "  -----------------------------------------------------------------------------"
		SET ANY=1
		SET DOT=0
	)
	GOTO:EOF
	
:filesize
	REM # get a file size (in bytes):
	REM #
	REM #	`FILE`	= the desired file-path
	REM # 	1	= variable name to set
	REM --------------------------------------------------------------------
	FOR %%G IN (%FILE%) DO SET "%~1=%%~zG"
	GOTO:EOF

:display_status_left
	REM # outputs the status line up to the original file's size:
	REM #
	REM #	`FILE` - the desired file-path
	REM --------------------------------------------------------------------
	REM # get the current file size
	FOR %%G IN (%FILE%) DO SET SIZE_OLD=%%~zG
	REM # get the file name without losing special characters
	FOR %%G IN (%FILE%) DO SET FILE_NAME=%%~nxG
	REM # prepare the status line (column is 35-wide)
	SET "LINE_NAME=%FILE_NAME%                                   "
	SET "LINE_NAME=%LINE_NAME:~0,35%"
	REM # right-align the file size
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # formulate the line
	SET "STATUS_LEFT=* %LINE_NAME% %LINE_OLD% "
	REM # move to the next line if we last printed a progress dot
	IF %DOT% GTR 0 ECHO: & SET DOT=0
	REM # output the status line (without carriage-return)
	<NUL (SET /P "STATUS_LEFT=%STATUS_LEFT%")
	GOTO:EOF

:display_status_right
	REM # assuming that the left-hand status is already displayed,
	REM # append the size-reduction and new file size, and output
	REM # the complete status line to the log
	REM #
	REM #	`FILE` - the desired file-path
	REM --------------------------------------------------------------------
	REM # get the updated file size
	FOR %%G IN (%FILE%) DO SET SIZE_NEW=%%~zG
	REM # no change in size?
	REM # do not log same-size messages, they can greatly bloat the log
	IF %SIZE_NEW% EQU %SIZE_OLD% (
		SET "STATUS_RIGHT==          0 : same size"
		GOTO :display_status_right__echo
	)
	REM # calculate the size difference
	CALL :get_filesize_diff SAVED %SIZE_OLD% %SIZE_NEW%
	REM # format & right-align the size difference
	CALL :format_filesize_bytes SAVED %SAVED%
	REM # increase or decrease in size?
	IF %SIZE_NEW% GTR %SIZE_OLD% SET "SAVED=+%SAVED%"
	IF %SIZE_NEW% LSS %SIZE_OLD% SET "SAVED=-%SAVED%"
	REM # format & right-align the new file size
	CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
	REM # formulate the line
	SET "STATUS_RIGHT=%SAVED% = %LINE_NEW% "
	REM # output the remainder of the status
	REM # line and log the complete status line
	CALL :log "%STATUS_LEFT%%STATUS_RIGHT%"
	
	:display_status_right__echo
	ECHO %STATUS_RIGHT%
	SET DOT=0
	GOTO:EOF
	
:display_status_msg
	REM # append a message to the status line
	REM # and also output it to the log whole:
	REM #
	REM # 	%1 = message
	REM --------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "TEXT=%~1"
	REM # now allow the parameter string to be
	REM # displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # (note that the status line is displayed in two parts in the
	REM #  console, before and after file optimisation, but needs to be
	REM #  output to the log file as a single line)
	ECHO !TEXT!
	CALL :log "%STATUS_LEFT%!TEXT!"
	ENDLOCAL & SET DOT=0 & GOTO:EOF

:get_filesize_diff
	REM # calculate the difference between two file sizes
	SETLOCAL

	SET "OLD=%2"
	SET "NEW=%3"

	IF %OLD% EQU %NEW% (
		REM # return 0%
		SET /A VAL=0
	) ELSE (
		REM # increase or decrease?
		IF %NEW% GTR %OLD% (
			SET /A VAL=NEW-OLD
		) ELSE (
			SET /A VAL=OLD-NEW
		)
	)

	REM # return the size difference in the variable name provided
	ENDLOCAL & SET "%1=%VAL%"
	GOTO:EOF

:format_filesize_bytes
	REM --------------------------------------------------------------------
	SETLOCAL
	REM # add the thousands separators to the number
	CALL :format_number_thousands RESULT %~2
	REM # right-align the number
	SET "RESULT=           %RESULT%"
	SET "RESULT=%RESULT:~-11%"
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF
	
:format_number_thousands
	REM --------------------------------------------------------------------
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


REM ============================================================================
:die
REM # clear the title
TITLE %COMSPEC%