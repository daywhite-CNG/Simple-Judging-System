@echo off
setlocal

cd /d "%~dp0"

set "SQL=yuoj-backend\mysql-init\create_table.sql"

echo ================================================
echo   鱼 OJ（微服务版）数据库初始化
echo ================================================
echo 将创建数据库 yuoj 及 6 张表：
echo   user / question / question_submit
echo   post / post_thumb / post_favour
echo SQL 文件：%SQL%
echo 说明：脚本内均为 create ... if not exists，重复执行不会清空已有数据
echo.

rem usage 1: init-db.bat root <password>   (non-interactive)
rem usage 2: double-click, then type user and password
if not "%~1"=="" (
    set "MYSQLUSER=%~1"
    set "MYSQLPASS=%~2"
    set "NONINTERACTIVE=1"
) else (
    set /p MYSQLUSER=MySQL user [root]:
    if not defined MYSQLUSER set "MYSQLUSER=root"
    set /p MYSQLPASS=MySQL password:
)

if not exist "%SQL%" (
    echo [ERROR] SQL file not found: %SQL%
    goto :fail
)

mysql -u%MYSQLUSER% -p%MYSQLPASS% < "%SQL%"
if errorlevel 1 (
    echo.
    echo [ERROR] import failed: check mysql.exe on PATH and the credentials.
    goto :fail
)

echo.
echo [OK] done. tables in database yuoj:
mysql -u%MYSQLUSER% -p%MYSQLPASS% -e "use yuoj; show tables;"
echo.
echo next: run promote-admin.sql to grant admin role to a registered account
endlocal
exit /b 0

:fail
if not defined NONINTERACTIVE pause
endlocal
exit /b 1
