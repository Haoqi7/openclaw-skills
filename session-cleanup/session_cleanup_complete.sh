#!/bin/bash
# 完整版会话清理脚本
# 清理超过6小时的所有会话文件，并同步OpenClaw元数据

set -e

echo "=== 完整版会话清理脚本开始执行 ==="
echo "执行时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 计算6小时前的时间戳（毫秒）
CURRENT_MS=$(date +%s%3N)
SIX_HOURS_AGO_MS=$((CURRENT_MS - 6 * 60 * 60 * 1000))
echo "当前时间戳: $CURRENT_MS"
echo "6小时前时间戳: $SIX_HOURS_AGO_MS"
echo ""

# 清理计数器
TOTAL_CLEANED=0
TOTAL_SPACE=0

# 遍历所有agent的会话目录
for AGENT_DIR in /root/.openclaw/agents/*; do
    if [ -d "$AGENT_DIR" ]; then
        AGENT_ID=$(basename "$AGENT_DIR")
        SESSIONS_DIR="$AGENT_DIR/sessions"
        
        if [ -d "$SESSIONS_DIR" ]; then
            echo "检查agent: $AGENT_ID"
            echo "会话目录: $SESSIONS_DIR"
            
            # 检查sessions.json文件
            SESSIONS_JSON="$SESSIONS_DIR/sessions.json"
            if [ -f "$SESSIONS_JSON" ] && [ -s "$SESSIONS_JSON" ]; then
                echo "  - 检查sessions.json文件"
                
                # 备份原文件
                BACKUP_FILE="$SESSIONS_JSON.backup.$(date +%s)"
                cp "$SESSIONS_JSON" "$BACKUP_FILE"
                echo "  - 备份文件: $BACKUP_FILE"
                
                # 注意：sessions.json格式复杂，不直接使用jq处理
                # 由OpenClaw内置命令处理元数据同步
            elif [ -f "$SESSIONS_JSON" ]; then
                echo "  - sessions.json文件为空"
            else
                echo "  - 无sessions.json文件"
            fi
            
            # 清理所有.jsonl相关文件（包括.reset.*和.deleted.*）
            echo "  - 检查所有.jsonl相关文件"
            
            # 查找所有.jsonl文件（包括子后缀）
            while IFS= read -r JSONL_FILE; do
                FILE_NAME=$(basename "$JSONL_FILE")
                
                # 获取文件修改时间（秒）
                if stat -c %Y "$JSONL_FILE" >/dev/null 2>&1; then
                    # Linux系统
                    FILE_MTIME=$(stat -c %Y "$JSONL_FILE")
                else
                    # macOS系统
                    FILE_MTIME=$(stat -f %m "$JSONL_FILE")
                fi
                FILE_MTIME_MS=$((FILE_MTIME * 1000))
                
                # 检查文件是否超过6小时
                if [ "$FILE_MTIME_MS" -lt "$SIX_HOURS_AGO_MS" ]; then
                    # 获取文件大小
                    if stat -c %s "$JSONL_FILE" >/dev/null 2>&1; then
                        FILE_SIZE=$(stat -c %s "$JSONL_FILE")
                    else
                        FILE_SIZE=$(stat -f %z "$JSONL_FILE")
                    fi
                    
                    # 检查文件是否正在使用（通过.lock文件）
                    LOCK_FILE="${JSONL_FILE}.lock"
                    if [ -f "$LOCK_FILE" ]; then
                        echo "    - 跳过正在使用的文件: $FILE_NAME (有.lock文件)"
                    else
                        echo "    - 删除超时文件: $FILE_NAME (修改时间: $FILE_MTIME_MS, 大小: $FILE_SIZE 字节)"
                        rm -f "$JSONL_FILE"
                        TOTAL_CLEANED=$((TOTAL_CLEANED + 1))
                        TOTAL_SPACE=$((TOTAL_SPACE + FILE_SIZE))
                    fi
                fi
            done < <(find "$SESSIONS_DIR" -maxdepth 1 -name "*.jsonl*" -type f)
            
            # 清理.deleted残留文件（单独处理，确保不会漏掉）
            echo "  - 检查残留文件"
            for DELETED_FILE in "$SESSIONS_DIR"/*.deleted; do
                if [ -f "$DELETED_FILE" ]; then
                    FILE_NAME=$(basename "$DELETED_FILE")
                    if stat -c %s "$DELETED_FILE" >/dev/null 2>&1; then
                        FILE_SIZE=$(stat -c %s "$DELETED_FILE")
                    else
                        FILE_SIZE=$(stat -f %z "$DELETED_FILE")
                    fi
                    echo "    - 删除残留文件: $FILE_NAME (大小: $FILE_SIZE 字节)"
                    rm -f "$DELETED_FILE"
                    TOTAL_CLEANED=$((TOTAL_CLEANED + 1))
                    TOTAL_SPACE=$((TOTAL_SPACE + FILE_SIZE))
                fi
            done
            
            echo ""
        fi
    fi
done

echo "=== 文件清理完成 ==="
echo "总清理文件数: $TOTAL_CLEANED"
echo "释放空间: $((TOTAL_SPACE / 1024)) KB"
echo ""

# 执行OpenClaw内置清理命令，同步元数据
echo "=== 执行OpenClaw内置清理命令（同步元数据）==="
echo "命令: openclaw sessions cleanup --fix-missing --enforce --all-agents"
echo ""

# 运行清理命令，设置超时避免卡住
timeout 30 openclaw sessions cleanup --fix-missing --enforce --all-agents 2>&1
CLEANUP_EXIT_CODE=$?

if [ $CLEANUP_EXIT_CODE -eq 124 ]; then
    echo "  - 警告: OpenClaw清理命令超时（30秒），但文件清理已完成"
elif [ $CLEANUP_EXIT_CODE -ne 0 ]; then
    echo "  - 警告: OpenClaw清理命令失败，退出码: $CLEANUP_EXIT_CODE"
else
    echo "  - OpenClaw清理命令执行成功"
fi

echo ""
echo "=== 验证清理结果 ==="
echo "命令: openclaw sessions --all-agents"
echo ""

# 显示当前会话列表
timeout 10 openclaw sessions --all-agents 2>&1 | tail -10

echo ""
echo "=== 清理完成 ==="
echo "执行完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo "总结:"
echo "1. 文件清理: 删除 $TOTAL_CLEANED 个超时文件，释放 $((TOTAL_SPACE / 1024)) KB 空间"
echo "2. 元数据同步: 更新sessions.json，移除无效会话条目"
echo "3. Web UI现在只显示6小时内的活跃会话"