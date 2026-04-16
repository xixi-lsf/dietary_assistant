"""
Tool definitions and execution logic for the dietary assistant agent.
"""
import json
import re
import httpx
from datetime import date, timedelta
from sqlalchemy.orm import Session
from backend.models import Ingredient, NutritionLog, UserProfile, UserMemory

#定义了agent可调用的工具集
# ---------------------------------------------------------------------------
# Tool schemas
# ---------------------------------------------------------------------------

TOOL_SCHEMAS = [
    {
        "name": "get_fridge_contents",
        "description": "获取冰箱中现有的食材列表。当需要根据现有食材推荐菜肴时调用。",
        "input_schema": {
            "type": "object",
            #定义了该 object 中可以包含哪些属性
            "properties": {
                "category": {"type": "string", "description": "分类过滤：ingredient/seasoning/cookware，不填返回所有"}
            },
            #必须存在的属性名称
            "required": [],
        },
    },
    {
        "name": "get_nutrition_history",
        "description": "查询用户最近 N 天的营养摄入记录。用于分析饮食趋势或判断今日摄入情况。",
        "input_schema": {
            "type": "object",
            "properties": {
                "days": {"type": "integer", "description": "查询最近几天，默认7，最多30"},
                "include_today": {"type": "boolean", "description": "是否包含今日，默认true"},
            },
            "required": [],
        },
    },
    {
        "name": "get_user_memory",
        "description": "读取用户长期记忆：口味偏好权重、硬约束（绝对不吃）、健康目标、偏好摘要。推荐前应先调用。",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "update_user_preference",
        "description": "更新用户长期记忆：新增/移除硬约束、设置健康目标、更新偏好摘要。",
        "input_schema": {
            "type": "object",
            "properties": {
                "add_hard_constraint": {"type": "string", "description": "新增禁忌食材"},
                "remove_hard_constraint": {"type": "string", "description": "移除禁忌食材"},
                "set_health_goals": {"type": "array", "items": {"type": "string"}, "description": "设置健康目标列表"},
                "set_preference_summary": {"type": "string", "description": "更新偏好文字摘要"},
            },
            "required": [],
        },
    },
    {
        "name": "log_meal",
        "description": "将一餐记录到营养日志。当用户告知已吃了某道菜时调用。",
        "input_schema": {
            "type": "object",
            "properties": {
                "recipe_name": {"type": "string", "description": "菜名"},
                "meal_type": {"type": "string", "description": "breakfast/lunch/dinner/snack"},
                "calories": {"type": "number", "description": "热量 kcal"},
                "protein": {"type": "number", "description": "蛋白质 g"},
                "carbs": {"type": "number", "description": "碳水 g"},
                "fat": {"type": "number", "description": "脂肪 g"},
                "fiber": {"type": "number", "description": "膳食纤维 g"},
            },
            "required": ["recipe_name", "meal_type", "calories"],
        },
    },
    {
        "name": "calculate_nutrition",
        "description": "根据食材和份量估算营养素。用户询问某道菜热量时调用。",
        "input_schema": {
            "type": "object",
            "properties": {
                "dish_name": {"type": "string", "description": "菜名"},
                "servings": {"type": "number", "description": "份数，默认1"},
                "ingredients": {"type": "array", "items": {"type": "string"}, "description": "食材列表如 [\"鸡胸肉200g\"]"},
            },
            "required": ["dish_name"],
        },
    },
    {
        "name": "explain_recommendation",
        "description": "解释为什么推荐某道菜，引用用户记忆和饮食状态作为依据。",
        "input_schema": {
            "type": "object",
            "properties": {
                "dish_name": {"type": "string", "description": "被推荐的菜名"},
                "reasons": {"type": "array", "items": {"type": "string"}, "description": "推荐理由列表"},
            },
            "required": ["dish_name", "reasons"],
        },
    },
    {
        "name": "detect_conflict",
        "description": "检测用户请求与长期记忆的冲突（口味冲突、营养目标冲突）。",
        "input_schema": {
            "type": "object",
            "properties": {
                "user_request": {"type": "string", "description": "用户的当前请求"},
                "check_taste": {"type": "boolean", "description": "是否检查口味冲突，默认true"},
                "check_nutrition": {"type": "boolean", "description": "是否检查营养目标冲突，默认true"},
            },
            "required": ["user_request"],
        },
    },
    {
        "name": "get_weather",
        "description": "获取指定城市的当前天气，包括温度、天气状况、湿度。用于根据天气推荐合适的饮食（如雨天推荐热汤、高温推荐清淡）。",
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "城市名，英文或中文均可，如 Beijing、上海"},
            },
            "required": ["city"],
        },
    },
    {
        "name": "search_web",
        "description": "搜索网页获取菜谱、食材营养、饮食知识等最新信息。当本地数据不足时调用，如搜索特定菜系做法、食材功效、流行饮食趋势。",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "搜索关键词，如：番茄炒蛋做法、减脂期适合吃什么"},
                "num_results": {"type": "integer", "description": "返回结果数量，默认3，最多5"},
            },
            "required": ["query"],
        },
    },
]

