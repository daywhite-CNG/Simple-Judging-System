-- 清理已核实无任何代码引用的库表字段（与代码同步变更：实体/VO/查询条件已同步删除）
-- 备份：backup-yuoj-before-column-cleanup-20261101.sql（mysqldump 全库，含本文件涉及的表）
-- 审计依据：HANDOFF 字段审计 2026-11-01
use yuoj;

-- user：微信登录残留列（全库无写入点；idx_unionId 随列自动删除）
alter table user drop column unionId;
alter table user drop column mpOpenId;

-- question：点赞/收藏无对应接口与前端展示，仅建表默认值
alter table question drop column thumbNum;
alter table question drop column favourNum;

-- 帖子三表：原 yoj 社区功能残留，微服务版无 post-service
drop table post;
drop table post_thumb;
drop table post_favour;
