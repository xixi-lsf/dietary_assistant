import base64
import json
import time as _time

import httpx

DEFAULT_AI_BASE_URL = "https://codeapi.icu"

_MAX_RETRIES = 3
_RETRY_BACKOFF = [5, 15, 30]  # 每次重试等待秒数


def _post(api_key: str, base_url: str, payload: dict) -> dict:
    url = base_url.rstrip('/') + '/v1/messages'
    headers = {
        'x-api-key': api_key,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
    }
    for attempt in range(_MAX_RETRIES + 1):
        r = httpx.post(url, headers=headers, json=payload, timeout=120)
        if r.status_code == 429 and attempt < _MAX_RETRIES:
            wait = _RETRY_BACKOFF[attempt]
            print(f"[AI] 429 限流，{wait}s 后重试 ({attempt+1}/{_MAX_RETRIES})")
            _time.sleep(wait)
            continue
        r.raise_for_status()
        return r.json()


def recommend_recipes(
    api_key: str,
    occasion: str,
    people_count: int,
    preferences: str,
    fridge_items: list[dict],
    user_profile: dict,
    base_url: str = None,
    feedback: str = "",
    nutrition_advice: str = "",
    long_term_memory: dict = None,
    short_term_memory: dict = None,
) -> dict:
    fridge_str = ", ".join(i["name"] for i in fridge_items) if fridge_items else "未知"

    # 长期记忆：结构化偏好
    profile_parts = []
    if long_term_memory:
        taste_weights = long_term_memory.get("taste_weights", {})
        hard_constraints = long_term_memory.get("hard_constraints", [])
        health_goals = long_term_memory.get("health_goals", [])
        pref_summary = long_term_memory.get("preference_summary", "")

        if hard_constraints:
            profile_parts.append(f"【绝对禁忌，不得出现】：{'、'.join(hard_constraints)}")
        if taste_weights:
            strong = [k for k, v in taste_weights.items() if v >= 0.7]
            weak = [k for k, v in taste_weights.items() if v <= 0.3]
            if strong:
                profile_parts.append(f"强烈偏好：{'、'.join(strong)}")
            if weak:
                profile_parts.append(f"不太喜欢：{'、'.join(weak)}")
        if health_goals:
            profile_parts.append(f"健康目标：{'、'.join(health_goals)}")
        if pref_summary:
            profile_parts.append(f"偏好摘要：{pref_summary}")
    elif user_profile:
        if user_profile.get("dislikes"):
            profile_parts.append(f"不喜欢：{user_profile['dislikes']}")
        if user_profile.get("preferences"):
            profile_parts.append(f"偏好：{user_profile['preferences']}")
        if user_profile.get("goal"):
            profile_parts.append(f"健康目标：{user_profile['goal']}")

    profile_str = "；".join(profile_parts) or "无特殊要求"

    # 短期记忆：当前周期饮食状态
    short_term_parts = []
    if short_term_memory:
        cycle_nutrition = short_term_memory.get("cycle_nutrition", {})
        today_meals = short_term_memory.get("today_meals", [])
        recent_recipes = short_term_memory.get("recent_recipes", [])

        if today_meals:
            today_str = "、".join(f"{m['recipe_name']}({m['meal_type']})" for m in today_meals)
            short_term_parts.append(f"今日已吃：{today_str}")
        if cycle_nutrition.get("avg_calories"):
            short_term_parts.append(
                f"近期均摄入：{cycle_nutrition['avg_calories']:.0f}kcal/天，"
                f"脂肪{cycle_nutrition.get('fat_level','未知')}，蛋白质{cycle_nutrition.get('protein_level','未知')}"
            )
        if recent_recipes:
            short_term_parts.append(f"近期已推荐（避免重复）：{'、'.join(recent_recipes[-5:])}")

    short_term_str = "\n".join(short_term_parts)
    short_term_block = f"\n【近期饮食状态（短期记忆）】\n{short_term_str}" if short_term_str else ""

    feedback_str = f"\n用户反馈（请据此调整）：{feedback}" if feedback and feedback.strip() else ""
    advice_str = f"\n营养建议（请据此调整营养侧重）：{nutrition_advice}" if nutrition_advice and nutrition_advice.strip() else ""
    pref_str = f"\n【特殊需求，必须严格遵守】：{preferences}" if preferences and preferences.strip() else ""

    prompt = f"""你是一位专业营养师，请根据用户需求推荐菜肴和主食，让用户自由搭配。

场合：{occasion or '日常'}
用餐人数：{people_count}人
冰箱食材：{fridge_str}
【用户长期偏好（长期记忆）】
{profile_str}{pref_str}{short_term_block}{feedback_str}{advice_str}

请返回以下JSON格式（不要其他文字）：
{{
  "dishes": [
    {{
      "name": "菜名",
      "ingredients": ["食材1", "食材2"],
      "steps": ["步骤1", "步骤2"],
      "nutrition": {{"calories": 数字, "protein": 数字, "carbs": 数字, "fat": 数字, "fiber": 数字}},
      "time_minutes": 数字
    }}
  ],
  "staples": [
    {{
      "name": "主食名（如150g米饭、全麦馒头1个、玉米半根）",
      "ingredients": ["食材"],
      "steps": ["步骤"],
      "nutrition": {{"calories": 数字, "protein": 数字, "carbs": 数字, "fat": 数字, "fiber": 数字}},
      "time_minutes": 数字
    }}
  ]
}}

推荐策略（按优先级）：
1. 【用户需求优先】若用户有明确需求（如"想吃牛肉""想吃三明治""想吃辣的"），dishes 应以该需求为核心，推荐2-3道相关菜品，且至少提供2种不同做法/口味变化；staples 配合需求灵活调整（如三明治需求则 staples 可为空或推荐面包类）
2. 【长期记忆优先】严格遵守硬约束，强烈偏好的口味权重高，不喜欢的尽量回避
3. 【短期记忆调节】若今日已摄入高脂/高热量，推荐清淡菜品；避免与近期已推荐菜品重复
4. 【多样性】每次推荐的菜品要与常见菜品有所不同，避免总是番茄炒蛋、清炒时蔬等，多考虑冰箱食材
5. 【无特殊需求时】dishes 推荐3道左右，默认控制在3-4道内，荤素搭配；staples 推荐1-2种即可，不要堆太多选项
6. 若用户有热量限制，确保任意菜+主食组合不超过该限制
7. nutrition数据要准确，单位kcal/g"""

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 2048,
        "messages": [{"role": "user", "content": prompt}],
    })

    text = data["content"][0]["text"].strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text)


