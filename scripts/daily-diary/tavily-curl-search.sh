#!/bin/bash
# 使用curl调用Tavily API的搜索脚本

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HOME/.openclaw/workspace/daily/tavily-search.log"
}

search_tavily() {
    local query="$1"
    local count="${2:-2}"
    
    log "调用Tavily API: $query"
    
    # Tavily API密钥（需要用户自行配置）
    local api_key="${TAVILY_API_KEY}"
    
    if [ -z "$api_key" ]; then
        # 尝试从OpenClaw配置中获取
        if [ -f "$HOME/.openclaw/openclaw.json" ]; then
            api_key=$(grep -o '"tavilyApiKey":"[^"]*"' "$HOME/.openclaw/openclaw.json" | cut -d'"' -f4)
        fi
    fi
    
    if [ -z "$api_key" ]; then
        log "错误: Tavily API密钥未配置"
        echo "请设置TAVILY_API_KEY环境变量或在OpenClaw配置文件中配置tavilyApiKey"
        return 1
    fi
    
    # 构建JSON请求
    local json_request=$(cat <<EOF
{
    "api_key": "$api_key",
    "query": "$query",
    "search_depth": "basic",
    "include_answer": false,
    "include_images": false,
    "include_raw_content": false,
    "max_results": $count,
    "include_domains": [],
    "exclude_domains": []
}
EOF
)
    
    # 调用Tavily API
    local response
    response=$(timeout 20 curl -s -X POST "https://api.tavily.com/search" \
        -H "Content-Type: application/json" \
        -d "$json_request" 2>&1)
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -n "$response" ]; then
        log "Tavily API响应成功"
        echo "$response"
        return 0
    else
        log "Tavily API调用失败，退出码: $exit_code"
        return 1
    fi
}

# 解析JSON响应
parse_json_response() {
    local json_response="$1"
    local format="${2:-simple}"
    
    if [ "$format" = "simple" ]; then
        # 简单格式：TITLE|URL|CONTENT
        echo "$json_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'results' in data:
        for i, result in enumerate(data['results'], 1):
            title = result.get('title', '').replace('|', '｜')
            url = result.get('url', '')
            content = result.get('content', '').replace('|', '｜').replace('\n', ' ')[:200]
            print(f'TITLE:{title}')
            print(f'URL:{url}')
            print(f'CONTENT:{content}')
            if i < len(data['results']):
                print('---ITEM---')
    else:
        print('错误: 响应格式不正确')
except Exception as e:
    print(f'解析错误: {e}')
" 2>/dev/null || echo "解析失败"
    else
        # JSON格式
        echo "$json_response"
    fi
}

# 主函数
main() {
    local query=""
    local count=2
    local format="simple"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --query)
                query="$2"
                shift 2
                ;;
            --count)
                count="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            *)
                echo "未知参数: $1"
                echo "用法: $0 --query \"搜索内容\" [--count 结果数量] [--format simple|json]"
                return 1
                ;;
        esac
    done
    
    if [ -z "$query" ]; then
        echo "错误: 必须提供 --query 参数"
        echo "用法: $0 --query \"搜索内容\" [--count 结果数量] [--format simple|json]"
        return 1
    fi
    
    # 调用Tavily API
    local response
    if response=$(search_tavily "$query" "$count"); then
        parse_json_response "$response" "$format"
        return 0
    else
        echo "Tavily API调用失败"
        return 1
    fi
}

# 执行主函数
main "$@"