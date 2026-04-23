#!/bin/bash
# ============================================================
# OpenClaw Diary Skill - 入口脚本
# 用法: bash skill.sh daily [--memory-summary "..."]
#       bash skill.sh weekly
#       bash skill.sh monthly
# ============================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

# 检查 Python3
if ! command -v python3 &>/dev/null; then
    echo "[错误] 未找到 python3，请先安装 Python 3.8+"
    exit 1
fi

# 检查依赖
python3 -c "import requests" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[错误] 缺少依赖 requests，执行: pip3 install requests"
    exit 1
fi

python3 -c "import feedparser" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[错误] 缺少依赖 feedparser，执行: pip3 install feedparser"
    exit 1
fi

# 检查配置文件
if [ ! -f "config.json" ]; then
    echo "[错误] 配置文件 config.json 不存在，请先配置"
    exit 1
fi

# 执行
python3 "$SKILL_DIR/diary.py" "$@"