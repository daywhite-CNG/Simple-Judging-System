@echo off
setlocal
cd /d "%~dp0"

echo 冒烟测试：POST http://localhost:8090/executeCode
echo 期望返回 outputList 为 ["3","5"]
echo.
curl -s -H "auth: secretKey" -H "Content-Type: application/json" -X POST http://localhost:8090/executeCode -d @test-sandbox.json
echo.
pause
exit /b 0
