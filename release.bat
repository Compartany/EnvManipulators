SET /P version=<version.txt
ECHO Version: %version%

gh release create v%version% EnvManipulators.zip