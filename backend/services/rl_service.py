"""
离线RL服务：奖励函数 + 轨迹记录 + 离线策略学习

核心思路：
  - 每次推荐前：查策略表，决定给 Claude 注入什么 prompt 参数
  - 每次反馈后：计算奖励，补全轨迹记录
  - 每攒够 LEARN_THRESHOLD 条完整轨迹：触发一次离线学习，更新策略表
"""

import json
from datetime import date
from sqlalchemy.orm import Session
from backend.models import (
    RecommendationTrajectory,
    PromptStrategyPolicy,
    NutritionLog,
    UserMemory,
)

# 触发离线学习的轨迹条数阈值（首次20条，之后每10条）
LEARN_THRESHOLD_INIT = 20
LEARN_THRESHOLD_INCR = 10


# ── 1. 奖励函数 ────────────────────────────────────────────────

def compute_reward(
    user_score: int,
    recommended_recipes: list[str],
    recent_recipes: list[str],
    nutrition_state: dict,
    hard_constraints: list[str],
    recipe_tags: str = "",
) -> float:
    """
    多维度奖励函数，返回标量奖励 [-1.0, 1.0]

    维度：
      1. 用户满意度（主信号，权重0.5）
      2. 多样性奖励（近7天未出现，权重0.2）
      3. 营养达标奖励（权重0.2）
      4. 硬约束惩罚（权重0.1，违反则大幅扣分）
    """
    reward = 0.0

    # 1. 用户满意度：评分1-5 → [-0.5, +0.5]
    satisfaction = (user_score - 3) / 2.0 * 0.5
    reward += satisfaction

    # 2. 多样性奖励：推荐的菜在近7天没出现过
    recent_set = set(recent_recipes[-7:]) if recent_recipes else set()
    new_count = sum(1 for r in recommended_recipes if r not in recent_set)
    diversity_ratio = new_count / max(len(recommended_recipes), 1)
    reward += diversity_ratio * 0.2

    # 3. 营养达标奖励
    nutrition_bonus = 0.0
    protein_level = nutrition_state.get("protein_level", "正常")
    fat_level = nutrition_state.get("fat_level", "正常")
    tags_list = [t.strip() for t in recipe_tags.replace("，", ",").split(",") if t.strip()]

    if protein_level == "偏低" and any(t in ["高蛋白", "蛋白质", "肉", "鱼", "蛋", "豆"] for t in tags_list):
        nutrition_bonus += 0.1
    if fat_level == "偏高" and any(t in ["清淡", "低油", "蒸", "煮"] for t in tags_list):
        nutrition_bonus += 0.1
    reward += min(nutrition_bonus, 0.2)

    # 4. 硬约束惩罚：如果推荐菜名包含禁忌食材，扣分
    if hard_constraints:
        for recipe in recommended_recipes:
            for constraint in hard_constraints:
                if constraint and constraint in recipe:
                    reward -= 0.3
                    break

    return round(max(-1.0, min(1.0, reward)), 4)


# ── 2. 状态快照 ────────────────────────────────────────────────

def build_state_snapshot(
    memory: UserMemory | None,
    recent_recipes: list[str],
    nutrition_state: dict,
    meal_type: str = "lunch",
) -> dict:
    """构建当前状态快照，存入轨迹"""
    taste_weights = memory.get_taste_weights() if memory else {}
    hard_constraints = memory.get_hard_constraints() if memory else []
    health_goals = memory.get_health_goals() if memory else []

    # 找出最强偏好标签（权重最高的前3个）
    top_tastes = sorted(taste_weights.items(), key=lambda x: x[1], reverse=True)[:3]

    return {
        "taste_weights": taste_weights,
        "top_tastes": [t[0] for t in top_tastes],
        "hard_constraints": hard_constraints,
        "health_goals": health_goals,
        "nutrition_state": nutrition_state,
        "recent_recipes": recent_recipes[-7:],
        "meal_type": meal_type,
        "date": date.today().isoformat(),
    }


def build_state_key(state: dict) -> str:
    """
    把状态压缩成一个字符串键，用于策略表查找
    格式："{protein_level}_{fat_level}_{top_taste}"
    """
    nutrition = state.get("nutrition_state", {})
    protein = nutrition.get("protein_level", "正常")
    fat = nutrition.get("fat_level", "正常")
    top_tastes = state.get("top_tastes", [])
    top_taste = top_tastes[0] if top_tastes else "无"
    return f"{protein}_{fat}_{top_taste}"


# ── 3. 策略查询 ────────────────────────────────────────────────

# 默认策略：没有历史数据时使用
_DEFAULT_STRATEGY = {
    "emphasis": "",          # 注入prompt的强调文字，如"请优先推荐高蛋白菜肴"
    "diversity_boost": False, # 是否在prompt中强调多样性
    "nutrition_focus": "",   # 营养侧重，如"protein"/"low_fat"
}


def get_prompt_strategy(db: Session, state: dict) -> dict:
    """
    查策略表，返回当前状态下最优的prompt策略。
    没有记录时返回默认策略（由营养状态推断）。
    """
    state_key = build_state_key(state)
    policy = db.query(PromptStrategyPolicy).filter(
        PromptStrategyPolicy.state_key == state_key
    ).first()

    if policy and policy.sample_count >= 3:
        # 有足够样本的学习结果，直接用
        return policy.get_strategy()

    # 冷启动：根据当前营养状态推断默认策略
    return _infer_default_strategy(state)