def generate_recipe_detail(
    api_key: str,
    recipe_name: str,
    steps: list[str],
    base_url: str = None,
    image_api_key: str = None,
    image_base_url: str = None,
) -> list[dict]:
    prompt = f"""你是一位专业厨师，请为菜肴「{recipe_name}」的每个烹饪步骤生成详细说明。

步骤列表：
{chr(10).join(f'{i+1}. {s}' for i, s in enumerate(steps))}

对每个步骤，请返回以下字段：

- step: 原始步骤文字（原样复制）

- result_description: 半成品描述（中文，2-3句话）。描述这一步完成后，食材/菜肴应该呈现的具体状态，帮助用户判断是否做对了。例如：醒面后面团应光滑有弹性、不粘手；切鱼后鱼片应厚薄均匀约0.5cm、边缘整齐。

- result_image_prompt: 半成品图片的英文prompt（30-50词）。要具体描述完成状态的视觉外观，包括颜色、形状、质地、摆放方式。例如切好的鱼片要描述"thinly sliced fish fillets, uniform 5mm thickness, arranged on white cutting board, glistening fresh surface, clean cuts"。

- process_description: 过程说明（中文）。仅当步骤涉及具体用量或关键手法时填写，例如"5g醋大约是瓷勺半勺"、"油温七成热时筷子插入会冒小泡"。无需展示时返回空字符串。

- process_image_prompt: 过程图片的英文prompt（30-50词）。仅当process_description非空时填写，要直观展示用量或操作，例如"half teaspoon of rice vinegar in small ceramic spoon, close-up shot, kitchen background"。无需展示时返回空字符串。

以JSON数组格式返回，只返回JSON，不要其他文字。"""

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 3000,
        "messages": [{"role": "user", "content": prompt}],
    })

    text = data["content"][0]["text"].strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    step_details = json.loads(text)

    if image_api_key:
        import concurrent.futures
        import time as _time

        # 先串行提交所有任务（避免429限流），收集task_id
        task_ids = []
        for step in step_details:
            rp = step.get("result_image_prompt", "")
            pp = step.get("process_image_prompt", "")
            print(f"[IMG-STEP] step={step.get('step','')[:30]} result_prompt={bool(rp)} process_prompt={bool(pp)}")
            r_task = _submit_image_task(image_api_key, rp) if rp else None
            _time.sleep(0.6)  # 避免超QPS
            p_task = _submit_image_task(image_api_key, pp) if pp else None
            if pp:
                _time.sleep(0.6)
            task_ids.append((step, r_task, p_task))

        # 并发轮询所有任务结果
        def _poll(args):
            step, r_task, p_task = args
            step["result_image_url"] = _poll_image_task(image_api_key, r_task) if r_task else None
            step["process_image_url"] = _poll_image_task(image_api_key, p_task) if p_task else None
            return step

        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            step_details = list(executor.map(_poll, task_ids))
    else:
        for step in step_details:
            step["result_image_url"] = None
            step["process_image_url"] = None

    return step_details


