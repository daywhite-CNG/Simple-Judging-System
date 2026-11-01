# -*- coding: utf-8 -*-
"""
清理源码注释里的非功能信息（署名 / 链接 / 创建时间），只保留功能解释。

删除：
  * @author xxx                 (Java 块注释)
  * @from   <a href=...>        (Java 块注释)
  * @createDate 2023-08-07 ...  (Java 块注释)
  # @author / # @from           (yml / sql / properties 行注释)
  <!-- @author ... -->          (xml)
保留：
  @description / @param / @return / @throws / @TableName / @Entity
  全部中文功能说明、todo 标记、[本地部署修改] 之类运维注释

用法：
  python clean-comments.py <目录>            # 干跑，只报告
  python clean-comments.py <目录> --apply    # 实际写入
"""
import os
import re
import sys

SKIP_DIRS = {"node_modules", "target", ".git", "generated", "logs", "tmpCode", "public", "__pycache__"}

JAVA_TAG = re.compile(r"^\s*\*\s*@(author|from|createDate)\b")
HASH_TAG = re.compile(r"^\s*#\s*@(author|from|createDate)\b")
XML_TAG = re.compile(r"^\s*<!--\s*@(author|from|createDate)\b.*-->\s*$")

BLANK_STAR = re.compile(r"^\s*\*\s*$")
BLOCK_END = re.compile(r"^\s*\*/\s*$")
BLOCK_START = re.compile(r"^\s*/\*\*\s*$")


def clean_java(lines):
    out = [ln for ln in lines if not JAVA_TAG.match(ln)]
    changed = True
    while changed:                      # 收敛：尾部/头部空 * 行、空注释块、连体空 * 行
        changed = False
        new, i, n = [], 0, len(out)
        while i < n:
            ln = out[i]
            if BLOCK_START.match(ln) and i + 1 < n and BLOCK_END.match(out[i + 1]):
                i += 2; changed = True; continue                       # 空注释块整体删
            if BLANK_STAR.match(ln) and i + 1 < n and BLOCK_END.match(out[i + 1]):
                i += 1; changed = True; continue                       # 尾部空 * 行
            if BLOCK_START.match(ln) and i + 1 < n and BLANK_STAR.match(out[i + 1]):
                new.append(ln); i += 2; changed = True; continue       # 头部空 * 行
            if BLANK_STAR.match(ln) and i + 1 < n and BLANK_STAR.match(out[i + 1]):
                new.append(ln); i += 2; changed = True; continue       # 连续空 * 行压成一个
            new.append(ln); i += 1
        out = new
    return out


def clean_lines(path, lines):
    low = path.lower()
    if low.endswith(".java"):
        return clean_java(lines)
    if low.endswith(".xml"):
        return [ln for ln in lines if not XML_TAG.match(ln)]
    if low.endswith((".yml", ".yaml", ".sql", ".properties")):
        return [ln for ln in lines if not HASH_TAG.match(ln)]
    return lines


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    root = os.path.abspath(sys.argv[1])
    apply = "--apply" in sys.argv

    stats = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith((".java", ".xml", ".yml", ".yaml", ".sql")):
                continue
            p = os.path.join(dirpath, fn)
            text = open(p, "rb").read().decode("utf-8")
            old = text.splitlines(keepends=True)
            new = clean_lines(p, old)
            if new != old:
                stats.append((os.path.relpath(p, root), len(old) - len(new)))
                if apply:
                    open(p, "wb").write("".join(new).encode("utf-8"))

    stats.sort(key=lambda x: (-x[1], x[0]))
    print(("已写入" if apply else "干跑") + f"：{len(stats)} 个文件，共删 {sum(s[1] for s in stats)} 行")
    for rel, rm in stats[:12]:
        print(f"  -{rm:3d}  {rel}")
    if len(stats) > 12:
        print(f"  ... 其余 {len(stats) - 12} 个文件")


if __name__ == "__main__":
    main()
