from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import date
import httpx
import json

from backend.database import get_db
from backend.models import UserProfile, Ingredient, NutritionLog
from backend.services.tool_service import TOOL_SCHEMAS, execute_tool
from backend.services import ai_service
from backend.services.ai_service import DEFAULT_AI_BASE_URL

#tools calling,使用claudeAPI的工具调用能力，让AI可以自助调用后端工具来完成对话和菜单推荐任务

router = APIRouter(prefix="/agent", tags=["agent"])

MAX_TOOL_ROUNDS = 6  # 防止无限循环


class AgentChatRequest(BaseModel):
    message: str
    history: List[dict] = []
    api_key: str
    ai_base_url: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None
    weather_api_key: Optional[str] = None
    serper_api_key: Optional[str] = None

#向 Claude API（兼容端点）发送请求（APIKEY,base_url,历史对话，系统提示词，重试次数）
async def _post_with_tools(api_key: str, base_url: str, messages: list, system: str, retries: int = 3) -> dict:
    import asyncio
    url = base_url.rstrip("/") + "/v1/messages"
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
    }

    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 2048,
        "system": system,
        "tools": TOOL_SCHEMAS,
        "messages": messages,
    }

    print(f"[Agent] payload messages count={len(messages)}, system len={len(system)}, tools count={len(TOOL_SCHEMAS)}")
    for i, m in enumerate(messages):
        content = m.get("content", "")
        content_preview = str(content)[:200] if content else "EMPTY"
        print(f"[Agent] msg[{i}] role={m.get('role')} content_type={type(content).__name__} preview={content_preview}")

    retry_backoff = [5, 15, 30]
    last_err = None
    for attempt in range(retries + 1):
        try:
            async with httpx.AsyncClient(timeout=120) as client:
                r = await client.post(url, headers=headers, json=payload)
            if r.status_code == 429 and attempt < retries:
                wait = retry_backoff[attempt] if attempt < len(retry_backoff) else 30
                print(f"[Agent] 429 限流，{wait}s 后重试 ({attempt+1}/{retries})")
                await asyncio.sleep(wait)
                continue
            if r.status_code >= 400:
                print(f"[Agent] API 错误 {r.status_code}: {r.text[:500]}")
            r.raise_for_status()
            return r.json()
        except (httpx.RemoteProtocolError, httpx.ConnectError, httpx.ReadError) as e:
            last_err = e
            if attempt < retries:
                await asyncio.sleep(2)
                continue
            raise
        except Exception:
            raise
    raise last_err

#动态构建system_prompt
#参数：数据库会话
def _build_system_prompt(db: Session) -> str:
    #获取用户个人资料、今日营养摄入日志、摄入总热量
    profile = db.query(UserProfile).first()
    today = date.today().isoformat()
    logs = db.query(NutritionLog).filter(NutritionLog.date == today).all()
    today_cal = sum(l.calories for l in logs)

    parts = [
        "你是用户的私人饮食管家 Agent，拥有工具调用能力。",
        "在回答前，主动使用工具获取用户的真实数据，而不是凭空猜测。",
        "推荐菜肴前必须先调用 get_user_memory 和 get_fridge_contents。",
        "对于不确定的问题可以使用search_web查询",
        "发现潜在冲突时调用 detect_conflict，推荐后调用 explain_recommendation 说明理由。",
        f"今日日期：{today}，今日已摄入：{today_cal:.0f} kcal。",
    ]
    if profile and profile.name:
        parts.append(f"用户姓名：{profile.name}")
    if profile and profile.goal:
        parts.append(f"健康目标：{profile.goal}")
    parts.append("回答要简洁、亲切，工具调用过程不需要向用户解释，直接给出结论。")
    #将所有片段用换行符连接成一个完整字符串
    return "\n".join(parts)