def recommend_banquet(
    api_key: str,
    people_count: int,
    occasion: str,
    preferences: str,
    dietary_restrictions: str,
    base_url: str = None,
) -> list[dict]:
    dish_count = people_count + 2

    prompt = f"""你是一位专业宴席设计师，请为以下场景设计一桌菜单：

用餐人数：{people_count}人
场合：{occasion}
口味偏好：{preferences or '无特殊要求'}
忌口：{dietary_restrictions or '无'}

要求：
1. 菜品数量固定为{dish_count}道（人数+2），荤素搭配合理
2. 根据场合氛围选择合适的菜品风格（如年夜饭选寓意好的菜，生日选喜庆菜，商务宴请选有档次的菜，普通聚餐选家常菜等，场合描述不在预设范围内时请灵活理解）
3. 搭配要有凉菜、热菜，可以有汤或主食
4. 每道菜提供营养数据

以JSON数组格式返回，每道菜包含：
- name, ingredients（字符串数组）, steps（字符串数组）
- nutrition: {{calories, protein, carbs, fat, fiber}}
- time_minutes, category（凉菜/热菜/汤/主食）

只返回JSON，不要其他文字。"""

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 3000,
        "messages": [{"role": "user", "content": prompt}],
    })

    text = data["content"][0]["text"].strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text)


def generate_diet_advice(
    api_key: str,
    cycle_days: int,
    nutrition_summary: list[dict],
    today_summary: dict,
    bmr: float,
    user_profile: dict,
    base_url: str = None,
) -> dict:
    summary_str = json.dumps(nutrition_summary, ensure_ascii=False)
    today_str = json.dumps(today_summary, ensure_ascii=False)

    # 推算宏量素目标（蛋白质1.6g/kg体重，脂肪25%热量，其余碳水）
    weight = user_profile.get("weight_kg", 0)
    protein_target = round(weight * 1.6) if weight > 0 else round(bmr * 0.15 / 4)
    fat_target = round(bmr * 0.25 / 9)
    carb_target = round((bmr - protein_target * 4 - fat_target * 9) / 4)

    today_meals = today_summary.get("meals", [])
    meal_count = len(today_meals)
    meal_types_recorded = list({m.get("meal_type", "") for m in today_meals})

    prompt = f"""你是用户的私人饮食管家，性格温柔可爱、专业贴心。请根据以下信息给出饮食建议。

【用户每日热量目标】{bmr:.0f} kcal（基于基础代谢计算）
【宏量素目标】蛋白质约{protein_target}g，脂肪约{fat_target}g，碳水约{carb_target}g，膳食纤维25g

【今日饮食记录】（已记录{meal_count}餐：{', '.join(meal_types_recorded) or '暂无'}）
{today_str}

【近{cycle_days}天饮食汇总】
{summary_str}

请分两部分回答：

**今日建议**（根据今日已记录的餐次，给出接下来的饮食建议。注意：用户可能只记录了部分餐次，不要因为记录少就说摄入不足，要根据已记录的内容给出合理建议）

**周期建议**（根据近{cycle_days}天整体趋势，分析营养素比例是否均衡，给出1-2条具体可操作的建议）

语气要温柔可爱，像朋友一样，避免使用"严重不足""严重超标"等打击性词汇。每部分不超过100字。"""

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 600,
        "messages": [{"role": "user", "content": prompt}],
    })

    return {"advice": data["content"][0]["text"].strip()}


def extract_feedback_tags(
    api_key: str,
    recipe_name: str,
    score: int,
    comment: str,
    base_url: str = None,
) -> str:
    prompt = f"""从以下用户对菜肴「{recipe_name}」的反馈中提取结构化偏好标签：

评分：{score}/5
评论：{comment or '无'}

请提取用户的口味偏好（如：偏咸、偏淡、喜欢辣、不喜欢某食材等），
以简短的中文标签形式返回，多个标签用逗号分隔，不超过30字。
只返回标签，不要其他文字。"""

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 100,
        "messages": [{"role": "user", "content": prompt}],
    })

    return data["content"][0]["text"].strip()


