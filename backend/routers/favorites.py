from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.models import Favorite, FavoriteSchema

#食谱收藏管理：提供对用户收藏的食谱进行增、删、查的 API。数据存储在 Favorite 表（在models中定义）中。

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.get("/")
def list_favorites(db: Session = Depends(get_db)):
    return db.query(Favorite).order_by(Favorite.created_at.desc()).all()

#添加一个收藏
@router.post("/")
def add_favorite(data: FavoriteSchema, db: Session = Depends(get_db)):
    existing = db.query(Favorite).filter(Favorite.recipe_name == data.recipe_name).first()
    if existing:
        return existing
    fav = Favorite(**data.model_dump())
    db.add(fav)
    db.commit()
    db.refresh(fav)
    return fav

#删除一个收藏
@router.delete("/{fav_id}")
def delete_favorite(fav_id: int, db: Session = Depends(get_db)):
    fav = db.query(Favorite).filter(Favorite.id == fav_id).first()
    if not fav:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(fav)
    db.commit()
    return {"ok": True}
