from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.database import init_db
from backend.routers import user, ingredients, recipes, nutrition, ai, favorites, memory, agent

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
