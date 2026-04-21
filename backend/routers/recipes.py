from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date, timedelta
from backend.database import get_db
from backend.models import MenuRequest, RecipeDetailRequest, BanquetRequest, UserProfile, Ingredient, NutritionLog, UserMemory
from backend.services import ai_service


#负责食谱相关的 AI 智能推荐、详细步骤生成（含图片）、宴席菜单推荐等功能

router = APIRouter(prefix="/recipes", tags=["recipes"])


#提供 MOCK_RECIPES 作为 API Key 缺失或调用失败时的降级方案
MOCK_RECIPES = [
    {
        "name": "番茄炒鸡蛋",
        "ingredients": ["番茄 2个", "鸡蛋 3个", "盐 适量", "糖 少许"],
        "steps": ["番茄切块，鸡蛋打散", "热锅下油，炒鸡蛋盛出", "再下油炒番茄，加盐糖", "倒入鸡蛋翻炒均匀"],
        "nutrition": {"calories": 220, "protein": 14, "carbs": 12, "fat": 12, "fiber": 2},
        "time_minutes": 15,
    },
    {
        "name": "清炒时蔬",
        "ingredients": ["青菜 300g", "蒜 3瓣", "盐 适量"],
        "steps": ["青菜洗净切段", "热锅下油爆香蒜末", "下青菜大火翻炒", "加盐调味出锅"],
        "nutrition": {"calories": 80, "protein": 3, "carbs": 8, "fat": 4, "fiber": 3},
        "time_minutes": 10,
    },
    {
        "name": "红烧豆腐",
        "ingredients": ["豆腐 400g", "生抽 2勺", "老抽 1勺", "糖 1勺", "葱姜蒜 适量"],
        "steps": ["豆腐切块煎至金黄", "爆香葱姜蒜", "加生抽老抽糖翻炒", "加水焖5分钟收汁"],
        "nutrition": {"calories": 180, "protein": 16, "carbs": 8, "fat": 9, "fiber": 1},
        "time_minutes": 20,
    },
]

#智能推荐菜谱
@router.post("/recommend")
def recommend_recipes(req: MenuRequest, db: Session = Depends(get_db)):
    print(f"[DEBUG] model={req.model} api_key={'***'+req.api_key[-4:] if req.api_key else None} ai_base_url={req.ai_base_url}")
    if req.model == "claude" and req.api_key:
        try:
            #获取冰箱食材、用户信息
            fridge_items = db.query(Ingredient).filter(Ingredient.category == "ingredient").all()
            fridge = [{"name": i.name, "quantity": i.quantity, "unit": i.unit} for i in fridge_items]
            profile = db.query(UserProfile).first()
            profile_dict = {}
            if profile:
                profile_dict = {
                    "dislikes": profile.dislikes,
                    "preferences": profile.preferences,
                    "goal": profile.goal,
                }

            # 获取长期记忆
            memory = db.query(UserMemory).first()
            long_term = None
            if memory:
                long_term = {
                    "taste_weights": memory.get_taste_weights(),
                    "hard_constraints": memory.get_hard_constraints(),
                    "health_goals": memory.get_health_goals(),
                    "preference_summary": memory.preference_summary or "",
                }

            # 短期记忆：周期内营养 + 今日餐次 + 近期推荐
            #获取短期记忆
            today = date.today().isoformat()
            cycle_days = profile.cycle_days if profile else 7
            start = (date.today() - timedelta(days=cycle_days - 1)).isoformat()
            logs = db.query(NutritionLog).filter(
                NutritionLog.date >= start,
                NutritionLog.date <= today,
            ).all()
            today_meals = [
                {"recipe_name": l.recipe_name, "meal_type": l.meal_type, "calories": l.calories}
                for l in logs if l.date == today
            ]
            cycle_logs = [l for l in logs]
            avg_cal = sum(l.calories for l in cycle_logs) / max(cycle_days, 1)
            avg_fat = sum(l.fat for l in cycle_logs) / max(cycle_days, 1)
            avg_protein = sum(l.protein for l in cycle_logs) / max(cycle_days, 1)
            recent_recipes = list({l.recipe_name for l in cycle_logs if l.recipe_name})

            
            short_term = {
                "cycle_nutrition": {
                    "avg_calories": avg_cal,
                    "fat_level": "偏高" if avg_fat > 60 else ("偏低" if avg_fat < 30 else "正常"),
                    "protein_level": "偏低" if avg_protein < 50 else ("充足" if avg_protein >= 60 else "正常"),
                },
                "today_meals": today_meals,
                "recent_recipes": recent_recipes,
            }

            #发送请求调用AI服务
            result = ai_service.recommend_recipes(
                api_key=req.api_key,
                occasion=req.occasion,
                people_count=req.people_count,
                preferences=req.preferences,
                fridge_items=fridge,
                user_profile=profile_dict,
                base_url=req.ai_base_url,
                feedback=req.feedback,
                nutrition_advice=req.nutrition_advice,
                long_term_memory=long_term,
                short_term_memory=short_term,
                model=req.ai_model,
            )
            if isinstance(result, list):
                result = ai_service.attach_recipe_preview_images(
                    result,
                    req.image_api_key,
                    req.image_base_url,
                )
                return {"recipes": result, "source": "claude"}
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
            return {**result, "source": "claude"}
        except Exception as e:
            print(f"[DEBUG] AI error: {type(e).__name__}: {e}")
            raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

    mock_recipes = ai_service.attach_recipe_preview_images(
        [dict(recipe) for recipe in MOCK_RECIPES],
        req.image_api_key,
        req.image_base_url,
    )
    return {"recipes": mock_recipes, "source": "mock"}

#获取模拟菜谱（无APIKEY）
@router.get("/mock")
def get_mock_recipes():
    return {"recipes": MOCK_RECIPES}

#生成菜谱详细步骤
#请求体RecipeDetailRequest中应该包含菜谱名称、文本APIKEY、图片生成APIKEY
#返回步骤列表
#每个步骤包含字段：step（原步骤）、process_description、result_description、process_image_prompt、result_image_prompt、以及可选的 process_image_url、result_image_url
@router.post("/detail")
def get_recipe_detail(req: RecipeDetailRequest):
    if not req.api_key:
        # 无 API key 时返回步骤文字，图片字段为 null
        return {"steps": [
            {"step": s, "result_description": "", "result_image_prompt": "",
             "process_description": "", "process_image_prompt": "",
             "result_image_url": None, "process_image_url": None}
            for s in req.steps
        ], "source": "mock"}
    try:
        steps = ai_service.generate_recipe_detail(
            api_key=req.api_key,
            recipe_name=req.recipe_name,
            steps=req.steps,
            base_url=req.ai_base_url,
            image_api_key=req.image_api_key,
            image_base_url=req.image_base_url,
            model=req.ai_model,
        )
        return {"steps": steps, "source": "claude"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")

#宴席菜单推荐
@router.post("/banquet")
def recommend_banquet(req: BanquetRequest):
    if not req.api_key:
        return {"recipes": MOCK_RECIPES, "source": "mock"}
    try:
        recipes = ai_service.recommend_banquet(
            api_key=req.api_key,
            people_count=req.people_count,
            occasion=req.occasion,
            preferences=req.preferences,
            dietary_restrictions=req.dietary_restrictions,
            base_url=req.ai_base_url,
            model=req.ai_model,
        )
        recipes = ai_service.attach_recipe_preview_images(
            recipes,
            image_api_key=req.image_api_key,
            image_base_url=req.image_base_url,
        )
        return {"recipes": recipes, "source": "claude"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 调用失败: {str(e)}")
