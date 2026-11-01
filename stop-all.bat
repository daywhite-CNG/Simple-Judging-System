@echo off
setlocal
echo 按端口精确停止，不会碰 Nacos(8848) / RabbitMQ(5672) / MySQL / Redis
for %%P in (8080 8090 8101 8102 8103 8104) do call :killport %%P
echo 完成。
exit /b 0

:killport
for /f "tokens=5" %%I in ('netstat -ano ^| findstr ":%1 " ^| findstr LISTENING') do (
    taskkill /F /PID %%I >nul 2>&1
    echo   已停止 :%1  PID=%%I
)
exit /b 0
