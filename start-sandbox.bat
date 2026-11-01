@echo off
setlocal
cd /d "%~dp0"

set "JAVA_HOME=F:\dev\java\8"
set "MAVEN_OPTS="
rem docker-java 无参 build() 默认连 unix socket，Windows 必须显式指向 tcp
set "DOCKER_HOST=tcp://localhost:2375"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo ================================================
echo   鱼 OJ 代码沙箱 :8090
echo   JAVA_HOME   = %JAVA_HOME%
echo   DOCKER_HOST = %DOCKER_HOST%
echo ================================================

curl -s --max-time 5 http://localhost:2375/_ping >nul
if errorlevel 1 (
    echo [X] Docker daemon 未响应 tcp://localhost:2375
    echo     Docker Desktop - Settings - General - 勾选
    echo     "Expose daemon on tcp://localhost:2375 without TLS"
    pause
    exit /b 1
)

if not exist eclipse-temurin-8-jre-alpine (
    echo [提示] 首次启动会拉取 eclipse-temurin:8-jre-alpine 约 100MB
)

cd yuoj-code-sandbox
call mvn -B -DskipTests package
if errorlevel 1 (
    echo [X] 构建失败，已中止
    pause
    exit /b 1
)

start "yuoj-sandbox" java -jar target\yuoj-code-sandbox-0.0.1-SNAPSHOT.jar
echo 沙箱已发起启动，端口 8090，健康检查: http://localhost:8090/health
exit /b 0
