# 鱼 OJ（微服务版）本地部署说明

> 本目录当前内容：`yuoj-backend` = **微服务版**（原压缩包 `鱼 OJ 在线判题系统（微服务版本）.zip` 解压而来，外层 `yuoj-backend-microservice-master/` 已剥离），
> `yuoj-frontend`、`yuoj-code-sandbox` 沿用之前的单体版配套代码。
>
> ⚠️ 2026-11-01 更新：根目录的 8 个 `.bat` / `test-sandbox.*` 启动脚本**已删除**，改由本文 §4 的手动命令接替。
> 原压缩包已不在本机，**本仓库是唯一副本**。

---

## 1. 架构与端口

```
             浏览器 http://localhost:8080
                        │
                        ▼
        ┌───────────────────────────────┐
        │  Gateway :8101  (/api/**)     │  Spring Cloud Gateway + Nacos + 跨域 + 全局鉴权过滤器
        └───────┬───────────┬───────────┘
                ▼           ▼           ▼
        user :8102   question :8103   judge :8104
        (/api/user)  (/api/question)  (/api/judge)
             │            │                │
             │            │  ── RabbitMQ ──▶│  判题任务异步派发
             │            │   code_exchange / code_queue
             ▼            ▼                ▼
        ┌─────────────────────────────────────────┐
        │ MySQL 3306 / Redis 6379 / Nacos 8848    │
        └─────────────────────────────────────────┘
                             │
                             ▼ judge 通过 HTTP 调用
                   代码沙箱 :8090（Docker 容器执行用户代码）
```

| 组件 | 端口 | 说明 |
|---|---|---|
| Gateway | 8101 | 前端唯一入口，前端 `generated/core/OpenAPI.ts` 写死此地址 |
| user-service | 8102 | `/api/user` |
| question-service | 8103 | `/api/question`，MQ 生产者 |
| judge-service | 8104 | `/api/judge`，MQ 消费者 |
| 代码沙箱 | 8090 | 需要 `DOCKER_HOST=tcp://localhost:2375` |
| 前端 | 8080 | Vue3 + Arco Design |
| MySQL | 3306 | **使用本机已装版本** |
| Redis | 6379 | **使用本机已装版本** |
| RabbitMQ | 5672 / 15672 | 容器启动 |
| Nacos | 8848 | 容器启动 |

---

## 2. 目录结构

```
<项目根目录>\                        clone 到任意盘符均可，下文用 $repo 指代
├── yuoj-backend\                     微服务版后端（Maven 聚合工程，7 个模块）
│   ├── pom.xml
│   ├── yuoj-backend-common\          通用工具、异常、统一响应
│   ├── yuoj-backend-model\           实体 / DTO / VO / 枚举
│   ├── yuoj-backend-gateway\         8101 网关
│   ├── yuoj-backend-service-client\  OpenFeign 客户端
│   ├── yuoj-backend-question-service\ 8103
│   ├── yuoj-backend-user-service\     8102
│   ├── yuoj-backend-judge-service\    8104
│   ├── docker-compose.env.yml        中间件编排（mysql/redis/rabbitmq/nacos）
│   ├── docker-compose.service.yml    服务编排
│   └── mysql-init\                   create_table.sql（建库 + 3 张表）
│                                     migrate-drop-unused-20261101.sql（已执行，幂等留存）
├── yuoj-frontend\                    8080
├── yuoj-code-sandbox\                8090
```

> 根目录启动脚本（`*.bat`）、`promote-admin.sql`、`clean-comments.py` 已于 2026-11-01 删除：
> 提权语句已内联到 §4-⑤，启动改用 §4 手动命令。

---

## 3. 前置状态（本机实测 2026-11-01）

| 项 | 状态 |
|---|---|
| JDK 8 | ✅ 已装。系统 `JAVA_HOME` 指向更高版本，**构建前必须覆盖**（见 §4-⓪）—— 本项目 Spring Boot 2.6.13 + `java.version 1.8` |
| Maven | ✅ `mvn` 已在 PATH |
| MySQL @3306 | ✅ 已运行，`root / 123456`。`mysql.exe` 可能不在 PATH，统一在 §4-⓪ 指定 |
| Redis @6379 | ✅ 已运行，**无密码** |
| Node / npm | ✅ |
| 数据库 `yuoj` | ✅ 已建，**3 张表**（`user` / `question` / `question_submit`），`user` 表 1 个账号 `test001`（角色 `user`，非 admin） |
| 后端 7 个模块 jar | ✅ 已构建于 2026-11-01 15:45，字节码 major 52（Java 8） |
| 沙箱 jar | ✅ 已构建于 2026-11-01 13:16 |
| Docker Desktop | ✅ 已运行（RabbitMQ 5672 / Nacos 8848 均在 LISTENING） |