# ---------------------------------------------------------------------------
# Executors
# ---------------------------------------------------------------------------
#执行入口
#根据tool_name找到对应工具的函数，将tool_input等参数传给他，执行这个函数，返回最后的执行结果（字典）
#tool_input参数怎么来的？模型看到tool_schema，选定某个工具，看到他的input_schema，包含在响应的content字段中某个type:tool_use的块中返回
def execute_tool(tool_name: str, tool_input: dict, db: Session, external_keys: dict = None) -> dict:
    #映射表：工具名称 ->具体的 Python 函数
    executors = {
        "get_fridge_contents": _get_fridge_contents,
        "get_nutrition_history": _get_nutrition_history,
        "get_user_memory": _get_user_memory,
        "update_user_preference": _update_user_preference,
        "log_meal": _log_meal,
        "calculate_nutrition": _calculate_nutrition,
        "explain_recommendation": _explain_recommendation,
        "detect_conflict": _detect_conflict,
        "get_weather": _get_weather,
        "search_web": _search_web,
    }

    #找不到函数对象：
    #fn是根据工具名称找到的函数
    fn = executors.get(tool_name)
    if not fn:
        return {"error": f"未知工具：{tool_name}"}


    #区分外部工具和内部工具
    try:
        if tool_name in ("get_weather", "search_web"):
            return fn(tool_input, external_keys or {})
        return fn(tool_input, db)
    except Exception as e:
        return {"error": str(e)}


def _get_fridge_contents(inp: dict, db: Session) -> dict:
    category = inp.get("category")
    q = db.query(Ingredient)
    if category:
        q = q.filter(Ingredient.category == category)
    items = q.all()
    return {
        "items": [{"name": i.name, "quantity": i.quantity, "unit": i.unit, "category": i.category} for i in items],
        "count": len(items),
    }


