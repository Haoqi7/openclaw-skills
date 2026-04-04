#!/bin/bash
# OpenClaw 每日日记生成脚本
# 执行时间：每日北京时间20:00

set -e

# 配置
WORKSPACE="$HOME/.openclaw/workspace"
DAILY_DIR="$WORKSPACE/daily"
LOG_FILE="$DAILY_DIR/diary.log"

# 获取当前日期（北京时间）
BEIJING_TIME=$(TZ=Asia/Shanghai date '+%Y-%m-%d')
BEIJING_TIME_FULL=$(TZ=Asia/Shanghai date '+%Y年%m月%d日 %A')
BEIJING_HOUR=$(TZ=Asia/Shanghai date '+%H:%M')

# 日记文件路径
DIARY_FILE="$DAILY_DIR/$BEIJING_TIME.md"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Tavily API直接调用函数
call_tavily_api() {
    local query="$1"
    local count="${2:-2}"
    
    log "调用Tavily API搜索: $query"
    
    TAVILY_SCRIPT="$DAILY_DIR/tavily-curl-search.sh"
    
    if [ ! -f "$TAVILY_SCRIPT" ]; then
        log "Tavily API脚本不存在: $TAVILY_SCRIPT"
        return 1
    fi
    
    if ! command -v curl &>/dev/null; then
        log "curl命令不可用"
        return 1
    fi
    
    # 调用Tavily API脚本，使用简单格式便于解析
    local output
    local exit_code
    output=$(timeout 25 "$TAVILY_SCRIPT" --query "$query" --count "$count" --format simple 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
        echo "$output"
        return 0
    else
        log "Tavily API调用失败，退出码: $exit_code"
        return 1
    fi
}

# 解析Tavily API输出
parse_tavily_output() {
    local tavily_output="$1"
    local result_number="${2:-1}"
    
    # 初始化变量
    local title=""
    local url=""
    local content=""
    local current_item=0
    
    # 逐行解析
    while IFS= read -r line; do
        case "$line" in
            TITLE:*)
                title="${line#TITLE:}"
                ;;
            URL:*)
                url="${line#URL:}"
                ;;
            CONTENT:*)
                content="${line#CONTENT:}"
                ;;
            ---ITEM---)
                current_item=$((current_item + 1))
                if [ $current_item -eq $result_number ]; then
                    break
                fi
                # 重置变量，准备下一个item
                title=""; url=""; content=""
                ;;
        esac
    done <<< "$tavily_output"
    
    # 清理数据
    title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    url=$(echo "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 返回结果
    echo "$title|$url|$content"
}

# 获取系统数据
get_system_data() {
    log "尝试从OpenClaw API获取数据..."
    
    local system_data=""
    local total_tokens=""
    local total_cost=""
    local active_agents=""
    local system_data_status=""
    
    # 尝试调用OpenClaw API获取数据
    if command -v openclaw &>/dev/null; then
        local api_response
        if api_response=$(timeout 10 openclaw status --json 2>&1); then
            # 解析JSON数据
            if echo "$api_response" | grep -q "totalTokens"; then
                total_tokens=$(echo "$api_response" | grep -o '"totalTokens":[0-9]*' | cut -d: -f2)
                total_cost=$(echo "$api_response" | grep -o '"totalCost":[0-9.]*' | cut -d: -f2)
                active_agents=$(echo "$api_response" | grep -o '"activeAgents":[0-9]*' | cut -d: -f2)
                
                system_data_status="✅ 正常获取：成功从OpenClaw API获取实时数据"
                system_data="**Token使用统计**：${total_tokens:-0} tokens\n**累计费用**：\$${total_cost:-0.00}\n**活跃Agent数**：${active_agents:-0}"
            else
                # API可用但无数据或格式错误
                total_tokens="API无数据"
                total_cost="API无数据"
                active_agents="API无数据"
                system_data_status="⚠️ 数据缺失：OpenClaw API可用但返回空数据或格式异常"
                log "API返回空数据或格式错误"
                system_data="**Token使用统计**：API无数据\n**累计费用**：API无数据\n**活跃Agent数**：API无数据"
            fi
        else
            # 网络超时或API不可用
            system_data_status="❌ 网络超时：OpenClaw API响应超时，可能网络连接缓慢或服务繁忙"
            system_data="**Token使用统计**：API超时\n**累计费用**：API超时\n**活跃Agent数**：API超时"
            log "OpenClaw API调用超时"
        fi
    else
        # OpenClaw命令不存在
        system_data_status="❌ 命令缺失：openclaw命令未找到，请检查安装"
        system_data="**Token使用统计**：命令缺失\n**累计费用**：命令缺失\n**活跃Agent数**：命令缺失"
        log "openclaw命令未找到"
    fi
    
    echo "$system_data|$system_data_status"
}

