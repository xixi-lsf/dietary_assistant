from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

#使用 SQLite

DATABASE_URL = "sqlite:///./dietary_assistant.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

#声明式基类，所有 ORM 模型继承它
class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

#调用 Base.metadata.create_all(bind=engine) 创建所有表
def init_db():
    from backend.models import UserProfile, Ingredient, NutritionLog, Feedback, Favorite, UserMemory
    Base.metadata.create_all(bind=engine)

    # 迁移：为已有表添加新列（SQLite 不支持 ALTER TABLE ADD COLUMN IF NOT EXISTS，逐一尝试）
    migrations = [
        "ALTER TABLE user_profile ADD COLUMN age INTEGER DEFAULT 0",
        "ALTER TABLE user_profile ADD COLUMN gender VARCHAR DEFAULT ''",
        "ALTER TABLE user_profile ADD COLUMN height_cm FLOAT DEFAULT 0",
        "ALTER TABLE user_profile ADD COLUMN weight_kg FLOAT DEFAULT 0",
        "ALTER TABLE user_profile ADD COLUMN activity_level VARCHAR DEFAULT 'moderate'",
        "ALTER TABLE feedback ADD COLUMN feedback_level VARCHAR DEFAULT 'quick'",
        "ALTER TABLE feedback ADD COLUMN quick_reason TEXT DEFAULT ''",
        "ALTER TABLE feedback ADD COLUMN recommendation_mode VARCHAR DEFAULT 'hardcoded'",
    ]
    with engine.connect() as conn:
        for sql in migrations:
            try:
                conn.execute(text(sql))
                conn.commit()
            except Exception:
                pass  # 列已存在则忽略
