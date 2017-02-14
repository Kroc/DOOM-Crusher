@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # get_percentage.bat
REM ====================================================================================================================
REM # calculate the percentage difference between two values

REM # %1 - variable name to set with the result
REM # %2 - the first (old) value
REM # %3 - the second (new) value

REM # NOTES:
REM # * neither number can be greater than or equal to 2'147'483'648 (2 GB in bytes)

REM --------------------------------------------------------------------------------------------------------------------

REM # the largest number we can use before it becomes negative (equivilent to 2 GB in bytes)
SET /A MAXINT=2*1024*1024*1024,MAXINT-=1
REM # the largest number we can multiply by 100 before it becomes too big (approx. 20.9 MB)
SET /A MAX100=MAXINT/100

SET "OLD=%2"
SET "NEW=%3"

REM # if the old number is too large, divide both by 1000 to bring the final calulcation within safe range
IF %OLD% GTR %MAX100% SET /A "OLD/=1000,NEW/=1000"
REM # if the new number is too large, divide both by 1000 to bring the final calulcation within safe range
IF %NEW% GTR %MAX100% SET /A "OLD/=1000,NEW/=1000"

REM # same?
IF %OLD% EQU %NEW% (
	REM # return 0%
	SET /A VAL=0
) ELSE (
	REM # increase or decrease?
	IF %NEW% GTR %OLD% (
		SET /A VAL=100*NEW/OLD
	) ELSE (
		SET /A VAL=100-100*NEW/OLD
	)
)

REM # return the percentage value in the variable name provided
ENDLOCAL & SET "%1=%VAL%"