#端点1：管家对话
@router.post("/chat")
#参数：AgentChatRequest对象，数据库会话
async def agent_chat(req: AgentChatRequest, db: Session = Depends(get_db)):
    #构建系统提示词
    print(f"[Agent] chat: api_key={'***'+req.api_key[-4:] if req.api_key else 'EMPTY'} base_url={req.ai_base_url}")
    system_prompt = _build_system_prompt(db)
    #获取外部API KEY，打包成字典
    external_keys = {
        "weather_api_key": req.weather_api_key,
        "serper_api_key": req.serper_api_key,
    }

    #创建对话消息列表，将对话历史（req.history）转换成claudeAPI要求的messages格式
    messages = []
    #只保留 role 为 "user" 或 "assistant" 且 content 非空的消息
    #追加用户本次发送的消息作为最后一条user消息
    for h in req.history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": req.message})

    #记录每一轮调用的工具名称、输入参数和返回结果
    tool_calls_log = []

    #工具调用循环（最多六轮）
    for _round in range(MAX_TOOL_ROUNDS):
        try:
            #在这里用到了_post_with_tools，向claudeAPI发送请求，得到的回应是response，这个response是json格式
            #这里面就包含了tool需要的参数字段和其他（比如stop_reason）必要字段
            response = await _post_with_tools(
                api_key=req.api_key,
                base_url=req.ai_base_url or DEFAULT_AI_BASE_URL,
                messages=messages,
                system=system_prompt,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

        
        #stop_reason是claude响应终止原因
        #如果是end_turn说明模型完成了最终回答，没有更多工具调用需求
        #如果是tool_use说明模型还需要调用工具
        stop_reason = response.get("stop_reason")
        #相应内容块列表（可能是文本（type: "text"）或工具调用请求（type: "tool_use"））
        content_blocks = response.get("content", [])
        #将模型响应追加到message列表中
        messages.append({"role": "assistant", "content": content_blocks})

        #如果end_turn，遍历content_blocks提取type: "text" 的块，拼接成完整回复文本
        if stop_reason == "end_turn":
            text = ""
            for block in content_blocks:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += block.get("text", "")
            #返回前端的内容：
            return {
                "reply": text.strip(),#最终回复内容
                "tool_calls": tool_calls_log,#工具调用记录
                "rounds": _round + 1,#实际轮数
                "source": "agent",#标识这是 Agent 模式生成的回复
            }

        #如果还需要调用工具，遍历 content_blocks，找到所有 type: "tool_use" 的块
        if stop_reason == "tool_use":
            tool_results = []
            for block in content_blocks:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                tool_name = block["name"]
                #模型看到input_schema,生成参数json，提取到tool_input
                tool_input = block.get("input", {})
                tool_id = block["id"]
                #执行工具
                result = execute_tool(tool_name, tool_input, db, external_keys)
                tool_calls_log.append({"tool": tool_name, "input": tool_input, "result": result})
                #消息块，作为一条新的user消息加入messages
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
            messages.append({"role": "user", "content": tool_results})
            continue
        break

    raise HTTPException(status_code=500, detail="Agent 超过最大工具调用轮次，未能完成任务")


class AgentRecommendRequest(BaseModel):
    occasion: str = "日常"
    people_count: int = 2
    preferences: str = ""
    api_key: str
    ai_base_url: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None
    weather_api_key: Optional[str] = None
    serper_api_key: Optional[str] = None

#端点2：菜单推荐
@router.post("/recommend")
async def agent_recommend(req: AgentRecommendRequest, db: Session = Depends(get_db)):
    """Agent 模式菜单推荐：模型自主调用工具获取上下文，再生成推荐"""
    print(f"[Agent] recommend: api_key={'***'+req.api_key[-4:] if req.api_key else 'EMPTY'} base_url={req.ai_base_url}")
    external_keys = {
        "weather_api_key": req.weather_api_key,
        "serper_api_key": req.serper_api_key,
    }
    has_weather = bool(req.weather_api_key)
    has_search = bool(req.serper_api_key)

    system_prompt = f"""你是一位专业营养师 Agent，拥有工具调用能力。
推荐菜单前，你可以主动调用工具：
1. 调用 get_user_memory 了解用户偏好、禁忌和健康目标
2. 调用 get_fridge_contents 查看可用食材
3. 调用 get_nutrition_history 了解近期饮食状态
4. {"调用 get_weather 查询当地天气，根据气温和天气状况调整推荐（如寒冷推荐热汤，炎热推荐清淡）" if has_weather else "（天气工具未配置，跳过）"}
5. {"调用 search_web 搜索相关菜谱或饮食建议（可选，当需要更多灵感时）" if has_search else "（搜索工具未配置，跳过）"}
6. 调用 detect_conflict 检查用户请求是否与记忆冲突
7. 生成推荐后，为每道推荐菜调用 explain_recommendation 说明理由

推荐数量规则：
- 若用户明确点名某个食材、菜系或品类（如牛肉、三明治、鸡胸肉沙拉），推荐 2-3 道相关菜品，且至少给出 2 种不同做法
- 若用户没有明确指定，只推荐 3 道左右菜品，默认控制在 3-4 道内
- 主食根据场景灵活处理，通常 0-2 个即可，不要为了凑数给太多
- 若用户点名的本身就是主食/单品类需求（如三明治），可让 staples 为空

最终以 JSON 格式返回推荐结果，格式如下（不要其他文字）：
{{
  "dishes": [{{"name": "菜名", "ingredients": [...], "steps": [...], "nutrition": {{"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}}, "time_minutes": 0, "reason": "推荐理由"}}],
  "staples": [{{"name": "主食名", "ingredients": [...], "steps": [...], "nutrition": {{"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}}, "time_minutes": 0}}],
  "agent_notes": "本次推荐的整体说明，包括根据记忆、饮食状态、天气做了哪些调整"
}}"""

    user_message = f"场合：{req.occasion}，用餐人数：{req.people_count}人。{('特殊需求：' + req.preferences) if req.preferences else ''}请帮我推荐今天的菜单。"

    messages = [{"role": "user", "content": user_message}]
    tool_calls_log = []

    for _round in range(MAX_TOOL_ROUNDS):
        try:
            response = await _post_with_tools(
                api_key=req.api_key,
                base_url=req.ai_base_url or DEFAULT_AI_BASE_URL,
                messages=messages,
                system=system_prompt,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

        stop_reason = response.get("stop_reason")
        content_blocks = response.get("content", [])
        messages.append({"role": "assistant", "content": content_blocks})

        if stop_reason == "end_turn":
            text = ""
            for block in content_blocks:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += block.get("text", "")
            text = text.strip()
            # 从文字中提取 JSON 块（模型可能在 JSON 前后加说明文字）
            if "```" in text:
                parts = text.split("```")
                for part in parts:
                    if part.startswith("json"):
                        text = part[4:].strip()
                        break
                    if part.strip().startswith("{"):
                        text = part.strip()
                        break
            # 找到第一个 { 到最后一个 } 之间的内容
            start = text.find("{")
            end = text.rfind("}")
            if start != -1 and end != -1 and end > start:
                text = text[start:end+1]
            try:
                result = json.loads(text)
            except Exception:
                raise HTTPException(status_code=500, detail=f"Agent 返回格式错误：{text[:200]}")
            if isinstance(result, dict):
                if "dishes" in result:
                    result["dishes"] = ai_service.attach_recipe_preview_images(
                        result.get("dishes", []),
                        req.image_api_key,
                        req.image_base_url,
                    )
                if "staples" in result:
                    result["staples"] = ai_service.attach_recipe_preview_images(
                        result.get("staples", []),
                        req.image_api_key,
                        req.image_base_url,
                    )
            return {
                **result,
                "source": "agent",
                "tool_calls": tool_calls_log,
                "rounds": _round + 1,
            }

        if stop_reason == "tool_use":
            tool_results = []
            for block in content_blocks:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                tool_name = block["name"]
                tool_input = block.get("input", {})
                tool_id = block["id"]
                result = execute_tool(tool_name, tool_input, db, external_keys)
                tool_calls_log.append({"tool": tool_name, "input": tool_input, "result": result})
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
            messages.append({"role": "user", "content": tool_results})
            continue

        break

    raise HTTPException(status_code=500, detail="Agent 超过最大工具调用轮次")
