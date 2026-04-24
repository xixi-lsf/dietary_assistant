from datetime import datetime
from typing import Optional
from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from sqlalchemy.sql import func
from pydantic import BaseModel
from backend.database import Base
import json
import re

# 近义词归一化映射：变体 → 标准词
_TAG_SYNONYMS = {
    "微辣": "辣", "略辣": "辣", "有点辣": "辣", "偏辣": "辣", "重辣": "辣", "超辣": "辣",
    "口味淡": "清淡", "偏淡": "清淡", "淡": "清淡", "清爽": "清淡",
    "鲜美": "鲜", "鲜香": "鲜",
    "甜味": "甜", "偏甜": "甜",
    "咸味": "咸", "偏咸": "咸", "重咸": "咸",
    "油": "油腻", "偏油": "油腻", "很油": "油腻",
    "爽": "爽口", "清爽口": "爽口",
    "香味": "香", "浓香": "香",
    "嫩滑": "嫩", "软嫩": "嫩", "细嫩": "嫩",
    "酸味": "酸", "偏酸": "酸",
    "麻辣": "麻", "花椒味": "麻",
    "浓": "浓郁", "味浓": "浓郁", "口味重": "浓郁",
}

def _normalize_tag(tag: str) -> str:
    """将近义词归一化为标准标签"""
    tag = tag.strip()
    return _TAG_SYNONYMS.get(tag, tag)

def _split_tags(tags_str: str) -> list[str]:
    """将 AI 返回的标签字符串拆分为独立标签列表，兼容中英文逗号、顿号"""
    if not tags_str or not tags_str.strip():
        return []
    parts = re.split(r"[,，、\s]+", tags_str.strip())
    return [_normalize_tag(t) for t in parts if t.strip()]

# 所有数据结构

# SQLAlchemy ORM Models
#Column：定义数据库标中一个字段的构造器
#用户个人资料：姓名、忌口、偏好、目标、周期、身体数据等
class UserProfile(Base):
    __tablename__ = "user_profile"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, default="")
    dislikes = Column(Text, default="")
    preferences = Column(Text, default="")
    goal = Column(String, default="")
    cycle_days = Column(Integer, default=7)
    age = Column(Integer, default=0)
    gender = Column(String, default="")   # male / female
    height_cm = Column(Float, default=0)
    weight_kg = Column(Float, default=0)
    activity_level = Column(String, default="moderate")  # sedentary/light/moderate/active
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

#冰箱食材：名称、分类、数量、单位
class Ingredient(Base):
    __tablename__ = "ingredients"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(String, default="ingredient")  # ingredient | cookware | seasoning
    quantity = Column(Float, default=0)
    unit = Column(String, default="")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

#营养摄入日志：日期、餐次、菜品名、热量/蛋白/碳水/脂肪/纤维
class NutritionLog(Base):
    __tablename__ = "nutrition_log"
    id = Column(Integer, primary_key=True, index=True)
    date = Column(String, nullable=False)
    meal_type = Column(String, default="lunch")  # breakfast | lunch | dinner | snack
    recipe_name = Column(String, default="")
    calories = Column(Float, default=0)
    protein = Column(Float, default=0)
    carbs = Column(Float, default=0)
    fat = Column(Float, default=0)
    fiber = Column(Float, default=0)
    created_at = Column(DateTime, server_default=func.now())

#用户反馈：
class Feedback(Base):
    __tablename__ = "feedback"
    id = Column(Integer, primary_key=True, index=True)
    recipe_name = Column(String, nullable=False)
    score = Column(Integer, default=3)
    #用户手写的评论
    comment = Column(Text, default="")
    structured_tags = Column(Text, default="")
    # Level 1: "quick"，选择的预设标签 | Level 2: "deep"，填写的文本反馈
    #（隐式信号，比如浏览时长，是否收藏等，由前端行为统计，不入库）
    feedback_level = Column(String, default="quick")
    # 快速反馈原因，逗号分隔，如 "太辣,步骤复杂"
    #勾选的预标签
    quick_reason = Column(Text, default="")
    # "hardcoded" | "agent" — 记录推荐来源，用于 硬编码/agent 对比
    recommendation_mode = Column(String, default="hardcoded")
    created_at = Column(DateTime, server_default=func.now())

#收藏菜品：
class Favorite(Base):
    __tablename__ = "favorites"
    id = Column(Integer, primary_key=True, index=True)
    recipe_name = Column(String, nullable=False)
    recipe_data = Column(Text, default="")  # JSON string of full Recipe
    created_at = Column(DateTime, server_default=func.now())


