from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import date, timedelta
import httpx
import json

from backend.database import get_db
from backend.models import UserProfile, Ingredient, NutritionLog, UserMemory
from backend.services.tool_service import TOOL_SCHEMAS, execute_tool
from backend.services import ai_service

#tools calling，使用 OpenAI 兼容格式的工具调用能力

router = APIRouter(prefix="/agent", tags=["agent"])

MAX_TOOL_ROUNDS = 6  # 防止无限循环


class AgentChatRequest(BaseModel):
    message: str
    history: List[dict] = []
    api_key: str
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None
    weather_api_key: Optional[str] = None
    serper_api_key: Optional[str] = None

#向 OpenAI 兼容端点发送请求（含工具调用）
#参数：apikey,url,历史对话message，系统提示，模型名，失败重试次数
async def _post_with_tools(api_key: str, base_url: str, messages: list, system: str, model: str = None, retries: int = 3) -> dict:
    """发送 OpenAI 兼容格式请求，返回统一的内部格式"""
    if not api_key or not base_url:
        raise ValueError("未配置 API Key 或 Base URL，请先在设置中配置")
    if not model:
        raise ValueError("未配置模型名称，请先在设置中配置")
    import asyncio
    url = base_url.rstrip("/")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    # 构建 messages：system 放首条
    all_messages = [{"role": "system", "content": system}]
    for m in messages:
        content = m.get("content", "")
        role = m.get("role", "user")

        if role == "assistant" and isinstance(content, list):
            # 内部 content_blocks → OpenAI assistant message
            text_parts = []
            tool_calls_out = []
            for block in content:
                if isinstance(block, dict):
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif block.get("type") == "tool_use":
                        tool_calls_out.append({
                            "id": block["id"],
                            "type": "function",
                            "function": {
                                "name": block["name"],
                                "arguments": json.dumps(block.get("input", {}), ensure_ascii=False),
                            },
                        })
            msg = {"role": "assistant", "content": "\n".join(text_parts) or None}
            if tool_calls_out:
                msg["tool_calls"] = tool_calls_out
            all_messages.append(msg)

        elif role == "user" and isinstance(content, list):
            # 内部 tool_result blocks → OpenAI tool messages
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    all_messages.append({
                        "role": "tool",
                        "tool_call_id": block["tool_use_id"],
                        "content": block.get("content", ""),
                    })
        else:
            all_messages.append({"role": role, "content": content})

    payload = {
        "model": model,
        "max_tokens": 2048,
        "tools": TOOL_SCHEMAS,
        "messages": all_messages,
    }

    print(f"[Agent] payload messages count={len(all_messages)}, system len={len(system)}, tools count={len(TOOL_SCHEMAS)}")

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
            data = r.json()

            # 将 OpenAI 响应转为内部统一格式
            choice = data["choices"][0]
            finish_reason = choice.get("finish_reason", "stop")
            message = choice.get("message", {})

            # 映射 stop_reason
            stop_reason = "tool_use" if finish_reason == "tool_calls" else "end_turn"

            # 构建内部 content_blocks
            content_blocks = []
            if message.get("content"):
                content_blocks.append({"type": "text", "text": message["content"]})
            if message.get("tool_calls"):
                for tc in message["tool_calls"]:
                    fn = tc.get("function", {})
                    args = fn.get("arguments", "{}")
                    try:
                        parsed_args = json.loads(args)
                    except json.JSONDecodeError:
                        parsed_args = {}
                    content_blocks.append({
                        "type": "tool_use",
                        "id": tc["id"],
                        "name": fn.get("name", ""),
                        "input": parsed_args,
                    })

            return {"stop_reason": stop_reason, "content": content_blocks}

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
    
    print(f"[Agent] chat: api_key={'***'+req.api_key[-4:] if req.api_key else 'EMPTY'} base_url={req.ai_base_url}")
    #构建系统提示词
    system_prompt = _build_system_prompt(db)
    #获取外部API KEY，打包成字典
    external_keys = {
        "weather_api_key": req.weather_api_key,
        "serper_api_key": req.serper_api_key,
    }

    #创建对话消息列表，将对话历史（req.history）转换成LLM API要求的messages格式
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
            #在这里用到了_post_with_tools，向API发送请求，得到的回应是response，这个response是json格式
            #这里面就包含了tool需要的参数字段和其他（比如stop_reason）必要字段
            response = await _post_with_tools(
                api_key=req.api_key,
                base_url=req.ai_base_url,
                messages=messages,
                system=system_prompt,
                model=req.ai_model,
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

        
        #stop_reason是claude响应终止原因
        #如果是end_turn说明模型完成了最终回答，没有更多工具调用需求
        #如果是tool_use说明模型还需要调用工具
        stop_reason = response.get("stop_reason")
        content_blocks = response.get("content", [])

        # 防止空 content 导致下游 API 报 "消息内容为空"
        if not content_blocks:
            print(f"[Agent] chat 警告：第 {_round+1} 轮返回空 content，stop_reason={stop_reason}")
            break

        messages.append({"role": "assistant", "content": content_blocks})

        if stop_reason == "end_turn":
            text = ""
            for block in content_blocks:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += block.get("text", "")
            return {
                "reply": text.strip(),
                "tool_calls": tool_calls_log,
                "rounds": _round + 1,
                "source": "agent",
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
            if not tool_results:
                print(f"[Agent] chat 警告：stop_reason=tool_use 但无 tool_use 块")
                break
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
    ai_model: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None
    weather_api_key: Optional[str] = None
    serper_api_key: Optional[str] = None


def _fallback_recommend(req, db: Session, tool_calls_log: list):
    """Agent 模式失败时降级到非 agent 单轮推荐"""
    print("[Agent] fallback 到非 agent 推荐模式")
    try:
        fridge_items = db.query(Ingredient).filter(Ingredient.category == "ingredient").all()
        fridge = [{"name": i.name, "quantity": i.quantity, "unit": i.unit} for i in fridge_items]

        profile = db.query(UserProfile).first()
        profile_dict = {}
        if profile:
            profile_dict = {"dislikes": profile.dislikes, "preferences": profile.preferences, "goal": profile.goal}

        memory = db.query(UserMemory).first()
        long_term = None
        if memory:
            long_term = {
                "taste_weights": memory.get_taste_weights(),
                "hard_constraints": memory.get_hard_constraints(),
                "health_goals": memory.get_health_goals(),
                "preference_summary": memory.preference_summary or "",
            }

        today = date.today().isoformat()
        cycle_days = profile.cycle_days if profile else 7
        start = (date.today() - timedelta(days=cycle_days - 1)).isoformat()
        logs = db.query(NutritionLog).filter(NutritionLog.date >= start, NutritionLog.date <= today).all()
        short_term = {
            "cycle_nutrition": {},
            "today_meals": [{"recipe_name": l.recipe_name, "meal_type": l.meal_type, "calories": l.calories} for l in logs if l.date == today],
            "recent_recipes": list({l.recipe_name for l in logs if l.recipe_name}),
        }

        result = ai_service.recommend_recipes(
            api_key=req.api_key,
            occasion=req.occasion,
            people_count=req.people_count,
            preferences=req.preferences,
            fridge_items=fridge,
            user_profile=profile_dict,
            base_url=req.ai_base_url,
            long_term_memory=long_term,
            short_term_memory=short_term,
            model=req.ai_model,
        )

        if isinstance(result, list):
            result = ai_service.attach_recipe_preview_images(result, req.image_api_key, req.image_base_url)
            return {"recipes": result, "source": "agent_fallback", "tool_calls": tool_calls_log}
        if isinstance(result, dict):
            if "dishes" in result:
                result["dishes"] = ai_service.attach_recipe_preview_images(result.get("dishes", []), req.image_api_key, req.image_base_url)
            if "staples" in result:
                result["staples"] = ai_service.attach_recipe_preview_images(result.get("staples", []), req.image_api_key, req.image_base_url)
        return {**result, "source": "agent_fallback", "tool_calls": tool_calls_log}
    except Exception as e:
        print(f"[Agent] fallback 也失败: {e}")
        raise HTTPException(status_code=500, detail=f"AI 调用失败（含降级）: {str(e)}")


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
                base_url=req.ai_base_url,
                messages=messages,
                system=system_prompt,
                model=req.ai_model,
            )
        except Exception as e:
            print(f"[Agent] recommend AI 调用失败: {e}，降级到非 agent 模式")
            return _fallback_recommend(req, db, tool_calls_log)

        stop_reason = response.get("stop_reason")
        content_blocks = response.get("content", [])

        # 防止空 content 导致下游 API 报 "消息内容为空"
        if not content_blocks:
            print(f"[Agent] 警告：第 {_round+1} 轮返回空 content，stop_reason={stop_reason}，降级到非 agent 模式")
            try:
                return _fallback_recommend(req, db, tool_calls_log)
            except Exception as fb_err:
                print(f"[Agent] fallback 调用异常: {fb_err}")
                raise

        messages.append({"role": "assistant", "content": content_blocks})

        if stop_reason == "end_turn":
            text = ""
            for block in content_blocks:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += block.get("text", "")
            text = text.strip()
            if "```" in text:
                parts = text.split("```")
                for part in parts:
                    if part.startswith("json"):
                        text = part[4:].strip()
                        break
                    if part.strip().startswith("{"):
                        text = part.strip()
                        break
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
            if not tool_results:
                print(f"[Agent] 警告：stop_reason=tool_use 但无 tool_use 块，降级到非 agent 模式")
                return _fallback_recommend(req, db, tool_calls_log)
            messages.append({"role": "user", "content": tool_results})
            continue

        break

    print("[Agent] 超过最大工具调用轮次或异常退出，降级到非 agent 模式")
    return _fallback_recommend(req, db, tool_calls_log)
