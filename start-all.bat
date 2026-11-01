@echo off
setlocal
cd /d "%~dp0"

echo ================================================
echo   鱼 OJ 一键启动
echo   前置：MySQL / Redis / Nacos / RabbitMQ / Docker
echo ================================================
echo [1/3] 代码沙箱
call "%~dp0start-sandbox.bat"
echo [2/3] 后端 4 个服务
call "%~dp0start-backend.bat"
echo [3/3] 前端（前台阻塞，Ctrl+C 结束）
call "%~dp0start-frontend.bat"
exit /b 0
