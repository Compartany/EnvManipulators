@ECHO OFF

@REM 切换编码为 UTF-8
CHCP 65001

:PROMT
SET /P CONFIRM=确认发行吗？请确保本地更新已发布到远程仓库！(y/N)
IF /I "%CONFIRM%" NEQ "y" GOTO END

SET /P version=<version.txt
ECHO Version: %version%

gh release create v%version% EnvManipulators.zip -t v%version%

:END
ECHO done