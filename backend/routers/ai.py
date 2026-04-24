from fastapi import APIRouter, Depends, UploadFile, File, Header, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy.orm import Session
from datetime import date, timedelta
from typing import List, Optional
from pydantic import BaseModel
from backend.database import get_db
from backend.models import FeedbackSchema, Feedback, DietAdviceRequest, UserProfile, NutritionLog, Ingredient, UserMemory
from backend.services import ai_service
import httpx

#FastAPI路由模块，实现了普通（非agent模式）的AI辅助功能
#所有端点都是单词请求-响应，没有多轮工具调用循环
#后端预先组装上下文，一次性调用 AI

router = APIRouter(prefix="/ai", tags=["ai"])


@router.get("/image-proxy")
async def image_proxy(url: str = Query(...)):
    """代理外部图片请求，解决 Flutter Web CORS 问题"""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.get(url)
            r.raise_for_status()
            return Response(content=r.content, media_type=r.headers.get("content-type", "image/png"))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"图片获取失败: {e}")

#上传一张冰箱/食材照片，让 AI 识别图片中的食材名称
@router.post("/identify-ingredients")
async def identify_ingredients(
    file: UploadFile = File(...),
    x_api_key: str = Header(default=None),
    x_ai_base_url: str = Header(default=None),
    x_ai_model: str = Header(default=None),
):
    if not x_api_key:
        return {"ingredients": ["番茄", "鸡蛋", "青椒"], "source": "mock"}

    try:
        image_bytes = await file.read()
        media_type = file.content_type or "image/jpeg"
        ingredients = ai_service.identify_ingredients(
            api_key=x_api_key,
            image_bytes=image_bytes,
            media_type=media_type,
            base_url=x_ai_base_url,
            model=x_ai_model,
        )
        return {"ingredients": ingredients, "source": "claude"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

#用户对菜品的反馈入库，并更新用户的长期记忆（UserMemory）
@router.post("/feedback")
def submit_feedback(data: FeedbackSchema, db: Session = Depends(get_db),
                    x_api_key: str = Header(default=None),
                    x_ai_base_url: str = Header(default=None),
                    x_ai_model: str = Header(default=None)):
    fb = Feedback(**data.model_dump())
    db.add(fb)
    db.commit()
    db.refresh(fb)

    # 提取口味标签，更新长期记忆
    if x_api_key:
        try:
            # 统一走 AI 提取：把所有评价信息（评分、预设标签、文字评论）喂给模型
            # 模型只提取口味特征词，评分决定权重方向（高分→权重上升，低分→权重下降）
            tags = ai_service.extract_feedback_tags(
                api_key=x_api_key,
                recipe_name=data.recipe_name,
                score=data.score,
                comment=data.comment or "",
                quick_reason=data.quick_reason or "",
                base_url=x_ai_base_url,
                model=x_ai_model,
            )

            if tags and tags.strip():
                memory = db.query(UserMemory).first()
                if not memory:
                    memory = UserMemory()
                    db.add(memory)
                memory.update_taste_weights(tags, data.score)
                memory.append_feedback(
                    recipe=data.recipe_name,
                    score=data.score,
                    tags=tags,
                    date=date.today().isoformat(),
                )
                db.commit()
        except Exception:
            pass  # 写回失败不影响反馈保存

    return fb

#返回所有反馈记录，按创建时间倒序
@router.get("/feedback")
def list_feedback(db: Session = Depends(get_db)):
    return db.query(Feedback).order_by(Feedback.created_at.desc()).all()


class InitMemoryRequest(BaseModel):
    preferences: str = ""
    dislikes: str = ""
    api_key: str = ""
    ai_base_url: str = ""
    ai_model: str = ""


#用户保存设置时调用，把口味偏好和忌口初始化为口味权重
#只设置尚未有记录的标签，不覆盖已有权重（保护运行中积累的数据）
@router.post("/init-memory-from-profile")
def init_memory_from_profile(req: InitMemoryRequest, db: Session = Depends(get_db)):
    if not req.api_key or (not req.preferences and not req.dislikes):
        return {"status": "skipped"}

    try:
        result = ai_service.initialize_memory_from_profile(
            api_key=req.api_key,
            preferences=req.preferences,
            dislikes=req.dislikes,
            base_url=req.ai_base_url or None,
            model=req.ai_model or None,
        )
    except Exception:
        return {"status": "error"}

    like_tags = result.get("like_tags", [])
    dislike_tags = result.get("dislike_tags", [])
    if not like_tags and not dislike_tags:
        return {"status": "no_tags"}

    memory = db.query(UserMemory).first()
    if not memory:
        memory = UserMemory()
        db.add(memory)

    weights = memory.get_taste_weights()
    # 只初始化尚未有记录的标签，不覆盖运行中积累的权重（归一化近义词）
    from backend.models import _normalize_tag
    for tag in like_tags:
        tag = _normalize_tag(tag)
        if tag not in weights:
            weights[tag] = 0.8
    for tag in dislike_tags:
        tag = _normalize_tag(tag)
        if tag not in weights:
            weights[tag] = 0.2

    memory.taste_weights = __import__("json").dumps(weights, ensure_ascii=False)
    db.commit()
    return {"status": "ok", "like_tags": like_tags, "dislike_tags": dislike_tags}

#基于用户近期的营养摄入记录，生成周期性的饮食总结和建议
@router.post("/diet-advice")
def get_diet_advice(req: DietAdviceRequest, db: Session = Depends(get_db)):
    if not req.api_key:
        return {"advice": "请在设置页填写 AI API Key 以获取个性化饮食建议。", "source": "mock"}

    profile = db.query(UserProfile).first()

    # 计算 BMR（Mifflin-St Jeor）
    bmr = 2000.0
    if profile and profile.weight_kg and profile.height_cm and profile.age:
        if profile.gender == "female":
            bmr = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age - 161
        else:
            bmr = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age + 5
        activity_multipliers = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55, "active": 1.725}
        bmr *= activity_multipliers.get(profile.activity_level or "moderate", 1.55)

    # 今日数据
    today_logs = db.query(NutritionLog).filter(NutritionLog.date == req.date).all()
    today_totals = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}
    for log in today_logs:
        for k in today_totals:
            today_totals[k] += getattr(log, k, 0)
    today_summary = {
        "date": req.date,
        "totals": today_totals,
        "meals": [{"meal_type": l.meal_type, "recipe_name": l.recipe_name, "calories": l.calories} for l in today_logs],
    }

    # 周期数据
    end = date.fromisoformat(req.date)
    start = end - timedelta(days=req.cycle_days - 1)
    logs = db.query(NutritionLog).filter(
        NutritionLog.date >= start.isoformat(),
        NutritionLog.date <= end.isoformat(),
    ).all()
    daily: dict[str, dict] = {}
    for log in logs:
        d = log.date
        if d not in daily:
            daily[d] = {"date": d, "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}
        for k in ["calories", "protein", "carbs", "fat", "fiber"]:
            daily[d][k] += getattr(log, k, 0)

    summary = list(daily.values())
    if not summary and not today_logs:
        return {"advice": "还没有饮食记录呢，快去记录今天吃了什么吧～", "source": "mock"}

    user_profile_dict = {}
    if profile:
        user_profile_dict = {
            "weight_kg": profile.weight_kg,
            "goal": profile.goal,
        }

    try:
        result = ai_service.generate_diet_advice(
            api_key=req.api_key,
            cycle_days=req.cycle_days,
            nutrition_summary=summary,
            today_summary=today_summary,
            bmr=bmr,
            user_profile=user_profile_dict,
            base_url=req.ai_base_url,
            model=req.ai_model,
        )
        return {**result, "source": "claude", "bmr": round(bmr)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")


class ChatRequest(BaseModel):
    message: str
    history: List[dict] = []
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None

#与agent区别：agent.py 实现了工具调用（tool use）的多轮 Agent 循环，模型可以自主调用工具（如查冰箱、查记忆等）
#ai.py 是传统的单次请求-响应模式，系统提前准备好上下文（查询数据库，组装提示词），然后一次性调用 AI，没有工具调用能力
@router.post("/chat")
def chat(req: ChatRequest, db: Session = Depends(get_db)):
    if not req.api_key:
        return {"reply": "请在设置页填写 AI API Key，我才能为您提供个性化服务。", "source": "mock"}

    profile = db.query(UserProfile).first()
    fridge = db.query(Ingredient).filter(Ingredient.category == "ingredient").all()
    today = date.today().isoformat()
    logs = db.query(NutritionLog).filter(NutritionLog.date == today).all()
    today_calories = sum(l.calories for l in logs)

    # 长期记忆
    memory = db.query(UserMemory).first()

    #构建系统提示词
    context_parts = ["你是用户的私人饮食管家，风格亲切、专业。"]
    if profile:
        if profile.name:
            context_parts.append(f"用户姓名：{profile.name}")
        if profile.goal:
            context_parts.append(f"健康目标：{profile.goal}")

    # 优先用结构化长期记忆
    if memory:
        constraints = memory.get_hard_constraints()
        weights = memory.get_taste_weights()
        goals = memory.get_health_goals()
        if constraints:
            context_parts.append(f"【绝对禁忌】：{'、'.join(constraints)}")
        if weights:
            strong = [k for k, v in weights.items() if v >= 0.7]
            if strong:
                context_parts.append(f"强烈偏好：{'、'.join(strong)}")
        if goals:
            context_parts.append(f"健康目标（记忆）：{'、'.join(goals)}")
        if memory.preference_summary:
            context_parts.append(f"偏好摘要：{memory.preference_summary}")
    elif profile:
        if profile.dislikes:
            context_parts.append(f"不喜欢：{profile.dislikes}")
        if profile.preferences:
            context_parts.append(f"饮食偏好：{profile.preferences}")

    # 短期记忆：今日饮食
    if fridge:
        fridge_str = "、".join(i.name for i in fridge[:10])
        context_parts.append(f"冰箱现有食材：{fridge_str}")
    context_parts.append(f"今日已摄入热量：{today_calories:.0f} kcal")
    if logs:
        meals_str = "、".join(f"{l.recipe_name}({l.meal_type})" for l in logs if l.recipe_name)
        if meals_str:
            context_parts.append(f"今日已吃：{meals_str}")
    context_parts.append("请根据用户问题给出简洁、实用的饮食建议，必要时可主动询问更多信息。")

    system_prompt = "\n".join(context_parts)

    #调用ai.service.chat传入系统提示、历史对话、当前消息，返回AI回复的文本
    try:
        reply = ai_service.chat(
            api_key=req.api_key,
            system_prompt=system_prompt,
            history=req.history,
            message=req.message,
            base_url=req.ai_base_url,
            model=req.ai_model,
        )
        return {"reply": reply, "source": "claude"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")
