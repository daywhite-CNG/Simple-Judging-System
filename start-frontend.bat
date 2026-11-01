@echo off
setlocal
cd /d "%~dp0yuoj-frontend"

echo ================================================
echo   鱼 OJ 前端 :8080
echo ================================================

if not exist node_modules (
    echo 未发现 node_modules，开始安装依赖（首次较慢）...
    call npm install --legacy-peer-deps
    if errorlevel 1 (
        echo [X] npm install 失败
        pause
        exit /b 1
    )
)

call npm run serve
exit /b 0
