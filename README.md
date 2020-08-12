# log-rotation-win
Rotate logs in powershell

 ### Usage

As far as I know there is no builtin solution to recycle old log files and oss's are not kept up-to-date much. Therefore there is a custom script running to achieve the same.
Usage is simple as follows.
```
powershell -command "C:\Users\Administrator\util\logrotation.ps1" -LogsPath 'C:\Windows\System32\LogFiles\python\' -FileAgeDays 30 -CreateTime -IncludeFileExtension '.2'
```
There is a `help` documentation describing the full usage. Read it as `Get-Help logrotation.ps1` in `powershell`.
