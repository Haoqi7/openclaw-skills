#!/bin/bash

# OpenClaw Skills Installer
# 安装自定义技能和定时任务

set -e

OPENCLAW_SKILLS_DIR="/usr/lib/node_modules/openclaw/skills"
WORKSPACE_SKILLS_DIR="$HOME/.openclaw/workspace/skills"
CRON_DIR="./cron-tasks"

echo "🚀 开始安装 OpenClaw 自定义技能..."

# 检查OpenClaw技能目录
if [ ! -d "$OPENCLAW_SKILLS_DIR" ]; then
    echo "❌ OpenClaw技能目录不存在: $OPENCLAW_SKILLS_DIR"
    exit 1
fi

# 安装技能
echo "📦 安装技能到系统目录..."

# android-flashlight
if [ -d "skills/android-flashlight" ]; then
    echo "  → 安装 android-flashlight..."
    cp -r "skills/android-flashlight" "$OPENCLAW_SKILLS_DIR/"
    echo "    ✅ android-flashlight 安装完成"
fi

# session-cleanup-v2
if [ -d "skills/session-cleanup-v2" ]; then
    echo "  → 安装 session-cleanup-v2..."
    cp -r "skills/session-cleanup-v2" "$OPENCLAW_SKILLS_DIR/"
    echo "    ✅ session-cleanup-v2 安装完成"
fi

# 创建定时任务
echo "⏰ 创建定时任务..."

if [ -d "$CRON_DIR" ]; then
    for cron_file in "$CRON_DIR"/*.json; do
        if [ -f "$cron_file" ]; then
            task_name=$(basename "$cron_file" .json)
            echo "  → 创建定时任务: $task_name"
            
            # 检查openclaw命令是否存在
            if command -v openclaw &> /dev/null; then
                openclaw cron create --json "$cron_file" && \
                echo "    ✅ $task_name 定时任务创建成功" || \
                echo "    ⚠️  $task_name 定时任务创建失败"
            else
                echo "    ⚠️  openclaw命令未找到，请手动创建定时任务"
                echo "    命令: openclaw cron create --json $cron_file"
            fi
        fi
    done
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "📋 已安装技能:"
ls -la "$OPENCLAW_SKILLS_DIR/" | grep -E "(android-flashlight|session-cleanup)" || true
echo ""
echo "⏰ 定时任务列表:"
openclaw cron list 2>/dev/null | grep -E "(session-cleanup|dashboard-monitor)" || echo "请手动运行: openclaw cron list"