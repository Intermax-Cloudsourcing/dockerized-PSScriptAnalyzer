#!/bin/sh
/opt/microsoft/powershell/6/pwsh -C 'Set-PSReadLineOption -HistorySaveStyle SaveNothing'
opt/microsoft/powershell/6/pwsh
exec "$@"