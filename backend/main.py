from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.database import init_db, get_db
from backend.routers import user, ingredients, recipes, nutrition, ai, favorites, memory, agent
from backend.services import rl_service
from sqlalchemy.orm import Session
from fastapi import Depends

app = FastAPI(title="私人饮食助理 API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    init_db()


app.include_router(user.router)
app.include_router(ingredients.router)
app.include_router(recipes.router)
app.include_router(nutrition.router)
app.include_router(ai.router)
app.include_router(favorites.router)
app.include_router(memory.router)
app.include_router(agent.router)


@app.get("/")
def root():
    return {"status": "ok", "message": "私人饮食助理后端运行中"}


@app.post("/rl/learn")
def trigger_offline_learning(db: Session = Depends(get_db)):
    """手动触发离线RL学习，返回更新摘要"""
    result = rl_service.run_offline_learning(db)
    return result


@app.get("/rl/policy")
def get_rl_policy(db: Session = Depends(get_db)):
    """查看当前所有策略表内容"""
    from backend.models import PromptStrategyPolicy
    policies = db.query(PromptStrategyPolicy).all()
    return [
        {
            "state_key": p.state_key,
            "best_strategy": p.get_strategy(),
            "avg_reward": p.avg_reward,
            "sample_count": p.sample_count,
        }
        for p in policies
    ]


@app.get("/rl/trajectories")
def get_trajectories(db: Session = Depends(get_db)):
    """查看最近20条轨迹记录"""
    from backend.models import RecommendationTrajectory
    trajs = db.query(RecommendationTrajectory).order_by(
        RecommendationTrajectory.created_at.desc()
    ).limit(20).all()
    return [
        {
            "id": t.id,
            "state_key": rl_service.build_state_key(t.get_state()),
            "strategy": t.get_strategy(),
            "recipes": t.get_recipes(),
            "reward": t.reward,
            "user_score": t.user_score,
            "created_at": t.created_at,
        }
        for t in trajs
    ]
