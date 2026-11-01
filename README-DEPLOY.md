# 鱼 OJ（微服务版）本地部署说明

> 本目录当前内容：`yuoj-backend` = **微服务版**（原压缩包 `鱼 OJ 在线判题系统（微服务版本）.zip` 解压而来，外层 `yuoj-backend-microservice-master/` 已剥离），
> `yuoj-frontend`、`yuoj-code-sandbox` 沿用之前的单体版配套代码。
> 原始压缩包仍完整保留在 `D:\BaiduNetdiskDownload\OJ在线判题系统源码\`，未做任何改动。

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
D:\WorkSpace\JavaProject\yuoj\
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
│   └── mysql-init\create_table.sql   建库 + 6 张表
├── yuoj-frontend\                    8080
├── yuoj-code-sandbox\                8090
├── init-db.bat                       建库导表
├── start-all.bat                     一键启动（中间件 → 沙箱 → 后端 → 前端）
├── start-backend.bat                 只启动 4 个后端服务
├── start-sandbox.bat                 只启动代码沙箱
├── start-frontend.bat                只启动前端
├── stop-all.bat                      停止 java / node / yuoj-* 容器
├── test-sandbox.bat                  沙箱冒烟测试
└── promote-admin.sql                 把注册账号提权为管理员
```

---

## 3. 前置状态（本机实测）

| 项 | 状态 |
|---|---|
| JDK 8 | ✅ `C:\Program Files\Java\jdk-8`（jdk8u504），脚本内临时指定，**不影响系统 JAVA_HOME** |
| Maven 3.9.16 | ✅ `D:\Dev\Maven`，`mvn` 已在 PATH |
| MySQL 8.0.46 @3306 | ✅ 已运行，`root / 123456`（已实测连通） |
| Redis @6379 | ✅ 已运行，**无密码** |
| Node / npm | ✅ |
| 数据库 `yuoj` | ✅ 已建，6 张表，`user` 表已有 1 个账号 |
| 后端 8 个模块编译 | ✅ `mvn -B -DskipTests install` BUILD SUCCESS（26 秒） |
| **Docker Desktop** | ❌ **未启动** —— RabbitMQ、Nacos、代码沙箱都依赖它，必须你手动开 |

### 3-1 Docker Desktop（必须你手动做）

1. 启动 Docker Desktop，等左下角变绿
2. Settings → General → 勾选 **Expose daemon on tcp://localhost:2375 without TLS**（代码沙箱走 TCP 连接，不用 `docker.sock`）
3. 预拉镜像，避免首次判题卡住：
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

## 4. 部署步骤

### ① 建库导表（只需一次，已验证）

```powershell
# 非交互（推荐，便于自动化）
D:\WorkSpace\JavaProject\yuoj\init-db.bat root 123456

# 或直接双击，按提示输入用户名密码
```

脚本会把 `yuoj-backend\mysql-init\create_table.sql` 导入，建库 `yuoj` + 6 张表：
`user` / `question` / `question_submit` / `post` / `post_thumb` / `post_favour`。
SQL 里全是 `create ... if not exists`，**重复执行不会清空已有数据**。

### ② 起中间件（RabbitMQ + Nacos）

```powershell
docker compose -f D:\WorkSpace\JavaProject\yuoj\yuoj-backend\docker-compose.env.yml up -d rabbitmq nacos
```

验证：
- Nacos：<http://localhost:8848/nacos>（默认 `nacos / nacos`）
- RabbitMQ：<http://localhost:15672>（默认 `guest / guest`）

### ③ 起后端 4 个服务

```powershell
D:\WorkSpace\JavaProject\yuoj\start-backend.bat
```

脚本会：校验 JDK 8 → 探测 Nacos 8848 → `mvn install` 装好公共模块 → 依次在**独立窗口**启动
user(8102) → question(8103) → judge(8104) → gateway(8101)，每个间隔 10 秒。

验证：
- 网关文档：<http://localhost:8101/doc.html>（Knife4j 聚合了 3 个子服务的 Swagger）
- Nacos 控制台 → 服务列表 → 应看到 `yuoj-backend-user-service`、`yuoj-backend-question-service`、`yuoj-backend-judge-service`、`yuoj-backend-gateway`

### ④ 起代码沙箱

```powershell
D:\WorkSpace\JavaProject\yuoj\start-sandbox.bat
curl http://localhost:8090/health      # → ok
```

### ⑤ 起前端

