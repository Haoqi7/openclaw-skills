#!/bin/bash
# 最终版会话清理脚本
# 清理超过6小时的所有会话文件

set -e

echo "=== 会话清理脚本开始执行 ==="
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
                
                # 使用jq处理JSON文件，处理空文件或无效JSON的情况
                if jq '.' "$SESSIONS_JSON" >/dev/null 2>&1; then
                    # 过滤掉超过6小时的会话，保留running状态的会话
                    jq --argjson cutoff "$SIX_HOURS_AGO_MS" '
                        if .entries then
                            .entries = (.entries | map(select(
                                (.updatedAt // 0) > $cutoff or 
                                (.status // "") == "running"
                            )))
                        else
                            .
                        end
                    ' "$SESSIONS_JSON" > "$SESSIONS_JSON.tmp" && mv "$SESSIONS_JSON.tmp" "$SESSIONS_JSON"
                    
                    echo "  - 已更新sessions.json，移除超时会话条目"
                    echo "  - 备份文件: $BACKUP_FILE"
                else
                    echo "  - 警告: sessions.json格式无效，跳过处理"
                    rm -f "$BACKUP_FILE"
                fi
            elif [ -f "$SESSIONS_JSON" ]; then
                echo "  - sessions.json文件为空"
            else
                echo "  - 无sessions.json文件"
            fi
            
            # 清理转录文件（.jsonl文件）
            echo "  - 检查转录文件"
            for JSONL_FILE in "$SESSIONS_DIR"/*.jsonl; do
                if [ -f "$JSONL_FILE" ]; then
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
                    
                    if [ "$FILE_MTIME_MS" -lt "$SIX_HOURS_AGO_MS" ]; then
                        if stat -c %s "$JSONL_FILE" >/dev/null 2>&1; then
                            FILE_SIZE=$(stat -c %s "$JSONL_FILE")
                        else
                            FILE_SIZE=$(stat -f %z "$JSONL_FILE")
                        fi
                        echo "    - 删除超时文件: $FILE_NAME (修改时间: $FILE_MTIME_MS, 大小: $FILE_SIZE 字节)"
                        rm -f "$JSONL_FILE"
                        TOTAL_CLEANED=$((TOTAL_CLEANED + 1))
                        TOTAL_SPACE=$((TOTAL_SPACE + FILE_SIZE))
                    fi
                fi
            done
            
            # 清理.deleted残留文件
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

# 执行OpenClaw内置清理命令，同步元数据
echo "=== 执行OpenClaw内置清理命令 ==="
openclaw sessions cleanup --fix-missing --enforce --all-agents 2>&1 | tail -20

echo ""
echo "=== 清理完成 ==="
echo "总清理文件数: $TOTAL_CLEANED"
echo "释放空间: $((TOTAL_SPACE / 1024)) KB"
echo "当前会话数量: $(openclaw sessions --all-agents 2>&1 | grep 'Sessions listed:' | awk '{print $3}')"
echo "执行完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"