def _submit_image_task(image_api_key: str, prompt: str) -> str | None:
    """提交图片生成任务，返回 task_id"""
    headers = {
        "Authorization": f"Bearer {image_api_key}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
    }
    payload = {
        "model": "wanx2.1-t2i-turbo",
        "input": {"prompt": prompt},
        "parameters": {"size": "512*512", "n": 1},
    }
    print(f"[IMG] submitting prompt={prompt[:60]}")
    r = httpx.post("https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis",
                   headers=headers, json=payload, timeout=30)
    print(f"[IMG] submit status={r.status_code}, body={r.text[:200]}")
    if r.status_code != 200:
        return None
    return r.json().get("output", {}).get("task_id")


def _poll_image_task(image_api_key: str, task_id: str) -> str | None:
    """轮询任务结果，返回图片URL"""
    import time
    query_url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
    headers = {"Authorization": f"Bearer {image_api_key}"}
    for i in range(20):
        time.sleep(3)
        qr = httpx.get(query_url, headers=headers, timeout=15)
        qr.raise_for_status()
        output = qr.json().get("output", {})
        status = output.get("task_status", "")
        print(f"[IMG] poll {i+1} task={task_id[:8]}: status={status}")
        if status == "SUCCEEDED":
            results = output.get("results", [])
            url = results[0].get("url") if results else None
            print(f"[IMG] succeeded url={url}")
            return url
        if status in ("FAILED", "CANCELED"):
            print(f"[IMG] failed: {output}")
            return None
    print(f"[IMG] timeout task={task_id[:8]}")
    return None


def generate_image_qwen(
    image_api_key: str,
    prompt: str,
    image_base_url: str = None,
) -> str | None:
    """单张图片生成（提交+轮询）"""
    task_id = _submit_image_task(image_api_key, prompt)
    if not task_id:
        return None
    return _poll_image_task(image_api_key, task_id)


def _build_recipe_preview_prompt(recipe: dict) -> str:
    ingredients = ", ".join(recipe.get("ingredients", [])[:5])
    name = recipe.get("name", "dish")
    return (
        f"A plated serving of {name}, realistic food photography, appetizing homemade dish, "
        f"ingredients include {ingredients}, clean table setting, soft natural light, high detail"
    )


def attach_recipe_preview_images(
    recipes: list[dict],
    image_api_key: str | None,
    image_base_url: str = None,
) -> list[dict]:
    if not recipes:
        return recipes

    for recipe in recipes:
        recipe["preview_image_url"] = None

    if not image_api_key:
        return recipes

    import concurrent.futures
    import time as _time

    task_ids: list[tuple[dict, str | None]] = []
    for recipe in recipes:
        prompt = _build_recipe_preview_prompt(recipe)
        task_id = _submit_image_task(image_api_key, prompt)
        task_ids.append((recipe, task_id))
        _time.sleep(0.6)

    def _poll_preview(args: tuple[dict, str | None]) -> dict:
        recipe, task_id = args
        recipe["preview_image_url"] = (
            _poll_image_task(image_api_key, task_id) if task_id else None
        )
        return recipe

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        return list(executor.map(_poll_preview, task_ids))


def identify_ingredients(api_key: str, image_bytes: bytes, media_type: str = "image/jpeg", base_url: str = None) -> list[str]:
    image_data = base64.standard_b64encode(image_bytes).decode("utf-8")

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 512,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_data,
                        },
                    },
                    {
                        "type": "text",
                        "text": "请识别图片中的食材，以JSON字符串数组格式返回食材名称列表，只返回JSON，不要其他文字。例如：[\"番茄\", \"鸡蛋\"]",
                    },
                ],
            }
        ],
    })

    text = data["content"][0]["text"].strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text)


def chat(
    api_key: str,
    system_prompt: str,
    history: list[dict],
    message: str,
    base_url: str = None,
) -> str:
    messages = []
    for h in history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": message})

    data = _post(api_key, base_url or DEFAULT_AI_BASE_URL, {
        "model": "claude-sonnet-4-6",
        "max_tokens": 1024,
        "system": system_prompt,
        "messages": messages,
    })
    return data["content"][0]["text"].strip()
