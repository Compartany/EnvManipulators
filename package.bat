@ECHO OFF

@REM 切换编码为 UTF-8
CHCP 65001

SET archive=archive
SET package=EnvManipulators.zip

lua scripts\init.lua >version.txt
SET /P version=<version.txt
ECHO Version: %version%

if EXIST %package% (
    DEL %package%
    ECHO Delete %package%
)

@REM -r 递归
"%ProgramFiles%/WinRAR/WinRAR" a -r %package% img\
"%ProgramFiles%/WinRAR/WinRAR" a -r %package% scripts\
"%ProgramFiles%/WinRAR/WinRAR" a  %package% "说明.txt"
"%ProgramFiles%/WinRAR/WinRAR" a  %package% "README.txt"
"%ProgramFiles%/WinRAR/WinRAR" a  %package% "version.txt"
ECHO Package %package%

COPY %package% %archive%\%version%.zip
ECHO Archive %version%.zip
