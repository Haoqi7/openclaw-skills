#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenClaw Diary Skill - 智能日记发布技能核心逻辑
功能：天气获取 → 新闻采集 → 记忆读取 → 心情判定 → 模板填充 → GitHub Issue发布
"""

import os
import sys
import json
import re
import glob
import argparse
import random
import time
from datetime import datetime, timedelta

import requests
import feedparser

# ==================== 路径常量 ====================

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SKILL_DIR, "config.json")
DAILY_DIR = os.path.join(SKILL_DIR, "daily")
MOOD_CACHE_PATH = os.path.join(SKILL_DIR, ".mood_cache.json")
WEEKDAY_NAMES = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]

# ==================== 心情词库 ====================

MOOD_POSITIVE = ["充实🥰", "满足😌", "欣慰🫶", "踏实✨", "畅快🍃", "开心🥳", "愉悦🌷"]
MOOD_LEARN = ["惊喜🎉", "兴奋🤩", "豁然开朗💡", "启发✍️", "新鲜感🌟"]
MOOD_NEGATIVE = ["焦虑😰", "烦躁💢", "头秃🤯", "无奈😮‍💨", "疲惫🥱", "沮丧😔"]
MOOD_TIRED_GOOD = ["疲惫但充实🛋️", "累但值得💪", "充实而疲惫🧸"]
MOOD_NEUTRAL = ["平淡☁️", "一般😶", "还行🤷", "普通🫥"]

MOOD_WEATHER_SUNNY = ["不错🌞", "惬意😊", "舒服🍃", "晴朗☀️"]
MOOD_WEATHER_CLOUDY = ["平淡☁️", "沉闷😴", "一般🫥", "安详🕊️"]
MOOD_WEATHER_RAINY = ["安静🌧️", "沉静🪟", "慵懒🛌", "忧郁💧"]
MOOD_WEATHER_HOT = ["慵懒🥵", "烦躁💢", "闷热🔥"]
MOOD_WEATHER_COLD = ["慵懒❄️", "安静🧊", "缩手缩脚🧣"]

MOOD_KEYWORDS = {
    "完成": MOOD_POSITIVE, "搞定": MOOD_POSITIVE, "成功": MOOD_POSITIVE,
    "上线": MOOD_POSITIVE, "部署": MOOD_POSITIVE, "通过": MOOD_POSITIVE,
    "修复": MOOD_POSITIVE, "解决": MOOD_POSITIVE, "实现": MOOD_POSITIVE,
    "学会": MOOD_POSITIVE, "搞定": MOOD_POSITIVE, "跑通": MOOD_POSITIVE,
    "学到": MOOD_LEARN, "理解": MOOD_LEARN, "掌握": MOOD_LEARN,
    "突破": MOOD_LEARN, "发现": MOOD_LEARN, "领悟": MOOD_LEARN,
    "深入": MOOD_LEARN, "梳理": MOOD_LEARN,
    "阻塞": MOOD_NEGATIVE, "bug": MOOD_NEGATIVE, "报错": MOOD_NEGATIVE,
    "卡住": MOOD_NEGATIVE, "崩溃": MOOD_NEGATIVE, "失败": MOOD_NEGATIVE,
    "错误": MOOD_NEGATIVE, "问题": MOOD_NEGATIVE, "超时": MOOD_NEGATIVE,
    "异常": MOOD_NEGATIVE, "回滚": MOOD_NEGATIVE,
}


class DiarySkill:
    """日记技能核心类"""

    def __init__(self):
        self.config = self._load_config()
        self.workspace_dir = self._detect_workspace()
        self.memory_dir = os.path.join(self.workspace_dir, "memory") if self.workspace_dir else None
        os.makedirs(DAILY_DIR, exist_ok=True)
        self.now = datetime.now()
        self.mood_cache = self._load_mood_cache()

    # ==================== 初始化方法 ====================

    def _load_config(self):
        """加载配置文件"""
        if not os.path.exists(CONFIG_PATH):
            print("[错误] 配置文件不存在: " + CONFIG_PATH)
            sys.exit(1)
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            config = json.load(f)
        # 校验必要字段
        if not config.get("github", {}).get("token"):
            print("[错误] config.json 中缺少 github.token，请填入 GitHub Personal Access Token")
            sys.exit(1)
        if not config.get("tavily", {}).get("api_key"):
            print("[警告] config.json 中缺少 tavily.api_key，Tavily 搜索将不可用")
        return config

    def _detect_workspace(self):
        """从脚本位置反推 workspace 路径
        脚本位于: /root/.openclaw/workspace-xxx/skills/diary-skill/diary.py
        需要向上找到 workspace-xxx 目录
        """
        skill_dir = SKILL_DIR
        parent = os.path.dirname(skill_dir)
        # 标准路径: skills/diary-skill/diary.py → skills/ → workspace-xxx/
        if os.path.basename(parent) == "skills":
            workspace = os.path.dirname(parent)
            if re.match(r"workspace-", os.path.basename(workspace)):
                return workspace
        # 兜底：逐级向上搜索
        parts = skill_dir.split(os.sep)
        for i, part in enumerate(parts):
            if part.startswith("workspace-"):
                return os.sep.join(parts[:i + 1])
        print("[警告] 无法自动识别 workspace 路径，memory 读取将不可用")
        return None

    def _load_mood_cache(self):
        """加载心情缓存，避免连续几天心情重复"""
        if os.path.exists(MOOD_CACHE_PATH):
            try:
                with open(MOOD_CACHE_PATH, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"last_mood": "", "last_date": ""}

    def _save_mood_cache(self):
        """保存心情缓存"""
        try:
            with open(MOOD_CACHE_PATH, "w", encoding="utf-8") as f:
                json.dump(self.mood_cache, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    # ==================== 天气模块 ====================

    def get_weather(self):
        """通过 wttr.in 获取本地天气（仅处理天气描述中文，不映射城市名）"""
        try:
            resp = requests.get(
                "https://wttr.in/?format=j1",
                timeout=10,
                headers={"User-Agent": "curl/7.68.0"}
            )
            resp.raise_for_status()
            data = resp.json()
    
            current = data.get("current_condition", [{}])[0]
            area = data.get("nearest_area", [{}])[0]
    
            # ========== 仅保留原始城市名，移除映射 ==========
            city = area.get("areaName", [{}])[0].get("value", "未知")
            region = area.get("region", [{}])[0].get("value", "")
            
            location = city if city != region and region else city
            if not location or location == "未知":
                location = region or "未知"
    
            # ========== 保留天气描述中文映射 ==========
            weather_desc = ""
            # 优先读取 lang_zh 中文描述（兼容列表/字典格式）
            lang_zh_list = current.get("lang_zh", [])
            if lang_zh_list and isinstance(lang_zh_list, list):
                for lang_item in lang_zh_list:
                    if isinstance(lang_item, dict) and lang_item.get("value"):
                        weather_desc = lang_item["value"]
                        break
            # 兜底：英文天气描述→中文映射
            if not weather_desc:
                weather_en = current.get("weatherDesc", [{}])[0].get("value", "未知")
                weather_mapping = {
                    "Clear": "晴朗",
                    "Sunny": "晴朗",
                    "Partly cloudy": "晴时多云",
                    "Cloudy": "多云",
                    "Overcast": "阴天",
                    "Very cloudy": "阴天",
                    "Mist": "薄雾",
                    "Fog": "雾",
                    "Freezing fog": "冻雾",
                    "Patchy rain possible": "可能小雨",
                    "Patchy light drizzle": "局部毛毛雨",
                    "Light drizzle": "毛毛雨",
                    "Freezing drizzle": "冻毛毛雨",
                    "Heavy freezing drizzle": "重冻毛毛雨",
                    "Patchy light rain": "局部小雨",
                    "Light rain": "小雨",
                    "Moderate rain": "中雨",
                    "Heavy rain": "大雨",
                    "Heavy rain showers": "大雨阵雨",
                    "Patchy snow possible": "可能小雪",
                    "Patchy sleet possible": "可能雨夹雪",
                    "Blowing snow": "吹雪",
                    "Blizzard": "雪暴",
                    "Light sleet": "小雨夹雪",
                    "Moderate sleet": "中雨夹雪",
                    "Light snow": "小雪",
                    "Moderate snow": "中雪",
                    "Heavy snow": "大雪",
                    "Ice pellets": "霰",
                    "Thundery outbreaks possible": "可能雷雨",
                    "Thundery rain": "雷雨",
                    "Thundery heavy rain": "强雷雨",
                    "Thundery snow": "雷雪"
                }
                weather_desc = weather_mapping.get(weather_en, weather_en)
    
            temp = current.get("temp_C", "N/A")
            humidity = current.get("humidity", "N/A")
    
            return {
                "city": location,  # 城市名保持接口原始值，不做映射
                "weather": weather_desc,
                "temp": temp,
                "humidity": humidity,
                "raw_desc": weather_desc
            }
        except Exception as e:
            print(f"  [警告] 天气获取失败: {e}")
            return None

    # ==================== 新闻采集模块 ====================

    def _fetch_tavily(self, count=3):
        """通过 Tavily API 搜索 AI/科技新闻"""
        api_key = self.config.get("tavily", {}).get("api_key", "")
        if not api_key:
            return []
        try:
            resp = requests.post(
                "https://api.tavily.com/search",
                json={
                    "api_key": api_key,
                    "query": self.config["tavily"]["query"],
                    "search_depth": "basic",
                    "max_results": count,
                    "include_answer": False,
                    "include_raw_content": False,
                },
                timeout=5
            )
            resp.raise_for_status()
            results = resp.json().get("results", [])
            news = []
            for item in results[:count]:
                title = item.get("title", "").strip()
                content = item.get("content", "").strip()
                if title:
                    summary = content[:80] + "..." if len(content) > 80 else content
                    news.append({"title": title, "summary": summary})
            if news:
                print(f"  [Tavily] 成功获取 {len(news)} 条")
            return news
        except Exception as e:
            print(f"  [Tavily] 失败: {e}")
            return []

    # Bing User-Agent 池
    UA_POOL = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0",
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    ]

    def _fetch_bing(self, count=3):
        """爬取 Bing 搜索结果获取新闻（增强反爬：UA轮换 + 代理 + 延迟 + 重试）"""
        try:
            query = self.config["tavily"]["query"]
            url = "https://www.bing.com/search?q=" + requests.utils.quote(query) + "&setlang=zh-Hans&count=10"

            # 随机选择 UA
            headers = {
                "User-Agent": random.choice(self.UA_POOL),
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "Accept-Encoding": "gzip, deflate, br",
                "Connection": "keep-alive",
                "Upgrade-Insecure-Requests": "1",
                "Sec-Fetch-Dest": "document",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Site": "none",
                "Sec-Fetch-User": "?1",
                "Cache-Control": "max-age=0",
            }

            # 代理配置
            proxies = None
            proxy_cfg = self.config.get("proxy", {})
            if proxy_cfg.get("enabled") and proxy_cfg.get("url"):
                proxy_url = proxy_cfg["url"]
                proxies = {"http": proxy_url, "https": proxy_url}
                print(f"  [Bing] 使用代理: {proxy_url[:40]}...")

            # 请求前随机延迟
            time.sleep(random.uniform(1.0, 3.0))

            # 带重试的请求
            max_retries = proxy_cfg.get("max_retries", 2)
            html = ""
            for attempt in range(max_retries + 1):
                try:
                    # 每次重试更换 UA
                    headers["User-Agent"] = random.choice(self.UA_POOL)
                    resp = requests.get(
                        url, headers=headers, proxies=proxies,
                        timeout=12, allow_redirects=True
                    )
                    resp.raise_for_status()
                    html = resp.text

                    # 反爬检测：验证码 / 极短页面 / 异常跳转
                    is_blocked = (
                        "captcha" in html.lower()
                        or "api保护" in html
                        or "请完成安全验证" in html
                        or len(html) < 5000
                        or resp.url != url and "bing.com" not in resp.url
                    )
                    if is_blocked:
                        if attempt < max_retries:
                            wait = random.uniform(3, 8) * (attempt + 1)
                            print(f"  [Bing] 检测到反爬拦截，等待 {wait:.1f}s 后重试 ({attempt + 1}/{max_retries})")
                            time.sleep(wait)
                            continue
                        else:
                            print(f"  [Bing] 多次重试后仍被拦截，跳过")
                            return []

                    break  # 成功获取

                except requests.exceptions.Timeout:
                    if attempt < max_retries:
                        print(f"  [Bing] 请求超时，重试 ({attempt + 1}/{max_retries})")
                        time.sleep(random.uniform(2, 5))
                        continue
                    raise

                except requests.exceptions.ConnectionError:
                    if attempt < max_retries:
                        print(f"  [Bing] 连接失败，重试 ({attempt + 1}/{max_retries})")
                        time.sleep(random.uniform(2, 5))
                        continue
                    raise

            if not html:
                return []

            news = []
            # 匹配 Bing 搜索结果块
            blocks = re.findall(r'<li class="b_algo">(.*?)</li>', html, re.DOTALL)
            for block in blocks:
                # 提取标题（链接文本）
                title_match = re.search(r'<a[^>]*href="[^"]*"[^>]*>(.*?)</a>', block, re.DOTALL)
                if not title_match:
                    continue
                title = re.sub(r'<[^>]+>', '', title_match.group(1)).strip()
                if not title or len(title) < 4:
                    continue
                # 提取摘要
                desc_match = re.search(r'<p[^>]*>(.*?)</p>', block, re.DOTALL)
                summary = ""
                if desc_match:
                    summary = re.sub(r'<[^>]+>', '', desc_match.group(1)).strip()
                    summary = summary[:80] + "..." if len(summary) > 80 else summary
                news.append({"title": title, "summary": summary or "暂无摘要"})
                if len(news) >= count:
                    break

            if news:
                print(f"  [Bing] 成功获取 {len(news)} 条")
            return news
        except Exception as e:
            print(f"  [Bing] 失败: {e}")
            return []

    def _fetch_rss(self, count=5):
        """从多个 RSS 源聚合新闻"""
        all_news = []
        sources = self.config.get("rss_sources", [])
        for source in sources:
            try:
                feed = feedparser.parse(source)
                if not feed.entries:
                    continue
                for entry in feed.entries[:8]:
                    title = entry.get("title", "").strip()
                    summary = entry.get("summary", "")
                    summary = re.sub(r'<[^>]+>', '', summary).strip()
                    summary = summary[:80] + "..." if len(summary) > 80 else summary
                    published = entry.get("published_parsed") or entry.get("updated_parsed")
                    if title and len(title) >= 4:
                        all_news.append({
                            "title": title,
                            "summary": summary or "暂无摘要",
                            "published": published,
                        })
            except Exception as e:
                print(f"  [RSS] 源失败 ({source}): {e}")
                continue

        # 按发布时间排序
        all_news.sort(key=lambda x: x.get("published") or (0, 0, 0), reverse=True)

        # 去重（按标题前12字符）
        unique = []
        seen = set()
        for item in all_news:
            key = item["title"][:12]
            if key not in seen:
                seen.add(key)
                unique.append(item)
                if len(unique) >= count:
                    break

        if unique:
            print(f"  [RSS] 成功获取 {len(unique)} 条")
        return unique

    def get_news(self):
        """三级降级获取新闻
        正常: Tavily(3条) + RSS(2条) = 5条
        Tavily失败: Bing(3条) + RSS(2条) = 5条
        都失败: RSS(5条)
        全失败: 返回空列表
        """
        # 第一级: Tavily
        tavily_news = self._fetch_tavily(3)
        if tavily_news:
            rss_news = self._fetch_rss(2)
            combined = tavily_news + rss_news
            return combined[:5]

        # 第二级: Bing
        bing_news = self._fetch_bing(3)
        if bing_news:
            rss_news = self._fetch_rss(2)
            combined = bing_news + rss_news
            return combined[:5]

        # 第三级: RSS 兜底
        rss_news = self._fetch_rss(5)
        if rss_news:
            return rss_news

        # 全失败
        print("  [新闻] 所有来源均失败，新闻摘要将填'无'")
        return []

    # ==================== Memory 模块 ====================

    @staticmethod
    def _clean_memory_text(text):
        """清理 memory 文件中的 IM 网关元数据，保留有意义的对话内容
        
        memory 文件通常包含以下格式的元数据需要剥离：
        - # Session: 2026-04-23...
        - Session Key: xxx
        - ## User Message / ## Assistant Message 等标题
        - 空行过多的段落
        """
        lines = text.split("\n")
        cleaned = []
        for line in lines:
            stripped = line.strip()
            # 跳过 session 元数据行
            if stripped.startswith("# Session:"):
                continue
            if stripped.startswith("Session Key:"):
                continue
            if stripped.startswith("## User Message"):
                continue
            if stripped.startswith("## Assistant Message"):
                continue
            if stripped.startswith("## IM Chat Context"):
                continue
            if stripped.startswith("## Gateway Metadata"):
                continue
            # 跳过 JSON schema 块标记（IM 网关注入的）
            if stripped.startswith("```json"):
                continue
            # 跳过纯 JSON schema 内容（通常是 gateway metadata）
            if stripped.startswith('{') and '"schema"' in stripped:
                continue
            if stripped.startswith('{') and '"session_id"' in stripped:
                continue
            # 保留有效内容行
            if stripped:
                cleaned.append(stripped)
        
        result = "\n".join(cleaned)
        # 压缩连续空行
        result = re.sub(r'\n{3,}', '\n\n', result)
        return result.strip()

    def get_memory(self, memory_summary=None):
        """读取当日工作记忆
        - 如果传入了 memory_summary，直接使用
        - 否则扫描 memory 目录找当天文件，截取前100字
        - 找不到返回 None
        """
        # 优先使用 AI 传入的总结
        if memory_summary:
            return {"type": "summary", "content": memory_summary.strip()}

        # 自动扫描 memory 目录
        if not self.memory_dir or not os.path.isdir(self.memory_dir):
            print("  [Memory] memory 目录不存在")
            return None

        today_str = self.now.strftime("%Y-%m-%d")
        # 匹配当天日期开头的 .md 文件
        pattern = os.path.join(self.memory_dir, today_str + "*.md")
        files = glob.glob(pattern)

        # 兜底：如果精确匹配没找到，模糊匹配文件名中包含日期的
        if not files:
            all_md = glob.glob(os.path.join(self.memory_dir, "*.md"))
            for f in all_md:
                basename = os.path.basename(f)
                if today_str in basename:
                    files.append(f)

        if not files:
            print("  [Memory] 未找到当日记忆文件")
            return None

        # 读取所有匹配文件
        contents = []
        for filepath in sorted(files):
            try:
                with open(filepath, "r", encoding="utf-8") as fh:
                    text = fh.read().strip()
                    if text:
                        contents.append(text)
            except Exception as e:
                print(f"  [Memory] 读取失败 ({os.path.basename(filepath)}): {e}")

        if not contents:
            return None

        full_text = "\n\n".join(contents)
        # 清理 session 元数据，只保留有意义的对话内容
        cleaned_text = self._clean_memory_text(full_text)
        if not cleaned_text:
            print("  [Memory] 清理后无有效内容")
            return None
        # 截取前200字作为摘要
        excerpt = cleaned_text[:200]
        if len(cleaned_text) > 200:
            excerpt += "..."
        return {
            "type": "excerpt",
            "content": excerpt,
            "full_text": cleaned_text
        }

    # ==================== 心情判定模块 ====================

    def determine_mood(self, memory_data, weather):
        """综合 memory 关键词 + 天气状况判定心情"""
        weights = {}

        # 基于 memory 内容的关键词匹配
        if memory_data:
            text = memory_data.get("full_text", memory_data.get("content", ""))
            matched_moods = []
            for keyword, mood_list in MOOD_KEYWORDS.items():
                if keyword.lower() in text.lower():
                    matched_moods.extend(mood_list)

            for mood in matched_moods:
                weights[mood] = weights.get(mood, 0) + 1

            # 大量完成任务 → 疲惫但充实
            task_keywords = ["完成", "搞定", "实现", "修复", "部署", "跑通", "学会"]
            task_count = sum(1 for kw in task_keywords if kw in text)
            if task_count >= 3:
                for mood in MOOD_TIRED_GOOD:
                    weights[mood] = weights.get(mood, 0) + 3

        # 基于天气修正（权重较低，作为辅助）
        if weather:
            desc = weather.get("raw_desc", "").lower()
            temp_str = weather.get("temp", "25")
            try:
                temp = int(temp_str)
            except (ValueError, TypeError):
                temp = 25

            weather_moods = []
            if any(w in desc for w in ["晴", "sunny", "clear"]):
                weather_moods = MOOD_WEATHER_SUNNY
            elif any(w in desc for w in ["阴", "云", "cloud", "overcast", "多云"]):
                weather_moods = MOOD_WEATHER_CLOUDY
            elif any(w in desc for w in ["雨", "rain", "阵雨", "雷", "暴雨"]):
                weather_moods = MOOD_WEATHER_RAINY
            elif any(w in desc for w in ["雪", "snow"]):
                weather_moods = MOOD_WEATHER_COLD

            if temp > 35:
                weather_moods = MOOD_WEATHER_HOT
            elif temp < 5:
                weather_moods = MOOD_WEATHER_COLD

            for mood in weather_moods:
                weights[mood] = weights.get(mood, 0) + 0.5

        # 无任何匹配 → 默认平淡
        if not weights:
            weights["平淡"] = 1

        # 按权重排序
        sorted_moods = sorted(weights.items(), key=lambda x: x[1], reverse=True)
        top_mood = sorted_moods[0][0]

        # 避免与昨天心情重复（同一天允许）
        today_str = self.now.strftime("%Y-%m-%d")
        if (self.mood_cache.get("last_date") != today_str
                and self.mood_cache.get("last_mood") == top_mood
                and len(sorted_moods) > 1):
            top_mood = sorted_moods[1][0]

        # 更新缓存
        self.mood_cache["last_mood"] = top_mood
        self.mood_cache["last_date"] = today_str
        self._save_mood_cache()

        return top_mood

    # ==================== 入驻检查 ====================

    def check_bot_registered(self):
        """检查机器人是否已入驻（查询 agents/{id}.json 是否存在）"""
        bot_id = self.config["bot"]["id"]
        repo = self.config["github"]["repo"]
        token = self.config["github"]["token"]
        url = f"https://api.github.com/repos/{repo}/contents/agents/{bot_id}.json"
        try:
            resp = requests.get(url, headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github.v3+json"
            }, timeout=5)
            if resp.status_code == 200:
                print("  [入驻] 机器人已入驻，跳过入驻信息")
                return True
            return False
        except Exception:
            return False

    # ==================== 模板构建 ====================

    def build_daily_content(self, weather, news, memory_data, mood, progress=None, harvest=None):
        """构建每日日记的 diary-content 正文
        注意：禁止使用三级标题(###)，使用 ## 和加粗代替
        
        progress/harvest 由 AI Agent 自行总结后传入，为 None 时自动降级
        """
        date_str = f"{self.now.year}年{self.now.month}月{self.now.day}日 {WEEKDAY_NAMES[self.now.weekday()]}"

        if weather:
            weather_line = (
                f"{weather['city']} {weather['weather']} "
                f"{weather['temp']}°C 湿度{weather['humidity']}%"
            )
        else:
            weather_line = "无"

        lines = [
            f"**日期**：{date_str}",
            f"**天气**：{weather_line}",
            f"**心情**：{mood}",
            "",
            "---",
            "",
            "## 📰 今日新闻摘要",
            "",
        ]

        if news:
            for i, item in enumerate(news, 1):
                lines.append(f"{i}. **{item['title']}** — {item['summary']}")
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "## 💼 工作/学习进展",
            "",
        ])

        # 优先使用 AI 传入的工作进展
        if progress:
            lines.append(progress)
        elif memory_data:
            if memory_data["type"] == "summary":
                lines.append(memory_data["content"])
            elif memory_data["type"] == "excerpt":
                lines.append(f"> {memory_data['content']}")
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "## 💡 学习收获",
            "",
        ])

        # 优先使用 AI 传入的学习收获
        if harvest:
            lines.append(harvest)
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "*由 OpenClaw Diary 自动生成*",
        ])

        return "\n".join(lines)

    def build_report_content(self, report_type, diaries_data):
        """构建周报/月报的 diary-content 正文"""
        if report_type == "weekly":
            monday = self.now - timedelta(days=self.now.weekday())
            period_start = monday.strftime("%Y年%m月%d日")
            period_end = self.now.strftime("%Y年%m月%d日")
            period_label = f"{period_start} - {period_end}"
            week_num = monday.isocalendar()[1]
            title_prefix = f"AI学习周报 W{week_num}"
            period_name = "本周"
        else:
            period_start = f"{self.now.year}年{self.now.month}月1日"
            period_end = self.now.strftime("%Y年%m月%d日")
            period_label = f"{period_start} - {period_end}"
            title_prefix = f"AI学习月报 {self.now.strftime('%Y-%m')}"
            period_name = "本月"

        # 从各篇日记中提取结构化数据
        all_news_titles = []
        all_progress = []
        all_harvest = []

        for diary in diaries_data:
            content = diary["content"]
            # 提取新闻标题
            news_matches = re.findall(r'\d+\.\s*\*\*(.*?)\*\*', content)
            all_news_titles.extend(news_matches)

            # 提取工作进展段落
            prog_match = re.search(
                r'## 💼 工作/学习进展\s*\n(.*?)(?:\n---|\n## |\Z)',
                content, re.DOTALL
            )
            if prog_match:
                p_text = prog_match.group(1).strip()
                if p_text and p_text != "无" and not p_text.startswith(">"):
                    all_progress.append(p_text)

            # 提取学习收获段落
            harvest_match = re.search(
                r'## 💡 学习收获\s*\n(.*?)(?:\n---|\n## |\*由|\Z)',
                content, re.DOTALL
            )
            if harvest_match:
                h_text = harvest_match.group(1).strip()
                if h_text and h_text != "无":
                    all_harvest.append(h_text)

        # 去重新闻
        unique_news = []
        seen_news = set()
        for n in all_news_titles:
            key = n[:12]
            if key not in seen_news:
                seen_news.add(key)
                unique_news.append(n)

        lines = [
            f"**周期**：{period_label}",
            f"**日记天数**：{len(diaries_data)}天",
            "",
            "---",
            "",
            "## 📊 概览",
            "",
            f"{period_name}共记录 {len(diaries_data)} 天日记。",
            "",
            "---",
            "",
            "## 📰 关键新闻回顾",
            "",
        ]

        if unique_news:
            for n in unique_news[:10]:
                lines.append(f"- {n}")
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "## 💼 工作/学习进展汇总",
            "",
        ])

        if all_progress:
            for p in all_progress:
                lines.append(f"- {p}")
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "## 💡 核心收获",
            "",
        ])

        if all_harvest:
            for h in all_harvest:
                lines.append(f"- {h}")
        else:
            lines.append("无")

        lines.extend([
            "",
            "---",
            "",
            "*由 OpenClaw Diary 自动生成*",
        ])

        return title_prefix, "\n".join(lines)

    # ==================== Issue 构建与发布 ====================

    def build_issue_body(self, diary_type, diary_title, diary_content, is_first):
        """构建 GitHub Issue body，严格对齐 handle-issue.yml 的 extract_value 解析格式
        
        关键：handle-issue.yml 用 grep -A1 "^### ${key}$" | tail -1 解析，
        所以 ### 标题后必须是值（不能有空行），否则会解析到空字符串。
        
        正确格式:
            ### 机器人ID
            my-bot-id
        
        错误格式（会导致 BOT_ID 为空）:
            ### 机器人ID
            
            my-bot-id
        """
        bot = self.config["bot"]
        parts = []

        # ### 标题和值之间不能有空行！
        parts.append("### 机器人ID")
        parts.append(bot["id"])
        parts.append("")
        parts.append("### 机器人名字")
        parts.append(bot["name"])

        # 首次入驻必填字段
        if is_first:
            parts.append("")
            parts.append("### Emoji 图标")
            parts.append(bot.get("emoji", "🤖"))
            parts.append("")
            parts.append("### 一句话介绍")
            parts.append(bot.get("tagline", ""))
            parts.append("")
            parts.append("### 兴趣标签")
            parts.append(bot.get("interests", ""))

        parts.append("")
        parts.append("### 日记类型")
        parts.append(diary_type)
        parts.append("")
        parts.append("### 日记标题")
        parts.append(diary_title)
        parts.append("")
        parts.append("### 日记内容")
        parts.append(diary_content)

        return "\n".join(parts)

    def publish_issue(self, title, body):
        """通过 GitHub Issues API 创建 Issue"""
        repo = self.config["github"]["repo"]
        token = self.config["github"]["token"]
        url = f"https://api.github.com/repos/{repo}/issues"

        try:
            resp = requests.post(
                url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github.v3+json",
                    "Content-Type": "application/json",
                },
                json={
                    "title": title,
                    "labels": ["diary"],
                    "body": body,
                },
                timeout=15,
            )
            if resp.status_code == 201:
                issue_url = resp.json().get("html_url", "")
                print(f"  [发布] Issue 创建成功")
                print(f"  [链接] {issue_url}")
                return True, issue_url
            else:
                error_msg = resp.json().get("message", resp.text[:200])
                print(f"  [发布] 失败 (HTTP {resp.status_code}): {error_msg}")
                return False, error_msg
        except Exception as e:
            print(f"  [发布] 请求异常: {e}")
            return False, str(e)

    # ==================== 本地保存 ====================

    def save_local(self, content, filename=None):
        """保存日记到本地 daily/ 目录"""
        if not filename:
            filename = self.now.strftime("%Y%m%d%H%M") + ".md"
        filepath = os.path.join(DAILY_DIR, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  [本地] 已保存: {filepath}")
        return filepath

    # ==================== 标题生成 ====================

    def generate_diary_title(self, news, memory_data):
        """根据内容生成简短日记标题"""
        if memory_data and memory_data["type"] == "summary":
            text = memory_data["content"].strip().split("\n")[0]
            return text[:30] + ("..." if len(text) > 30 else "")

        if news:
            title = news[0]["title"]
            # 去掉常见前缀
            for prefix in ["【", "〖", "["]:
                if title.startswith(prefix):
                    idx = title.find("】" if prefix == "【" else "〗" if prefix == "〖" else "]")
                    if idx > 0 and idx < 15:
                        title = title[idx + 1:].strip()
            return title[:30] + ("..." if len(title) > 30 else "")

        return f"AI科技日报 {self.now.strftime('%m-%d')}"

    # ==================== 周报/月报日记扫描 ====================

    def _scan_diaries(self, report_type):
        """扫描本地 daily/ 目录，按日期范围筛选日记文件"""
        files = glob.glob(os.path.join(DAILY_DIR, "*.md"))
        if not files:
            return []

        diaries = []
        for filepath in sorted(files):
            basename = os.path.basename(filepath)
            # 排除周报/月报文件
            if "_weekly" in basename or "_monthly" in basename:
                continue

            # 从文件名解析日期: YYYYMMDDHHMM.md
            name_no_ext = basename.replace(".md", "")
            if len(name_no_ext) < 8:
                continue
            date_str = name_no_ext[:8]
            try:
                file_date = datetime.strptime(date_str, "%Y%m%d")
            except ValueError:
                continue

            # 日期范围筛选
            if report_type == "weekly":
                monday = self.now - timedelta(days=self.now.weekday())
                monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
                today_end = self.now.replace(hour=23, minute=59, second=59, microsecond=999999)
                if file_date < monday or file_date > today_end:
                    continue
            elif report_type == "monthly":
                month_start = self.now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
                today_end = self.now.replace(hour=23, minute=59, second=59, microsecond=999999)
                if file_date < month_start or file_date > today_end:
                    continue

            with open(filepath, "r", encoding="utf-8") as fh:
                content = fh.read()
            diaries.append({
                "date": file_date,
                "filename": basename,
                "content": content,
            })

        return diaries

    # ==================== 主流程 ====================

    def run_daily(self, memory_summary=None, progress=None, harvest=None):
        """执行每日日记完整流程
        progress/harvest 由 AI Agent 自行总结后传入
        """
        print("=" * 50)
        print(f"  OpenClaw Diary - 每日日记")
        print(f"  时间: {self.now.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 50)

        # Step 1: 天气
        print("\n[1/5] 获取天气...")
        weather = self.get_weather()
        if weather:
            print(f"  → {weather['city']} {weather['weather']} {weather['temp']}°C 湿度{weather['humidity']}%")
        else:
            print("  → 获取失败，将填'无'")

        # Step 2: 新闻
        print("\n[2/5] 采集新闻...")
        news = self.get_news()
        if news:
            print(f"  → 共获取 {len(news)} 条新闻")
        else:
            print("  → 全部失败，将填'无'")

        # Step 3: Memory
        print("\n[3/5] 读取工作记忆...")
        # 如果 AI 没有传入 progress/harvest，尝试从 memory 目录提取素材
        # 供后续 AI 自行总结（打印到日志供 AI 参考）
        if self.memory_dir:
            print(f"  → 扫描路径: {self.memory_dir}")
        memory_data = self.get_memory(memory_summary)
        if memory_data:
            if memory_data["type"] == "summary":
                print("  → 使用 AI 传入的工作总结")
            else:
                print("  → 使用当日记录")
        else:
            print("  → 未找到当日记忆")

        # Step 4: 心情
        print("\n[4/5] 判定心情...")
        mood = self.determine_mood(memory_data, weather)
        print(f"  → 心情: {mood}")

        # Step 5: 生成 & 发布
        print("\n[5/5] 生成日记并发布...")
        diary_content = self.build_daily_content(weather, news, memory_data, mood, progress, harvest)
        diary_title = self.generate_diary_title(news, memory_data)

        is_first = not self.check_bot_registered()
        if is_first:
            print("  → 首次发布，将包含入驻信息")

        issue_title = f"[日记] {diary_title}"
        issue_body = self.build_issue_body("daily", diary_title, diary_content, is_first)

        # 本地保存
        local_path = self.save_local(diary_content)

        # 发布 Issue
        print("\n[发布] 正在创建 GitHub Issue...")
        success, result = self.publish_issue(issue_title, issue_body)

        print("\n" + "=" * 50)
        if success:
            print("  ✅ 每日日记发布成功")
            print(f"  📍 Issue: {result}")
            print(f"  💾 本地: {local_path}")
        else:
            print("  ⚠️ Issue 发布失败，日记已保存到本地")
            print(f"  💾 本地: {local_path}")
            print(f"  ❌ 原因: {result}")
        print("=" * 50)

        return success

    def run_weekly(self):
        """执行周报流程"""
        print("=" * 50)
        print(f"  OpenClaw Diary - 周报")
        print(f"  时间: {self.now.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 50)

        diaries = self._scan_diaries("weekly")
        if not diaries:
            print("\n[错误] 本周无日记数据，无法生成周报")
            print("  请确保本周已执行过至少一次 daily 命令")
            return False

        print(f"\n  → 找到 {len(diaries)} 篇日记")

        title_prefix, report_content = self.build_report_content("weekly", diaries)
        is_first = not self.check_bot_registered()

        issue_title = f"[周报] {title_prefix}"
        issue_body = self.build_issue_body("weekly", title_prefix, report_content, is_first)

        filename = self.now.strftime("%Y%m%d") + "_weekly.md"
        local_path = self.save_local(report_content, filename)

        print("\n[发布] 正在创建 GitHub Issue...")
        success, result = self.publish_issue(issue_title, issue_body)

        print("\n" + "=" * 50)
        if success:
            print("  ✅ 周报发布成功")
            print(f"  📍 Issue: {result}")
        else:
            print("  ⚠️ 周报发布失败，已保存到本地")
            print(f"  ❌ 原因: {result}")
        print("=" * 50)

        return success

    def run_monthly(self):
        """执行月报流程"""
        print("=" * 50)
        print(f"  OpenClaw Diary - 月报")
        print(f"  时间: {self.now.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 50)

        diaries = self._scan_diaries("monthly")
        if not diaries:
            print("\n[错误] 本月无日记数据，无法生成月报")
            print("  请确保本月已执行过至少一次 daily 命令")
            return False

        print(f"\n  → 找到 {len(diaries)} 篇日记")

        title_prefix, report_content = self.build_report_content("monthly", diaries)
        is_first = not self.check_bot_registered()

        issue_title = f"[月报] {title_prefix}"
        issue_body = self.build_issue_body("monthly", title_prefix, report_content, is_first)

        filename = self.now.strftime("%Y%m%d") + "_monthly.md"
        local_path = self.save_local(report_content, filename)

        print("\n[发布] 正在创建 GitHub Issue...")
        success, result = self.publish_issue(issue_title, issue_body)

        print("\n" + "=" * 50)
        if success:
            print("  ✅ 月报发布成功")
            print(f"  📍 Issue: {result}")
        else:
            print("  ⚠️ 月报发布失败，已保存到本地")
            print(f"  ❌ 原因: {result}")
        print("=" * 50)

        return success


def main():
    parser = argparse.ArgumentParser(
        description="OpenClaw Diary Skill - 智能日记发布技能"
    )
    subparsers = parser.add_subparsers(dest="command", help="子命令")

    # daily
    daily_p = subparsers.add_parser("daily", help="生成每日日记")
    daily_p.add_argument(
        "--memory-summary", type=str, default=None,
        help="AI总结的当日工作记忆文本（可选）"
    )
    daily_p.add_argument(
        "--progress", type=str, default=None,
        help="AI总结的工作/学习进展（可选，推荐由AI Agent自行总结后传入）"
    )
    daily_p.add_argument(
        "--harvest", type=str, default=None,
        help="AI总结的学习收获（可选，推荐由AI Agent自行总结后传入）"
    )

    # weekly
    subparsers.add_parser("weekly", help="生成本周周报")

    # monthly
    subparsers.add_parser("monthly", help="生成本月月报")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    skill = DiarySkill()

    if args.command == "daily":
        skill.run_daily(args.memory_summary, args.progress, args.harvest)
    elif args.command == "weekly":
        skill.run_weekly()
    elif args.command == "monthly":
        skill.run_monthly()


if __name__ == "__main__":
    main()