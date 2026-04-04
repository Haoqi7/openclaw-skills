#!/bin/bash
# RSS新闻获取脚本（备选方案）

set -e

# RSS源配置
RSS_SOURCES='[
    {
        "name": "中国新闻网财经",
        "url": "https://www.chinanews.com.cn/rss/finance.xml",
        "category": "财经",
        "language": "zh",
        "max_items": 5,
        "days_limit": 3
    },
    {
        "name": "36氪",
        "url": "https://36kr.com/feed",
        "category": "科技",
        "language": "zh",
        "max_items": 5,
        "days_limit": 3
    },
    {
        "name": "少数派",
        "url": "https://sspai.com/feed",
        "category": "科技",
        "language": "zh",
        "max_items": 5,
        "days_limit": 3
    },
    {
        "name": "The Verge",
        "url": "https://www.theverge.com/rss/index.xml",
        "category": "科技",
        "language": "en",
        "max_items": 5,
        "days_limit": 3
    }
]'

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RSS: $1" >> "$HOME/.openclaw/workspace/daily/diary.log"
}

# 解析RSS/Atom feed
parse_feed() {
    local feed_url="$1"
    local feed_name="$2"
    local category="$3"
    local max_items="$4"
    local days_limit="$5"
    
    log "解析RSS源: $feed_name ($category)"
    
    # 获取feed内容
    local feed_content
    if ! feed_content=$(timeout 15 curl -s -L "$feed_url" 2>/dev/null); then
        log "获取RSS源失败: $feed_url"
        return 1
    fi
    
    if [ -z "$feed_content" ]; then
        log "RSS源返回空内容: $feed_url"
        return 1
    fi
    
    # 判断feed类型并解析
    local items=""
    
    if echo "$feed_content" | grep -q "<rss"; then
        # RSS 2.0格式
        items=$(echo "$feed_content" | python3 -c "
import sys, xml.etree.ElementTree as ET
from datetime import datetime, timedelta
import html

xml_content = sys.stdin.read()
try:
    root = ET.fromstring(xml_content)
    
    # 计算三天前的时间
    three_days_ago = datetime.now() - timedelta(days=3)
    
    items_found = 0
    for item in root.findall('.//item'):
        if items_found >= $max_items:
            break
            
        title_elem = item.find('title')
        link_elem = item.find('link')
        pub_date_elem = item.find('pubDate')
        description_elem = item.find('description')
        
        if title_elem is not None and link_elem is not None:
            title = html.unescape(title_elem.text or '').strip()
            link = (link_elem.text or '').strip()
            
            # 检查发布日期
            pub_date = None
            if pub_date_elem is not None and pub_date_elem.text:
                try:
                    pub_date_str = pub_date_elem.text.strip()
                    # 尝试解析常见日期格式
                    for fmt in ['%a, %d %b %Y %H:%M:%S %z', '%a, %d %b %Y %H:%M:%S %Z', '%Y-%m-%dT%H:%M:%S%z']:
                        try:
                            pub_date = datetime.strptime(pub_date_str, fmt)
                            break
                        except:
                            continue
                except:
                    pass
            
            # 如果没有发布日期或发布时间在三天内，则包含
            if pub_date is None or pub_date >= three_days_ago:
                description = ''
                if description_elem is not None and description_elem.text:
                    description = html.unescape(description_elem.text or '').strip()
                    # 清理HTML标签
                    import re
                    description = re.sub(r'<[^>]+>', '', description)
                    description = description[:150] + '...' if len(description) > 150 else description
                
                print(f'{title}|{link}|{description}')
                items_found += 1
                
except Exception as e:
    print(f'解析错误: {e}')
" 2>/dev/null)
    elif echo "$feed_content" | grep -q "<feed"; then
        # Atom格式
        items=$(echo "$feed_content" | python3 -c "
import sys, xml.etree.ElementTree as ET
from datetime import datetime, timedelta
import html

xml_content = sys.stdin.read()
try:
    root = ET.fromstring(xml_content)
    
    # 计算三天前的时间
    three_days_ago = datetime.now() - timedelta(days=3)
    
    items_found = 0
    for entry in root.findall('{http://www.w3.org/2005/Atom}entry'):
        if items_found >= $max_items:
            break
            
        title_elem = entry.find('{http://www.w3.org/2005/Atom}title')
        link_elem = entry.find('{http://www.w3.org/2005/Atom}link')
        updated_elem = entry.find('{http://www.w3.org/2005/Atom}updated')
        summary_elem = entry.find('{http://www.w3.org/2005/Atom}summary')
        
        if title_elem is not None:
            title = html.unescape(title_elem.text or '').strip()
            link = ''
            if link_elem is not None and 'href' in link_elem.attrib:
                link = link_elem.attrib['href'].strip()
            
            # 检查更新时间
            updated_date = None
            if updated_elem is not None and updated_elem.text:
                try:
                    updated_str = updated_elem.text.strip()
                    updated_date = datetime.strptime(updated_str, '%Y-%m-%dT%H:%M:%S%z')
                except:
                    pass
            
            # 如果没有更新时间或更新时间在三天内，则包含
            if updated_date is None or updated_date >= three_days_ago:
                summary = ''
                if summary_elem is not None and summary_elem.text:
                    summary = html.unescape(summary_elem.text or '').strip()
                    import re
                    summary = re.sub(r'<[^>]+>', '', summary)
                    summary = summary[:150] + '...' if len(summary) > 150 else summary
                
                print(f'{title}|{link}|{summary}')
                items_found += 1
                
except Exception as e:
    print(f'解析错误: {e}')
" 2>/dev/null)
    else
        log "未知的feed格式: $feed_url"
        return 1
    fi
    
    if [ -z "$items" ]; then
        log "未从RSS源解析到内容: $feed_name"
        return 1
    fi
    
    echo "$items"
    return 0
}

# 主函数
main() {
    log "开始RSS新闻获取"
    
    # 按类别收集新闻
    local finance_items=""
    local tech_items=""
    
    # 解析RSS源配置
    echo "$RSS_SOURCES" | python3 -c "
import json, sys
sources = json.load(sys.stdin)
for source in sources:
    print(f'{source[\"name\"]}|{source[\"url\"]}|{source[\"category\"]}|{source[\"max_items\"]}|{source[\"days_limit\"]}')
" | while IFS='|' read -r name url category max_items days_limit; do
        log "处理RSS源: $name ($category)"
        
        local items
        if items=$(parse_feed "$url" "$name" "$category" "$max_items" "$days_limit"); then
            # 按类别分组
            if [ "$category" = "财经" ]; then
                finance_items="${finance_items}${items}\n"
            elif [ "$category" = "科技" ]; then
                tech_items="${tech_items}${items}\n"
            fi
        fi
    done
    
    # 输出结果
    echo "### 财经新闻（近三天）"
    echo ""
    
    if [ -n "$finance_items" ]; then
        local item_count=1
        echo "$finance_items" | while IFS='|' read -r title link description; do
            if [ -n "$title" ]; then
                echo "$item_count. **$title**"
                if [ -n "$link" ]; then
                    echo "   - 链接：$link"
                fi
                if [ -n "$description" ]; then
                    echo "   - 摘要：$description"
                fi
                echo ""
                item_count=$((item_count + 1))
            fi
        done
    else
        echo "今日无财经新闻数据。"
        echo ""
    fi
    
    echo "### 科技新闻（近三天）"
    echo ""
    
    if [ -n "$tech_items" ]; then
        local item_count=1
        echo "$tech_items" | while IFS='|' read -r title link description; do
            if [ -n "$title" ]; then
                echo "$item_count. **$title**"
                if [ -n "$link" ]; then
                    echo "   - 链接：$link"
                fi
                if [ -n "$description" ]; then
                    echo "   - 摘要：$description"
                fi
                echo ""
                item_count=$((item_count + 1))
            fi
        done
    else
        echo "今日无科技新闻数据。"
        echo ""
    fi
    
    log "RSS新闻获取完成"
}

# 执行主函数
main "$@"