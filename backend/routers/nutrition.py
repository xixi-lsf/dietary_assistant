from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend.database import get_db
from backend.models import NutritionLog, NutritionLogSchema

#提供对 NutritionLog 表的增、删、查操作，并支持按日期汇总营养数据

router = APIRouter(prefix="/nutrition", tags=["nutrition"])

#获取饮食记录列表，支持按日期筛选
@router.get("/")
def list_logs(date: str = None, db: Session = Depends(get_db)):
    q = db.query(NutritionLog)
    if date:
        q = q.filter(NutritionLog.date == date)
    return q.order_by(NutritionLog.date.desc()).all()

#添加一条新的营养记录
@router.post("/")
def add_log(data: NutritionLogSchema, db: Session = Depends(get_db)):
    log = NutritionLog(**data.model_dump())
    db.add(log)
    db.commit()
    db.refresh(log)
    return log

#删除一条营养记录
@router.delete("/{log_id}")
def delete_log(log_id: int, db: Session = Depends(get_db)):
    log = db.query(NutritionLog).filter(NutritionLog.id == log_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(log)
    db.commit()
    return {"ok": True}

#获取指定日期的营养汇总数据（各营养素总和 + 餐食详情）
@router.get("/summary")
def daily_summary(date: str, db: Session = Depends(get_db)):
    logs = db.query(NutritionLog).filter(NutritionLog.date == date).all()
    totals = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}
    for log in logs:
        for key in totals:
            totals[key] += getattr(log, key, 0)
    return {"date": date, "totals": totals, "meals": logs}