```powershell
D:\WorkSpace\JavaProject\yuoj\start-frontend.bat
```

打开 <http://localhost:8080> → 登录（`user` 表已有账号）或注册 → 若需管理员，改 `promote-admin.sql` 里的账号后执行：

```powershell
mysql -uroot -p123456 < D:\WorkSpace\JavaProject\yuoj\promote-admin.sql
```

### 一键启动 / 停止

```powershell
start-all.bat     # 中间件 → 沙箱 → 4 个后端 → 前端
stop-all.bat      # 停 java（后端+沙箱）、node（前端）、yuoj-* 容器
```

> `start-all.bat` 里 Docker 未运行时只警告并询问是否继续，不会静默失败。

---

## 5. 判题用例格式

管理端新建题目时，`judgeCase` 与 `judgeConfig` 都要填 **JSON 字符串**：

```json
judgeCase:   [{"input":"1 2","output":"3"},{"input":"2 3","output":"5"}]
judgeConfig: {"timeLimit":1000,"memoryLimit":100,"stackLimit":100}
```

提交 Java 代码后：提交记录 → `question_submit.status` 走 `0 待判题 → 1 判题中 → 2 成功`，
判题结论在 `judgeInfo.message`（Accepted / Wrong Answer / Time Limit Exceeded …）。

沙箱冒烟测试：

```powershell
D:\WorkSpace\JavaProject\yuoj\test-sandbox.bat
# 期望返回含 "outputList":["3"] 的 JSON
```

---

## 6. 相对官方压缩包已做的改动

| # | 位置 | 改动 | 原因 |
|---|---|---|---|
| 1 | 解压结构 | 剥掉 `yuoj-backend-microservice-master/` 外层 | 与 `yuoj-frontend` / `yuoj-code-sandbox` 平级，路径统一 |
| 2 | `init-db.bat` | 路径改为 `yuoj-backend\mysql-init\create_table.sql`，支持 `参数直传` 非交互模式 | 微服务版 SQL 在 `mysql-init/` 下；便于自动化验证 |
| 3 | `start-backend.bat` | 从「单服务 mvnw spring-boot:run」改为「install + 4 服务独立窗口」 | 微服务版无 `mvnw`，且必须起 4 个进程 |
| 4 | `start-all.bat` | 新增 | 一条命令串起全链路 |
| 5 | `stop-all.bat` | 端口检查扩展到 8080/8090/8101~8104，新增 `yuoj-*` 容器清理 | 单服务时代只查 3 个端口 |
| 6 | 全部 `.bat` | 编码改为 **GBK**，去掉 `chcp 65001` | 见 §7-2 |

其余源码未改：`application.yml` 里 MySQL 就是 `root/123456`（与本机一致），Redis 无密码所以 `password` 保持注释，Nacos/RabbitMQ 用 compose 默认值。

---

## 7. 排错对照表（都是本机真实踩过的）

| # | 现象 | 原因与处理 |
|---|---|---|
| 7-1 | `mvn -o` 报 `Non-resolvable parent POM ... spring-cloud-dependencies-parent:pom:3.1.5 (present, but unavailable)` | 该 POM 在本地 `~/.m2` 里存在，但记录的来源仓库 ID 与当前构建上下文不符，离线模式判定不可用。**用在线构建**（`mvn -B -DskipTests install`），依赖已缓存后 26 秒完成 |
| 7-2 | `.bat` 里某行中文被劈成两条命令，报 `'xx键关闭' is not recognized` 或 `'Profile' is not recognized` | **cmd 的 UTF-8 批处理失步 bug**：`chcp 65001` + UTF-8 存盘的 `.bat` 中，中文行会让**下一行**被截断。本目录 4 个脚本已改为 **GBK 编码 + 不设 chcp**（改动原因见 §6-6）。今后改这些脚本务必用 GBK/ANSI 保存 |
| 7-3 | 启动报 `Unrecognized option: --enable-native-access=ALL-UNNAMED` | 系统 `MAVEN_OPTS` 是 JDK 25 专用参数，JDK 8 不认。所有启动脚本已内置 `set "MAVEN_OPTS="` |
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

## 8. 已知限制

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

## 9. 回滚

- 数据库 `yuoj` 可 `drop database yuoj;` 后重跑 `init-db.bat`
- 中间件容器：`docker compose -f yuoj-backend\docker-compose.env.yml down`（数据在 `yuoj-backend\.mysql-data` 等目录，如需彻底清理一并删除）