### 3-1 Docker Desktop 前置检查

1. 启动 Docker Desktop，等左下角变绿
2. Settings → General → 勾选 **Expose daemon on tcp://localhost:2375 without TLS**（代码沙箱走 TCP 连接，不用 `docker.sock`）
3. 验证：`curl http://localhost:2375/_ping` → 返回 `OK`
4. 预拉镜像，避免首次判题卡住：
   ```bash
   docker pull eclipse-temurin:8-jre-alpine
   docker pull rabbitmq:3.12.6-management
   docker pull nacos/nacos-server:v2.2.0-slim
   ```

> **不要用 `docker compose up -d` 起全部中间件**：`docker-compose.env.yml` 里也声明了 mysql 和 redis，
> 会和你本机已在运行的 MySQL(3306)、Redis(6379) 抢端口。只起需要的两个：
> ```bash
> docker compose -f yuoj-backend\docker-compose.env.yml up -d rabbitmq nacos
> ```

---

## 4. 部署步骤（手动命令）

> 原先由 `.bat` 承担的环境变量与启动顺序，现在必须手动做对。**⓪ 的 JAVA_HOME 覆盖最易踩**：
> 系统默认 JDK 若高于 1.8，不覆盖会直接编译失败。

### ⓪ 每个新终端先设环境（PowerShell）

```powershell
# 先按自己的安装位置改这三行，后续所有命令都复用它们（本文档不写死任何本机路径）
$repo  = 'X:\path\to\yuoj'                  # 项目根目录
$jdk8  = 'X:\path\to\jdk\8'                 # JDK 8 安装目录
$mysql = 'X:\path\to\mysql\bin\mysql.exe'   # mysql.exe 完整路径

cd $repo
$env:JAVA_HOME  = $jdk8
$env:PATH       = "$env:JAVA_HOME\bin;$env:PATH"
$env:MAVEN_OPTS = ''          # 清掉高版本 JDK 专用参数，否则 JDK 8 报 Unrecognized option
java -version                 # 确认输出 1.8.x 再继续
```

### ① 建库导表（只需一次）

```powershell
# mysql.exe 若不在 PATH，用 §4-⓪ 定义的 $mysql
& $mysql -uroot -p123456 -e "source $repo\yuoj-backend\mysql-init\create_table.sql"

# 验证：应看到 3 张表
& $mysql -uroot -p123456 -e "use yuoj; show tables;"
```

建库 `yuoj` + **3 张表**：`user` / `question` / `question_submit`。
SQL 里全是 `create ... if not exists`，**重复执行不会清空已有数据**。

> 旧版文档写的“6 张表含 post/post_thumb/post_favour”已过时：帖子三表属于原单服版社区功能，
> 微服务版无 post-service，已于 2026-11-01 通过 `migrate-drop-unused-20261101.sql` 删除。

### ② 起中间件（RabbitMQ + Nacos）

```powershell
docker compose -f "$repo\yuoj-backend\docker-compose.env.yml" up -d rabbitmq nacos
```

验证：
- Nacos：<http://localhost:8848/nacos>（默认 `nacos / nacos`）
- RabbitMQ：<http://localhost:15672>（默认 `guest / guest`）

### ③ 编译 + 起后端 4 个服务

```powershell
# 先确认 Nacos 已起（否则服务注册失败）
netstat -ano | findstr ":8848"

# 编译（必须在线构建，离线会报 Non-resolvable parent POM，见 §7-1）
cd "$repo\yuoj-backend"
mvn -B -DskipTests install
```

然后**开 4 个独立终端**，每个先跑 §4-⓪ 的环境设置，再分别执行（顺序 user → question → judge → gateway，间隔约 10 秒）：

```powershell
java -jar "$repo\yuoj-backend\yuoj-backend-user-service\target\yuoj-backend-user-service-0.0.1-SNAPSHOT.jar"
java -jar "$repo\yuoj-backend\yuoj-backend-question-service\target\yuoj-backend-question-service-0.0.1-SNAPSHOT.jar"
java -jar "$repo\yuoj-backend\yuoj-backend-judge-service\target\yuoj-backend-judge-service-0.0.1-SNAPSHOT.jar"
java -jar "$repo\yuoj-backend\yuoj-backend-gateway\target\yuoj-backend-gateway-0.0.1-SNAPSHOT.jar"
```

或用一条 PowerShell 开 4 个错开启动的窗口（用 `Start-Process` 避开 cmd/PowerShell 双层引号转义）：