# 评估心情状态
assess_mood() {
    local work_content="$1"
    
    # 简单的心情评估逻辑
    if echo "$work_content" | grep -qi "错误\|失败\|故障\|异常"; then
        echo "警惕专注|发现系统异常需要重点关注|加强监控，及时处理问题"
    elif echo "$work_content" | grep -qi "复杂\|困难\|挑战\|紧急"; then
        echo "沉着应对|处理复杂情况，保持冷静|按计划推进，保持稳定"
    elif echo "$work_content" | grep -qi "成功\|完成\|顺利\|良好"; then
        echo "满意欣慰|任务顺利完成，体系运转良好|继续保持高效运转"
    elif [ -n "$work_content" ]; then
        echo "平静专注|按部就班执行日常任务|保持当前工作节奏"
    else
        echo "略有疲惫但充实|工作量大但成果显著|合理安排休息，保持效率"
    fi
}

# 主函数
main() {
    log "=== 开始执行每日日记生成 ==="
    log "当前时间（北京时间）: $BEIJING_TIME_FULL $BEIJING_HOUR"
    
    # 1. 获取系统数据
    log "获取系统数据..."
    local system_data_result
    system_data_result=$(get_system_data)
    local system_data=$(echo "$system_data_result" | cut -d'|' -f1)
    local system_data_status=$(echo "$system_data_result" | cut -d'|' -f2)
    
    # 2. 提取工作内容（从memory文件）
    log "提取工作内容..."
    local work_content=""
    local memory_file="$WORKSPACE/memory/$BEIJING_TIME.md"
    if [ -f "$memory_file" ]; then
        work_content=$(head -20 "$memory_file" | grep -v "^#" | head -5 | tr '\n' ' ')
    fi
    
    if [ -z "$work_content" ]; then
        work_content="今日无特别工作记录，执行常规维护任务。"
    fi
    
    # 3. 评估心情状态
    log "评估心情状态..."
    local mood_result
    mood_result=$(assess_mood "$work_content")
    local mood=$(echo "$mood_result" | cut -d'|' -f1)
    local mood_reason=$(echo "$mood_result" | cut -d'|' -f2)
    local tomorrow_outlook=$(echo "$mood_result" | cut -d'|' -f3)
    
    # 4. 获取新闻内容
    log "生成近三天真实新闻摘要（Tavily API直接调用方案）..."
    local finance_news=""
    local tech_news=""
    
    log "开始Tavily API新闻搜索..."
    log "Tavily API配置检查：使用tavily-curl-search.sh"
    
    # 尝试搜索经济新闻（使用Tavily API）
    local finance_query="$BEIJING_TIME 经济 财经 新闻 近三天"
    local finance_tavily_output
    if finance_tavily_output=$(call_tavily_api "$finance_query" 2); then
        log "经济新闻Tavily API调用成功"
        
        # 解析第一个结果
        local finance_result1
        if finance_result1=$(parse_tavily_output "$finance_tavily_output" 1); then
            local finance_title1=$(echo "$finance_result1" | cut -d'|' -f1)
            local finance_url1=$(echo "$finance_result1" | cut -d'|' -f2)
            local finance_content1=$(echo "$finance_result1" | cut -d'|' -f3)
            
            if [ -n "$finance_title1" ]; then
                finance_news="1. **$finance_title1**\n   - 链接：$finance_url1\n   - 摘要：$finance_content1\n\n"
            fi
        fi
        
        # 解析第二个结果
        local finance_result2
        if finance_result2=$(parse_tavily_output "$finance_tavily_output" 2); then
            local finance_title2=$(echo "$finance_result2" | cut -d'|' -f1)
            local finance_url2=$(echo "$finance_result2" | cut -d'|' -f2)
            local finance_content2=$(echo "$finance_result2" | cut -d'|' -f3)
            
            if [ -n "$finance_title2" ]; then
                finance_news="${finance_news}2. **$finance_title2**\n   - 链接：$finance_url2\n   - 摘要：$finance_content2\n\n"
            fi
        fi
    else
        log "经济新闻Tavily API调用失败，尝试RSS备选方案"
        # 这里可以调用RSS备选方案
    fi
    
    # 尝试搜索科技新闻
    local tech_query="$BEIJING_TIME AI 人工智能 科技 新闻 近三天"
    local tech_tavily_output
    if tech_tavily_output=$(call_tavily_api "$tech_query" 2); then
        log "科技新闻Tavily API调用成功"
        
        # 解析第一个结果
        local tech_result1
        if tech_result1=$(parse_tavily_output "$tech_tavily_output" 1); then
            local tech_title1=$(echo "$tech_result1" | cut -d'|' -f1)
            local tech_url1=$(echo "$tech_result1" | cut -d'|' -f2)
            local tech_content1=$(echo "$tech_result1" | cut -d'|' -f3)
            
            if [ -n "$tech_title1" ]; then
                tech_news="1. **$tech_title1**\n   - 链接：$tech_url1\n   - 摘要：$tech_content1\n\n"
            fi
        fi
        
        # 解析第二个结果
        local tech_result2
        if tech_result2=$(parse_tavily_output "$tech_tavily_output" 2); then
            local tech_title2=$(echo "$tech_result2" | cut -d'|' -f1)
            local tech_url2=$(echo "$tech_result2" | cut -d'|' -f2)
            local tech_content2=$(echo "$tech_result2" | cut -d'|' -f3)
            
            if [ -n "$tech_title2" ]; then
                tech_news="${tech_news}2. **$tech_title2**\n   - 链接：$tech_url2\n   - 摘要：$tech_content2\n\n"
            fi
        fi
    else
        log "科技新闻Tavily API调用失败，尝试RSS备选方案"
        # 这里可以调用RSS备选方案
    fi
    
    # 如果Tavily API都失败，使用RSS备选方案
    if [ -z "$finance_news" ] && [ -z "$tech_news" ]; then
        log "Tavily API全部失败，调用RSS备选方案"
        if [ -f "$DAILY_DIR/simple-rss-fetcher.sh" ]; then
            local rss_output
            if rss_output=$(timeout 30 "$DAILY_DIR/simple-rss-fetcher.sh" 2>&1); then
                finance_news=$(echo "$rss_output" | sed -n '/### 财经新闻/,/### 科技新闻/p' | head -20)
                tech_news=$(echo "$rss_output" | sed -n '/### 科技新闻/,/^$/p' | tail -n +2)
            fi
        fi
    fi
    
    # 如果RSS也失败，按陛下指令不写那部分内容
    if [ -z "$finance_news" ]; then
        finance_news="今日无经济新闻数据。"
    fi
    
    if [ -z "$tech_news" ]; then
        tech_news="今日无科技新闻数据。"
    fi
    
    # 5. 生成日记内容
    log "生成日记内容..."
    cat > "$DIARY_FILE" << EOF
# 每日日记 - $BEIJING_TIME_FULL（北京时间：$BEIJING_HOUR）

## 系统状态概览
**执行时间**：$(date '+%Y-%m-%d %H:%M UTC') / $BEIJING_TIME_FULL $BEIJING_HOUR 北京时间
**执行者**：OpenClaw Agent
**任务类型**：定时任务自动执行
**数据获取状态**：$system_data_status

## 今日工作内容总结
$work_content

## 心情状态
**心情**：$mood
**原因**：$mood_reason
**明日展望**：$tomorrow_outlook

## 系统运转日报
$system_data

## 新闻摘要（近三天）
### 经济新闻（近三天）
$finance_news

### AI与科技（近三天）
$tech_news

## 心得体会
今日工作按计划完成，系统运转正常。将继续保持高效执行，及时处理各类任务。

## 明日计划
1. 继续执行常规维护任务
2. 监控系统状态，及时处理异常
3. 按计划推进各项定时任务

---
*本日记由OpenClaw每日日记系统自动生成*
*生成时间：$BEIJING_TIME_FULL $BEIJING_HOUR（北京时间）*
EOF
    
    log "日记生成完成: $DIARY_FILE"
    
    # 6. 可选：发布到GitHub
    if [ -f "$DAILY_DIR/github-publisher.sh" ]; then
        log "尝试发布到GitHub..."
        if "$DAILY_DIR/github-publisher.sh" "$DIARY_FILE"; then
            log "GitHub发布成功"
        else
            log "GitHub发布失败"
        fi
    fi
    
    log "=== 每日日记生成完成 ==="
    echo "✅ 日记生成完成: $DIARY_FILE"
}

# 执行主函数
main "$@"