from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from backend.database import get_db
from backend.models import Ingredient, IngredientSchema

#冰箱食材管理：管理用户冰箱中的食材（增、删、改、查），并提供一个特殊的“扣减食材”接口，用于在生成菜谱后自动从冰箱中减少对应食材数量

router = APIRouter(prefix="/ingredients", tags=["ingredients"])

#列出所有食材
@router.get("/")
def list_ingredients(category: str = None, db: Session = Depends(get_db)):
    q = db.query(Ingredient)
    if category:
        q = q.filter(Ingredient.category == category)
    return q.all()

#添加食材
@router.post("/")
def add_ingredient(data: IngredientSchema, db: Session = Depends(get_db)):
    item = Ingredient(**data.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item

#更新食材信息（例如修改数量、类别等）
@router.put("/{item_id}")
def update_ingredient(item_id: int, data: IngredientSchema, db: Session = Depends(get_db)):
    item = db.query(Ingredient).filter(Ingredient.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Not found")
    for k, v in data.model_dump().items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item

#删除一种食材
@router.delete("/{item_id}")
def delete_ingredient(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Ingredient).filter(Ingredient.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(item)
    db.commit()
    return {"ok": True}

#扣减食材请求体
class DeductRequest(BaseModel):
    recipe_name: str
    ingredients: List[str]
    api_key: Optional[str] = None
    ai_base_url: Optional[str] = None

#根据菜谱所需的食材列表，尝试从冰箱中扣减对应食材的数量（每次扣减 1 个单位）
@router.post("/deduct")
def deduct_ingredients(req: DeductRequest, db: Session = Depends(get_db)):
    """根据菜谱食材列表，尝试从冰箱扣减对应食材数量（模糊匹配名称）"""
    deducted = []
    for ing_str in req.ingredients:
        # ing_str 格式如 "番茄 2个" 或 "鸡蛋 3个"，取第一个词作为名称
        name = ing_str.split()[0] if ing_str.strip() else ing_str
        item = db.query(Ingredient).filter(Ingredient.name.contains(name)).first()
        if item and item.quantity > 0:
            item.quantity = max(0, item.quantity - 1)
            deducted.append(item.name)
    db.commit()
    return {"deducted": deducted}
