@echo off
setlocal
cd /d "%~dp0"

set "JAVA_HOME=F:\dev\java\8"
set "MAVEN_OPTS="
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo ================================================
echo   鱼 OJ 微服务版 - 启动 4 个后端服务
echo   JAVA_HOME = %JAVA_HOME%
echo ================================================

netstat -ano | findstr ":8848" >nul
if errorlevel 1 (
    echo [X] Nacos 8848 未监听
    echo     先执行: F:\dev\nacos\bin\startup.cmd -m standalone
    pause
    exit /b 1
)
netstat -ano | findstr ":5672" >nul
if errorlevel 1 (
    echo [X] RabbitMQ 5672 未监听，先启动 RabbitMQ 服务
    pause
    exit /b 1
)

echo [1/2] mvn install （首次会下载依赖，耐心等）
cd yuoj-backend
call mvn -B -DskipTests install
if errorlevel 1 (
    echo [X] 构建失败，已中止
    pause
    exit /b 1
)

echo [2/2] 依次启动 user -^> question -^> judge -^> gateway
start "yuoj-user"     java -jar yuoj-backend-user-service\target\yuoj-backend-user-service-0.0.1-SNAPSHOT.jar
timeout /t 10 /nobreak >nul
start "yuoj-question" java -jar yuoj-backend-question-service\target\yuoj-backend-question-service-0.0.1-SNAPSHOT.jar
timeout /t 10 /nobreak >nul
start "yuoj-judge"    java -jar yuoj-backend-judge-service\target\yuoj-backend-judge-service-0.0.1-SNAPSHOT.jar
timeout /t 10 /nobreak >nul
start "yuoj-gateway"  java -jar yuoj-backend-gateway\target\yuoj-backend-gateway-0.0.1-SNAPSHOT.jar

echo.
echo 已发起启动。等约 60 秒后访问 http://localhost:8080
echo 停止请执行 stop-all.bat
exit /b 0
