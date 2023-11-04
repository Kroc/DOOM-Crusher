@ECHO %*
@%~dp0advzip.exe -z -4 %*
@IF ERORRLEVEL 1 PAUSE