def _get_nutrition_history(inp: dict, db: Session) -> dict:
    days = min(int(inp.get("days", 7)), 30)
    include_today = inp.get("include_today", True)
    today = date.today()
    end = today if include_today else today - timedelta(days=1)
    start = end - timedelta(days=days - 1)

    logs = db.query(NutritionLog).filter(
        NutritionLog.date >= start.isoformat(),
        NutritionLog.date <= end.isoformat(),
    ).all()

    daily: dict = {}
    for log in logs:
        d = log.date
        if d not in daily:
            daily[d] = {"date": d, "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0, "meals": []}
        for k in ["calories", "protein", "carbs", "fat", "fiber"]:
            daily[d][k] += getattr(log, k, 0)
        daily[d]["meals"].append({"meal_type": log.meal_type, "recipe_name": log.recipe_name, "calories": log.calories})

    summary = sorted(daily.values(), key=lambda x: x["date"])
    if not summary:
        return {"days": [], "summary": "暂无记录"}
    avg_cal = sum(d["calories"] for d in summary) / len(summary)
    return {"days": summary, "avg_calories_per_day": round(avg_cal, 1), "total_days_recorded": len(summary)}


def _get_user_memory(inp: dict, db: Session) -> dict:
    memory = db.query(UserMemory).first()
    profile = db.query(UserProfile).first()
    base = {
        "taste_weights": {},
        "hard_constraints": [],
        "health_goals": [],
        "preference_summary": "",
        "feedback_count": 0,
        "profile": _profile_dict(profile),
    }
    if not memory:
        return base
    return {
        "taste_weights": memory.get_taste_weights(),
        "hard_constraints": memory.get_hard_constraints(),
        "health_goals": memory.get_health_goals(),
        "preference_summary": memory.preference_summary or "",
        "feedback_count": len(memory.get_feedback_history()),
        "profile": _profile_dict(profile),
    }


def _profile_dict(profile) -> dict:
    if not profile:
        return {}
    return {
        "name": profile.name, "goal": profile.goal, "dislikes": profile.dislikes,
        "weight_kg": profile.weight_kg, "age": profile.age,
        "gender": profile.gender, "activity_level": profile.activity_level,
    }


def _update_user_preference(inp: dict, db: Session) -> dict:
    memory = db.query(UserMemory).first()
    if not memory:
        memory = UserMemory()
        db.add(memory)

    changed = []

    if inp.get("add_hard_constraint"):
        constraints = memory.get_hard_constraints()
        item = inp["add_hard_constraint"]
        if item not in constraints:
            constraints.append(item)
            memory.hard_constraints = json.dumps(constraints, ensure_ascii=False)
            changed.append(f"新增硬约束：{item}")

    if inp.get("remove_hard_constraint"):
        constraints = memory.get_hard_constraints()
        item = inp["remove_hard_constraint"]
        if item in constraints:
            constraints.remove(item)
            memory.hard_constraints = json.dumps(constraints, ensure_ascii=False)
            changed.append(f"移除硬约束：{item}")

    if inp.get("set_health_goals") is not None:
        memory.health_goals = json.dumps(inp["set_health_goals"], ensure_ascii=False)
        changed.append(f"更新健康目标：{inp['set_health_goals']}")

    if inp.get("set_preference_summary"):
        memory.preference_summary = inp["set_preference_summary"]
        changed.append("更新偏好摘要")

    db.commit()
    return {"success": True, "changes": changed}


def _log_meal(inp: dict, db: Session) -> dict:
    log = NutritionLog(
        date=date.today().isoformat(),
        meal_type=inp.get("meal_type", "lunch"),
        recipe_name=inp["recipe_name"],
        calories=inp.get("calories", 0),
        protein=inp.get("protein", 0),
        carbs=inp.get("carbs", 0),
        fat=inp.get("fat", 0),
        fiber=inp.get("fiber", 0),
    )
    db.add(log)
    db.commit()
    return {"success": True, "logged": inp["recipe_name"], "calories": inp.get("calories", 0)}


NUTRITION_DB = {
    "鸡胸肉": {"cal": 165, "protein": 31, "fat": 3.6, "carbs": 0},
    "猪肉": {"cal": 250, "protein": 17, "fat": 20, "carbs": 0},
    "牛肉": {"cal": 200, "protein": 26, "fat": 10, "carbs": 0},
    "鸡蛋": {"cal": 155, "protein": 13, "fat": 11, "carbs": 1},
    "豆腐": {"cal": 80, "protein": 8, "fat": 4, "carbs": 2},
    "米饭": {"cal": 130, "protein": 2.7, "fat": 0.3, "carbs": 28},
    "面条": {"cal": 138, "protein": 5, "fat": 0.6, "carbs": 28},
    "西兰花": {"cal": 34, "protein": 2.8, "fat": 0.4, "carbs": 7},
    "番茄": {"cal": 18, "protein": 0.9, "fat": 0.2, "carbs": 3.9},
    "土豆": {"cal": 77, "protein": 2, "fat": 0.1, "carbs": 17},
}


def _calculate_nutrition(inp: dict, db: Session) -> dict:
    servings = float(inp.get("servings", 1))
    ingredients = inp.get("ingredients", [])
    total = {"calories": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0, "fiber": 2.0}

    for item in ingredients:
        for food, vals in NUTRITION_DB.items():
            if food in item:
                m = re.search(r"(\d+)", item)
                grams = int(m.group(1)) if m else 100
                factor = grams / 100 * servings
                total["calories"] += vals["cal"] * factor
                total["protein"] += vals["protein"] * factor
                total["fat"] += vals["fat"] * factor
                total["carbs"] += vals["carbs"] * factor
                break

    if total["calories"] == 0:
        total = {"calories": 300 * servings, "protein": 15 * servings,
                 "fat": 12 * servings, "carbs": 30 * servings, "fiber": 3 * servings}
        return {**{k: round(v, 1) for k, v in total.items()},
                "dish": inp["dish_name"], "note": "基于菜名粗估，建议提供食材列表"}

    return {**{k: round(v, 1) for k, v in total.items()}, "dish": inp["dish_name"]}


def _explain_recommendation(inp: dict, db: Session) -> dict:
    dish = inp["dish_name"]
    reasons = inp.get("reasons", [])
    return {
        "dish": dish,
        "explanation": f"推荐「{dish}」的原因：" + "；".join(reasons),
        "reasons": reasons,
    }


def _detect_conflict(inp: dict, db: Session) -> dict:
    user_request = inp["user_request"]
    check_taste = inp.get("check_taste", True)
    check_nutrition = inp.get("check_nutrition", True)

    memory = db.query(UserMemory).first()
    conflicts = []
    suggestions = []

    if memory and check_taste:
        weights = memory.get_taste_weights()
        constraints = memory.get_hard_constraints()

        for item in constraints:
            if item in user_request:
                conflicts.append(f"请求包含硬约束食材「{item}」")
                suggestions.append(f"询问用户是否确认要包含「{item}」")

        taste_keywords = {"辣": "spicy", "甜": "sweet", "咸": "salty", "油腻": "greasy", "清淡": "light"}
        for kw, tag in taste_keywords.items():
            if kw in user_request:
                w = weights.get(tag, weights.get(kw, 0.5))
                if w < 0.35:
                    conflicts.append(f"请求「{kw}」但历史偏好权重较低（{w:.2f}）")
                    suggestions.append(f"告知用户历史记录显示不太喜欢{kw}，询问是否确认")

    if memory and check_nutrition:
        goals = memory.get_health_goals()
        high_cal_keywords = ["炸", "红烧", "糖醋", "奶油", "肥"]
        if any(g in ("减脂", "控热量") for g in goals):
            for kw in high_cal_keywords:
                if kw in user_request:
                    conflicts.append(f"「{kw}」类食物与健康目标「{'、'.join(goals)}」冲突")
                    suggestions.append("推荐低脂替代做法，或告知热量让用户自行决定")
                    break

    return {
        "has_conflict": len(conflicts) > 0,
        "conflicts": conflicts,
        "suggestions": suggestions,
        "user_request": user_request,
    }


def _get_weather(inp: dict, keys: dict) -> dict:
    api_key = keys.get("weather_api_key")
    if not api_key:
        return {"error": "未配置 OpenWeatherMap API Key，跳过天气查询"}

    city = inp.get("city", "Beijing")
    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"q": city, "appid": api_key, "units": "metric", "lang": "zh_cn"}

    r = httpx.get(url, params=params, timeout=10)
    if r.status_code != 200:
        return {"error": f"天气查询失败：{r.status_code} {r.text[:100]}"}

    data = r.json()
    weather = data.get("weather", [{}])[0]
    main = data.get("main", {})
    temp = main.get("temp", 0)
    feels_like = main.get("feels_like", 0)
    humidity = main.get("humidity", 0)
    description = weather.get("description", "")

    # 生成饮食建议提示
    diet_hint = ""
    if temp < 10:
        diet_hint = "天气寒冷，适合热汤、火锅、炖菜等暖身食物"
    elif temp < 20:
        diet_hint = "天气凉爽，荤素搭配均可"
    elif temp < 30:
        diet_hint = "天气温暖，可适当清淡"
    else:
        diet_hint = "天气炎热，推荐清淡、凉拌、低油食物，多补水"

    if humidity > 80:
        diet_hint += "；湿度较高，可加入祛湿食材如薏米、红豆"

    return {
        "city": city,
        "temperature": round(temp, 1),
        "feels_like": round(feels_like, 1),
        "humidity": humidity,
        "description": description,
        "diet_hint": diet_hint,
    }

#参数：搜索关键词+返回搜索结果数量，APIKEY
def _search_web(inp: dict, keys: dict) -> dict:
    api_key = keys.get("serper_api_key")
    if not api_key:
        return {"error": "未配置 Serper API Key，跳过网页搜索"}

    query = inp.get("query", "")
    num = min(int(inp.get("num_results", 3)), 5)

    #发起http请求
    r = httpx.post(
        "https://google.serper.dev/search",
        headers={"X-API-KEY": api_key, "Content-Type": "application/json"},
        json={"q": query, "num": num, "hl": "zh-cn", "gl": "cn"},
        timeout=15,
    )
    if r.status_code != 200:
        return {"error": f"搜索失败：{r.status_code} {r.text[:100]}"}

    data = r.json()
    results = []
    for item in data.get("organic", [])[:num]:
        results.append({
            "title": item.get("title", ""),
            "snippet": item.get("snippet", ""),
            "link": item.get("link", ""),
        })

    return {"query": query, "results": results, "count": len(results)}