def _infer_default_strategy(state: dict) -> dict:
    """冷启动时根据状态规则推断策略"""
    nutrition = state.get("nutrition_state", {})
    protein_level = nutrition.get("protein_level", "正常")
    fat_level = nutrition.get("fat_level", "正常")
    top_tastes = state.get("top_tastes", [])

    emphasis_parts = []
    nutrition_focus = ""

    if protein_level == "偏低":
        emphasis_parts.append("请优先推荐富含蛋白质的菜肴（如鱼、肉、蛋、豆制品）")
        nutrition_focus = "protein"
    if fat_level == "偏高":
        emphasis_parts.append("请避免油炸和高脂肪菜肴，优先清淡烹饪方式")
        nutrition_focus = nutrition_focus or "low_fat"
    if top_tastes:
        emphasis_parts.append(f"用户偏好口味：{'、'.join(top_tastes[:2])}")

    return {
        "emphasis": "；".join(emphasis_parts),
        "diversity_boost": len(state.get("recent_recipes", [])) >= 5,
        "nutrition_focus": nutrition_focus,
    }


# ── 4. 轨迹记录 ────────────────────────────────────────────────

def record_trajectory(
    db: Session,
    state: dict,
    strategy: dict,
    recommended_recipes: list[str],
) -> int:
    """推荐完成后记录轨迹，返回轨迹ID（反馈时用来补充奖励）"""
    traj = RecommendationTrajectory(
        state_snapshot=json.dumps(state, ensure_ascii=False),
        prompt_strategy=json.dumps(strategy, ensure_ascii=False),
        recommended_recipes=json.dumps(recommended_recipes, ensure_ascii=False),
        reward=None,
        user_score=None,
    )
    db.add(traj)
    db.commit()
    db.refresh(traj)
    return traj.id


def fill_trajectory_reward(
    db: Session,
    trajectory_id: int,
    user_score: int,
    recipe_tags: str,
) -> float | None:
    """
    反馈回来后，补全轨迹的奖励值。
    返回计算出的奖励，找不到轨迹则返回 None。
    """
    traj = db.query(RecommendationTrajectory).filter(
        RecommendationTrajectory.id == trajectory_id
    ).first()
    if not traj:
        return None

    state = traj.get_state()
    recipes = traj.get_recipes()
    nutrition_state = state.get("nutrition_state", {})
    recent_recipes = state.get("recent_recipes", [])
    hard_constraints = state.get("hard_constraints", [])

    reward = compute_reward(
        user_score=user_score,
        recommended_recipes=recipes,
        recent_recipes=recent_recipes,
        nutrition_state=nutrition_state,
        hard_constraints=hard_constraints,
        recipe_tags=recipe_tags,
    )

    traj.reward = reward
    traj.user_score = user_score
    db.commit()
    return reward


# ── 5. 离线学习 ────────────────────────────────────────────────

def should_trigger_learning(db: Session) -> bool:
    """判断是否需要触发离线学习"""
    total = db.query(RecommendationTrajectory).filter(
        RecommendationTrajectory.reward.isnot(None)
    ).count()

    if total < LEARN_THRESHOLD_INIT:
        return False

    # 检查上次学习后新增了多少条
    last_policy = db.query(PromptStrategyPolicy).order_by(
        PromptStrategyPolicy.updated_at.desc()
    ).first()

    if not last_policy:
        return True  # 从未学习过，直接触发

    # 统计上次学习时间之后新增的完整轨迹数
    new_count = db.query(RecommendationTrajectory).filter(
        RecommendationTrajectory.reward.isnot(None),
        RecommendationTrajectory.created_at > last_policy.updated_at,
    ).count()

    return new_count >= LEARN_THRESHOLD_INCR


def run_offline_learning(db: Session) -> dict:
    """
    离线学习主函数：
    遍历所有完整轨迹，按状态键分组，
    找出每个状态下平均奖励最高的策略，写入策略表。
    返回更新摘要。
    """
    trajectories = db.query(RecommendationTrajectory).filter(
        RecommendationTrajectory.reward.isnot(None)
    ).all()

    if not trajectories:
        return {"updated": 0, "message": "无完整轨迹数据"}

    # 按状态键分组：{state_key: [(strategy, reward), ...]}
    groups: dict[str, list[tuple[dict, float]]] = {}
    for traj in trajectories:
        state = traj.get_state()
        state_key = build_state_key(state)
        strategy = traj.get_strategy()
        reward = traj.reward
        if state_key not in groups:
            groups[state_key] = []
        groups[state_key].append((strategy, reward))

    updated = 0
    for state_key, samples in groups.items():
        if len(samples) < 2:
            continue  # 样本太少，跳过

        # 找出平均奖励最高的策略
        # 先把相同策略的奖励聚合
        strategy_rewards: dict[str, list[float]] = {}
        for strategy, reward in samples:
            key = json.dumps(strategy, sort_keys=True, ensure_ascii=False)
            if key not in strategy_rewards:
                strategy_rewards[key] = []
            strategy_rewards[key].append(reward)

        best_key = max(strategy_rewards, key=lambda k: sum(strategy_rewards[k]) / len(strategy_rewards[k]))
        best_strategy = json.loads(best_key)
        best_rewards = strategy_rewards[best_key]
        avg_reward = sum(best_rewards) / len(best_rewards)

        # 写入或更新策略表
        policy = db.query(PromptStrategyPolicy).filter(
            PromptStrategyPolicy.state_key == state_key
        ).first()
        if not policy:
            policy = PromptStrategyPolicy(state_key=state_key)
            db.add(policy)

        policy.best_strategy = json.dumps(best_strategy, ensure_ascii=False)
        policy.avg_reward = round(avg_reward, 4)
        policy.sample_count = len(samples)
        updated += 1

    db.commit()
    return {"updated": updated, "total_trajectories": len(trajectories)}
