@ECHO OFF

@REM 切换编码为 UTF-8
CHCP 65001

SET zip=%ProgramFiles%/WinRAR/WinRAR
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
"%zip%" a -r %package% img\
"%zip%" a -r %package% scripts\
"%zip%" a %package% "说明.txt"
"%zip%" a %package% "README.txt"
"%zip%" a %package% "version.txt"
ECHO Package %package%

COPY %package% %archive%\%version%.zip
ECHO Archive %version%.zip