```powershell
foreach ($d in 'yuoj-backend-user-service','yuoj-backend-question-service','yuoj-backend-judge-service','yuoj-backend-gateway') {
  $jar = Join-Path $repo "yuoj-backend\$d\target\$d-0.0.1-SNAPSHOT.jar"
  # 子进程继承当前会话环境变量（§4-⓪ 已设好），用 Start-Process java 规避双层引号转义
  Start-Process java -ArgumentList '-jar', $jar
  Start-Sleep -Seconds 10
}
```

验证（等约 60 秒）：
- 网关文档：<http://localhost:8101/doc.html>（Knife4j 聚合了 3 个子服务的 Swagger）
- Nacos 控制台 → 服务列表 → 应看到 `yuoj-backend-user-service`、`yuoj-backend-question-service`、`yuoj-backend-judge-service`、`yuoj-backend-gateway`

> 注意：**后端入口是 8101，不是 8080**。8080 是前端 devServer。旧 `start-backend.bat` 末尾提示“访问 8080”是错的。

### ④ 起代码沙箱

```powershell
# 沙箱走 TCP 连 Docker，不读 docker.sock
$env:DOCKER_HOST = 'tcp://localhost:2375'
curl.exe -s --max-time 5 http://localhost:2375/_ping      # → OK

cd "$repo\yuoj-code-sandbox"
mvn -B -DskipTests package
java -jar target\yuoj-code-sandbox-0.0.1-SNAPSHOT.jar
```

验证：`curl http://localhost:8090/health` → `ok`

### ⑤ 起前端

```powershell
cd "$repo\yuoj-frontend"
if (-not (Test-Path node_modules)) { npm install --legacy-peer-deps }   # 首次约几分钟
npm run serve
```

打开 <http://localhost:8080> → 登录或注册 → 若需管理员，把账号填进下面命令的 `<你的账号>`：

```powershell
# 先看现有账号
& $mysql -uroot -p123456 -e "use yuoj; select id, userAccount, userName, userRole from user;"

# 提权（确认账号无误再执行）
& $mysql -uroot -p123456 -e "use yuoj; update user set userRole = 'admin' where userAccount = '<你的账号>';"

# 复核：userRole 应为 admin
& $mysql -uroot -p123456 -e "use yuoj; select userAccount, userRole from user where userAccount = '<你的账号>';"
```

> 原 `promote-admin.sql` 已删除，其内容即上面三条语句。

### 停止

按端口精确杀（不要误杀 Nacos 8848 / RabbitMQ 5672 / MySQL 3306 / Redis 6379）：

```powershell
foreach ($port in 8080,8090,8101,8102,8103,8104) {
  $pids = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
          Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($procId in $pids) {
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    "已终止 端口 $port -> PID $procId"
  }
}
docker compose -f "$repo\yuoj-backend\docker-compose.env.yml" stop rabbitmq nacos
```

> 旧 `stop-all.bat` 只按端口 `taskkill`，**并没有**停容器和 node 进程（README 旧描述有误，已修正）。

---

## 5. 判题用例格式

管理端新建题目时，`judgeCase` 与 `judgeConfig` 都要填 **JSON 字符串**：

```json
judgeCase:   [{"input":"1 2","output":"3"},{"input":"2 3","output":"5"}]
judgeConfig: {"timeLimit":1000,"memoryLimit":100,"stackLimit":100}
```

提交 Java 代码后：提交记录 → `question_submit.status` 走 `0 待判题 → 1 判题中 → 2 成功`，
判题结论在 `judgeInfo.message`（Accepted / Wrong Answer / Time Limit Exceeded …）。

沙箱冒烟测试（需先完成 §4-④；`auth: secretKey` 是硬编码密钥，见 `MainController.java`）：

```powershell
curl.exe -s -H "auth: secretKey" -H "Content-Type: application/json" -X POST http://localhost:8090/executeCode -d '{"code":"public class Main { public static void main(String[] a){ System.out.println(Integer.parseInt(a[0])+Integer.parseInt(a[1])); } }","language":"java","inputList":["1 2","2 3"]}'
# 期望返回含 "outputList":["3","5"] 的 JSON
```

> 原 `test-sandbox.bat` + `test-sandbox.json` 已删（2026-11-01）。

---

## 6. 排错对照表（都是本机真实踩过的）