class UserMemory(Base):
    """结构化长期记忆：口味权重、硬约束、健康目标、反馈历史摘要"""
    __tablename__ = "user_memory"
    id = Column(Integer, primary_key=True, index=True)
    # {"spicy": 0.8, "light": 0.6, "sweet": 0.2, ...}记录用户对各种口味标签的偏好程度
    taste_weights = Column(Text, default="{}")
    # ["香菜", "内脏"]用户完全不吃的食物
    hard_constraints = Column(Text, default="[]")
    # ["减脂", "控糖"]
    health_goals = Column(Text, default="[]")
    # 历史反馈[{"recipe": "...", "score": 4, "tags": "...", "date": "..."}]
    feedback_history = Column(Text, default="[]")
    # AI 生成的偏好摘要文字
    preference_summary = Column(Text, default="")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    def get_taste_weights(self) -> dict:
        return json.loads(self.taste_weights or "{}")

    def get_hard_constraints(self) -> list:
        return json.loads(self.hard_constraints or "[]")

    def get_health_goals(self) -> list:
        return json.loads(self.health_goals or "[]")

    def get_feedback_history(self) -> list:
        return json.loads(self.feedback_history or "[]")

    #指数移动平均（EMA）进行权重更新
    #参数：新收到的tag口味标签，用户评分，衰减因子（默认0.9）
    def update_taste_weights(self, new_tags: str, score: int, decay: float = 0.9):
        """根据反馈标签和评分更新口味权重，近期权重更高（衰减因子 decay）"""
        #获取当前口味权重
        weights = self.get_taste_weights()
        # 评分 1-5 映射到 [-1, +1] 的增量（eg.评分5，映射为1；评分1，映射为-1）
        delta = (score - 3) / 2.0
        #对每个标签独立更新（兼容中英文逗号、顿号，并归一化近义词）
        for tag in _split_tags(new_tags):
            #获取旧权重，不存在则默认0.5
            old = weights.get(tag, 0.5)
            # 衰减旧值，叠加新信号
            weights[tag] = round(old * decay + (0.5 + delta * 0.3) * (1 - decay), 3)
            weights[tag] = max(0.0, min(1.0, weights[tag]))
        self.taste_weights = json.dumps(weights, ensure_ascii=False)

    #将一次反馈记录追加到 feedback_history 列表中
    def append_feedback(self, recipe: str, score: int, tags: str, date: str):
        history = self.get_feedback_history()
        history.append({"recipe": recipe, "score": score, "tags": tags, "date": date})
        # 只保留最近 50 条
        self.feedback_history = json.dumps(history[-50:], ensure_ascii=False)


# Pydantic Schemas
class UserProfileSchema(BaseModel):
    name: str = ""
    dislikes: str = ""
    preferences: str = ""
    goal: str = ""
    cycle_days: int = 7
    age: int = 0
    gender: str = ""
    height_cm: float = 0
    weight_kg: float = 0
    activity_level: str = "moderate"

    class Config:
        from_attributes = True


class IngredientSchema(BaseModel):
    name: str
    category: str = "ingredient"
    quantity: float = 0
    unit: str = ""

    class Config:
        from_attributes = True


class NutritionLogSchema(BaseModel):
    date: str
    meal_type: str = "lunch"
    recipe_name: str = ""
    calories: float = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0
    fiber: float = 0

    class Config:
        from_attributes = True


class FeedbackSchema(BaseModel):
    recipe_name: str
    score: int = 3
    comment: str = ""
    structured_tags: str = ""
    feedback_level: str = "quick"
    quick_reason: str = ""
    recommendation_mode: str = "hardcoded"

    class Config:
        from_attributes = True


class RecipeDetailRequest(BaseModel):
    recipe_name: str
    steps: list[str]
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None


class BanquetRequest(BaseModel):
    people_count: int = 4
    occasion: str = "日常"
    preferences: str = ""
    dietary_restrictions: str = ""
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None


class DietAdviceRequest(BaseModel):
    date: str
    cycle_days: int = 7
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None


class MenuRequest(BaseModel):
    occasion: str = "日常"
    people_count: int = 2
    preferences: str = ""
    use_fridge: bool = True
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None
    image_api_key: Optional[str] = None
    image_base_url: Optional[str] = None
    model: str = "mock"
    feedback: str = ""
    nutrition_advice: str = ""


class FavoriteSchema(BaseModel):
    recipe_name: str
    recipe_data: str = ""

    class Config:
        from_attributes = True
