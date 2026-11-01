-- ============================================================
-- 【已于 2026-11-01 执行完毕，仅作变更历史留存，无需再跑】
--
-- 清理已核实无任何代码引用的库表字段（与代码同步变更：实体/VO/查询条件已同步删除）
-- 审计依据：HANDOFF 字段审计 2026-11-01
--
-- 现状核对（2026-11-01 实测本机 yuoj 库）：
--   user    已无 unionId / mpOpenId
--   question 已无 thumbNum / favourNum
--   post / post_thumb / post_favour  三表已不存在
--   库内仅剩 3 张表：user / question / question_submit
--
-- 本文件已改写为幂等：重复执行不再报错，未迁移的旧库执行可完成迁移，
-- 已迁移的库执行则逐条跳过。
--
-- 注：原注释指向的备份文件 backup-yuoj-before-column-cleanup-20261101.sql
--     已于 2026-11-01 清理删除。
-- ============================================================

use yuoj;

-- ---------- user：微信登录残留列（全库无写入点；idx_unionId 随列自动删除） ----------
-- MySQL 8.0 的 ALTER TABLE DROP COLUMN 不支持 IF EXISTS，用存储过程判列存在再删。
drop procedure if exists yuoj_drop_col_if_exists;
delimiter $$
create procedure yuoj_drop_col_if_exists(in p_table varchar(64), in p_column varchar(64))
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'yuoj' and table_name = p_table and column_name = p_column) then
    set @ddl = concat('alter table `', p_table, '` drop column `', p_column, '`');
    prepare stmt from @ddl; execute stmt; deallocate prepare stmt;
    select concat('dropped: ', p_table, '.', p_column) as result;
  else
    select concat('skip (not exists): ', p_table, '.', p_column) as result;
  end if;
end $$
delimiter ;

call yuoj_drop_col_if_exists('user', 'unionId');
call yuoj_drop_col_if_exists('user', 'mpOpenId');
call yuoj_drop_col_if_exists('question', 'thumbNum');
call yuoj_drop_col_if_exists('question', 'favourNum');

-- ---------- 帖子三表：原 yoj 社区功能残留，微服务版无 post-service ----------
drop table if exists post;
drop table if exists post_thumb;
drop table if exists post_favour;

drop procedure if exists yuoj_drop_col_if_exists;

-- ---------- 迁移后自检：应只剩 3 张表 ----------
select table_name
from information_schema.tables
where table_schema = 'yuoj'
order by table_name;