| # | 现象 | 原因与处理 |
|---|---|---|
| 7-1 | `mvn -o` 报 `Non-resolvable parent POM ... spring-cloud-dependencies-parent:pom:3.1.5 (present, but unavailable)` | 该 POM 在本地 `~/.m2` 里存在，但记录的来源仓库 ID 与当前构建上下文不符，离线模式判定不可用。**用在线构建**（`mvn -B -DskipTests install`），依赖已缓存后 26 秒完成 |
| 7-2 | 已删脚本后仅在从 git 恢复 `.bat` 时适用：`.bat` 里中文行被劈成两条命令，报 `'xx键关闭' is not recognized` | **cmd 的 UTF-8 批处理失步 bug**：`chcp 65001` + UTF-8 存盘的 `.bat` 中，中文行会让**下一行**被截断。原脚本用 **GBK 编码 + 不设 chcp**（见 §6-6）；本文档的 PowerShell 命令不受此限制 |
| 7-3 | 启动报 `Unrecognized option: --enable-native-access=ALL-UNNAMED` | 系统 `MAVEN_OPTS` 可能带高版本 JDK 专用参数，JDK 8 不认。手动构建前先 `$env:MAVEN_OPTS = ''`（见 §4-⓪）；原脚本内置 `set "MAVEN_OPTS="`，脚本已删需自己设 |
| 7-4 | 报 `Unable to connect to Redis` | Redis 没起，或 `application.yml` 里取消注释了 `redis.password`（本机 Redis 无密码，必须保持注释） |
| 7-5 | 报 `Communications link failure` | MySQL 没起 / 密码不是 `123456` / 库 `yuoj` 没建 |
| 7-6 | 服务起不来，日志刷 Nacos 连接失败 | Nacos 没起（`docker ps` 看 `yuoj-nacos`），或 8848 被占 |
| 7-7 | 提交后一直「判题中」 | judge-service 没起 / RabbitMQ 没起 / 沙箱 8090 不通 —— 三个环节任一断都表现为同一个现象 |
| 7-8 | 沙箱日志 `Connection refused` 或 `docker.sock` 相关 | Docker Desktop 没开，或没勾 §3-1 的 Expose daemon，`DOCKER_HOST` 必须指向 `tcp://localhost:2375` |
| 7-9 | 判题报 `UnsupportedClassVersionError` | 沙箱「宿主机编译 + 容器运行」，容器 JRE 版本必须 ≥ 宿主机 javac 版本；已改为用沙箱自身 `java.home` 下的 javac |
| 7-10 | 容器创建失败 / 判题 100% 失败 | 原版 `withSecurityOpts("security=安全管理配置字符串")` 是非法占位串，Docker 会 400 拒建；此目录已移除那行 |
| 7-11 | 前端所有请求 404 | 后端没起在 8101，或 Gateway 没注册成功（看 Nacos 服务列表） |
| 7-12 | `docker compose up` 报端口占用 | 本机 MySQL/Redis 占着 3306/6379，只起 `rabbitmq nacos` 两个服务 |
| 7-13 | `npm run serve` 卡很久 | monaco-editor 打包慢，正常；`yarn.lock` 已改名 `.disabled`，请用 npm |

---

## 7. 已知限制

| 限制 | 说明 |
|---|---|
| **只支持 Java 判题** | 沙箱只有 Java 模板（代码固定存 `Main.java`，容器内 `java -cp /app Main`）；`JudgeManager` 也只注册了 Java 策略，前端语言下拉里的 cpp/go 不可用 |
| **无死信队列** | `code_queue` 是普通 durable 队列，没有 `x-dead-letter-exchange`；消费失败走 `basicNack(requeue=false)` 等于**消息直接丢弃**，记录会停在「判题中」 |
| **内存限制未生效** | 沙箱采集了内存峰值但 `judgeInfo.setMemory()` 被注释掉，MLE 判定永不触发 |
| **Sentinel 未启用** | 只在 `pom.xml` 里有依赖，无 `@SentinelResource`、无 dashboard 配置，等于没开 |
| **Redis 只用于 Session** | 全库无 `RedisTemplate` 编程式调用，没有缓存、没有限流 |
| **通过率统计缺失** | `question.submitNum` / `acceptedNum` 无任何自增逻辑 |
| **ES / COS / 微信未配置** | 微服务版未含这些模块；COS、微信相关占位配置不影响判题 |
| **无种子数据** | 建表脚本不插数据，题目需自己建 |
| **seccomp 已移除** | 为能建容器删掉了那行非法配置，容器仍有 `withNetworkDisabled` + `withReadonlyRootfs` + 100MB 内存 + 1 核 CPU，但**没有 syscall 白名单**，本地学习够用，别对外暴露 |

---

## 8. 回滚

- 数据库 `yuoj` 可 `drop database yuoj;` 后重跑 §4-① 的建库命令
- 中间件容器：`docker compose -f "$repo\yuoj-backend\docker-compose.env.yml" down`（数据在 `yuoj-backend\.mysql-data` 等目录，如需彻底清理一并删除）
- **已删除的启动脚本与工具文件**（10 个，可从 git 恢复）：
  `git checkout c63be05 -- '*.bat' test-sandbox.json promote-admin.sql clean-comments.py`
  > 必须指向 `c63be05`（删除前的提交）；`HEAD` 里已无这些文件，用 `HEAD` 会失败。
