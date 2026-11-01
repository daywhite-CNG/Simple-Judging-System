-- ============================================================
-- 鱼 OJ 本地部署：把已注册账号提权为管理员
-- 用法：
--   1. 先在 http://localhost:8080/user/register 注册一个账号
--   2. 把下面 'YOUR_ACCOUNT' 换成你注册的账号，然后执行：
--        mysql -uroot -p < promote-admin.sql
-- ============================================================

use yuoj;

-- 看看现有账号
select id, userAccount, userName, userRole from user;

-- 提权（注意替换账号名）
update user set userRole = 'admin' where userAccount = 'YOUR_ACCOUNT';

-- 确认结果，userRole 应为 admin
select id, userAccount, userRole from user where userAccount = 'YOUR_ACCOUNT';
