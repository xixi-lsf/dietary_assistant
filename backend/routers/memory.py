from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from backend.database import get_db
from backend.models import UserMemory, Feedback
from backend.services import ai_service
import json
import math


#记忆统计

router = APIRouter(prefix="/memory", tags=["memory"])
DECAY = 0.9

# 笼统模糊标签黑名单，不应出现在词云中
_VAGUE_TAGS = {
    "适合我的口味", "符合偏好", "好吃", "不错", "很好", "喜欢", "推荐",
    "满意", "适合", "符合", "口味好", "味道好", "很棒", "好", "棒", "赞",
    "完美", "优秀", "一般", "还行", "不错吃", "挺好", "还可以", "可以",
}
_VAGUE_KEYWORDS = ["口味", "偏好", "推荐", "适合", "符合", "满意", "喜欢", "风格"]


def _filter_weights(weights: dict) -> dict:
    """过滤笼统模糊的口味标签"""
    return {
        tag: w for tag, w in weights.items()
        if tag not in _VAGUE_TAGS
        and len(tag) <= 8
        and not any(kw in tag for kw in _VAGUE_KEYWORDS)
    }

#接受用户的历史反馈列表（按时间顺序），逐步重放每次反馈对口味权重的影响，并记录下每次反馈后的权重快照及统计信息（方差）。
#最终返回一个快照列表，用于前端可视化或收敛性分析。
#仅用于分析和可视化，并不修改数据库中的 UserMemory.taste_weights
#参数：一个list，每个元素是一个字典，从userMemory.feedback_history JSON解析而来
def _replay_weights(feedback_history: list) -> list:
    """从反馈历史重放，返回每步的权重快照和方差"""
    
    #空字典，存储当前各标签的权重（0~1）
    weights = {}
    # 存储每一步的快照
    snapshots = []

    #遍历每条反馈
    for i, entry in enumerate(feedback_history):
        #提取评分并计算delta
        score = entry.get("score", 3)
        tags_str = entry.get("tags", "")
        delta = (score - 3) / 2.0

        #解析标签并更新每个标签的权重
        for tag in [t.strip() for t in tags_str.split("，") if t.strip()]:
            old = weights.get(tag, 0.5)
            weights[tag] = round(old * DECAY + (0.5 + delta * 0.3) * (1 - DECAY), 3)
            weights[tag] = max(0.0, min(1.0, weights[tag]))

        # 计算当前所有权重的方差
        #方差衡量用户偏好是否集中（方差大则分散，口味复杂，各标签权重差异大）
        vals = list(weights.values())
        if len(vals) >= 2:
            mean = sum(vals) / len(vals)
            variance = round(sum((v - mean) ** 2 for v in vals) / len(vals), 4)
        else:
            variance = 0.0

        #记录快照
        snapshots.append({
            "feedback_index": i + 1,
            "date": entry.get("date", ""),
            "recipe": entry.get("recipe", ""),
            "score": score,
            "weights_snapshot": dict(weights),#复制当前权重字典
            "active_tags": len(weights),# 出现过多少不同标签
            "variance": variance,
        })

    #返回快照列表，[{},{},{}...]含有多个json
    return snapshots


#量化用户口味偏好是否已经稳定（收敛）
#给定一组按时间顺序的权重快照（由 _replay_weights 生成），计算收敛指数,接近1则稳定
#收敛指数帮助系统判断是否需要继续收集反馈，或者是否可以自信地推荐
#衡量权重变化的衰减速度。如果用户的偏好逐渐稳定，那么相邻反馈之间的权重调整幅度会越来越小，recent/early 变小，指数变大。
def _convergence_index(snapshots: list) -> float:
    """收敛指数：最近5次权重变化量 / 前5次变化量，越小越收敛，返回 0-1"""
    if len(snapshots) < 2:
        return 0.0

    #辅助函数：计算两个权重字典之间的平均绝对变化量
    def _weight_change(a: dict, b: dict) -> float:
        all_keys = set(a) | set(b)
        if not all_keys:
            return 0.0
        return sum(abs(b.get(k, 0.5) - a.get(k, 0.5)) for k in all_keys) / len(all_keys)

    #计算相邻快照的变化量序列
    changes = [
        _weight_change(snapshots[i - 1]["weights_snapshot"], snapshots[i]["weights_snapshot"])
        for i in range(1, len(snapshots))
    ]

    #反馈数量太少，无法判断
    if len(changes) < 2:
        return 0.0

    window = min(5, len(changes) // 2)
    early = sum(changes[:window]) / window if window > 0 else 0
    recent = sum(changes[-window:]) / window if window > 0 else 0

    if early == 0:
        return 1.0
    # 收敛指数 = 1 - (recent/early)，clamp 到 [0,1]
    return round(max(0.0, min(1.0, 1 - recent / early)), 3)


#记忆系统的状态报告窗口
#用于查看用户口味偏好的学习进度、评分趋势、以及不同推荐策略的效果对比
#返回用户记忆系统的当前状态（JSON），包括历史演化数据、收敛指标、A/B 测试结果等
@router.get("/stats")
def memory_stats(db: Session = Depends(get_db)):
    memory = db.query(UserMemory).first()
    if not memory:
        return {
            "taste_weight_history": [],
            "score_trend": [],
            "convergence_index": 0.0,
            "current_memory": None,
            "summary": "暂无反馈数据，记忆系统尚未启动。",
        }

    feedback_history = memory.get_feedback_history()
    if not feedback_history:
        return {
            "taste_weight_history": [],
            "score_trend": [],
            "convergence_index": 0.0,
            "current_memory": {
                "taste_weights": memory.get_taste_weights(),
                "hard_constraints": memory.get_hard_constraints(),
                "health_goals": memory.get_health_goals(),
                "feedback_count": 0,
            },
            "summary": "暂无反馈数据，记忆系统尚未启动。",
        }

    # 重放权重历史：snapshots 包含了每个反馈之后的 weights_snapshot、方差、评分等信息
    snapshots = _replay_weights(feedback_history)

    # 评分趋势（滑动平均，窗口3）
    #从第i条反馈开始，去最近3条评分的平均值
    score_trend = []
    window = 3
    for i, entry in enumerate(feedback_history):
        start = max(0, i - window + 1)
        rolling = sum(feedback_history[j]["score"] for j in range(start, i + 1)) / (i - start + 1)
        score_trend.append({
            "feedback_index": i + 1,
            "date": entry.get("date", ""),
            "recipe": entry.get("recipe", ""),
            "score": entry.get("score", 3),
            "rolling_avg": round(rolling, 2),
        })

    #计算收敛指数
    conv_index = _convergence_index(snapshots)
    #记录总反馈条数
    feedback_count = len(feedback_history)

    # A/B 对比：从 Feedback 表按 recommendation_mode 分组统计
    all_feedback = db.query(Feedback).all()#从数据库的 Feedback 表中读取 所有 反馈记录
    ab_stats: dict = {}
    #遍历所有反馈，按 ecommendation_mode 分两组：硬编码反馈和agent反馈，每组记录该模式下反馈总条数、评分的累加和、所有评分的列表
    for fb in all_feedback:
        mode = fb.recommendation_mode or "hardcoded"
        if mode not in ab_stats:
            ab_stats[mode] = {"count": 0, "total_score": 0, "scores": []}
        ab_stats[mode]["count"] += 1
        ab_stats[mode]["total_score"] += fb.score
        ab_stats[mode]["scores"].append(fb.score)

    #计算平均评分、方差（越小表示用户评分越稳定）、1~5分各出现次数（是否高分居多或低分居多）
    ab_comparison = {}
    for mode, stats in ab_stats.items():
        scores = stats["scores"]
        avg = stats["total_score"] / stats["count"] if stats["count"] > 0 else 0
        variance = sum((s - avg) ** 2 for s in scores) / len(scores) if scores else 0
        ab_comparison[mode] = {
            "count": stats["count"],
            "avg_score": round(avg, 2),
            "score_variance": round(variance, 3),
            "score_distribution": {str(i): scores.count(i) for i in range(1, 6)},
        }

    # 文字摘要
    if feedback_count < 3:
        summary = f"已收集 {feedback_count} 条反馈，记忆系统正在学习中。"
    elif conv_index >= 0.7:
        summary = f"已收集 {feedback_count} 条反馈，口味偏好已基本收敛（收敛指数 {conv_index}）。"
    else:
        summary = f"已收集 {feedback_count} 条反馈，口味偏好仍在学习中（收敛指数 {conv_index}）。"

    #返回完整响应
    return {
        "taste_weight_history": snapshots,#快照列表，用于前端绘制权重演化图
        "score_trend": score_trend,#每条反馈的原始评分和滑动平均分，用于观察用户满意度变化趋势
        "convergence_index": conv_index,#收敛指数
        "current_memory": {
            "taste_weights": _filter_weights(memory.get_taste_weights()),
            "hard_constraints": memory.get_hard_constraints(),
            "health_goals": memory.get_health_goals(),
            "preference_summary": memory.preference_summary or "",
            "feedback_count": feedback_count,
        },
        "ab_comparison": ab_comparison,#一个json，对比不同推荐模式
        "summary": summary,
    }


class DietObservationRequest(BaseModel):
    api_key: str
    ai_base_url: Optional[str] = None
    ai_model: Optional[str] = None


@router.post("/diet-observation")
def diet_observation(req: DietObservationRequest, db: Session = Depends(get_db)):
    """根据用户口味权重和收敛指数，让 AI 生成一段饮食观察文字"""
    memory = db.query(UserMemory).first()
    if not memory:
        return {"observation": "快来告诉管家你的偏好吧～"}

    taste_weights = _filter_weights(memory.get_taste_weights())
    feedback_history = memory.get_feedback_history()
    feedback_count = len(feedback_history)

    if not taste_weights or feedback_count == 0:
        return {"observation": "快来告诉管家你的偏好吧～"}

    snapshots = _replay_weights(feedback_history)
    conv_index = _convergence_index(snapshots)

    # 按权重排序，取前10个标签
    sorted_weights = sorted(taste_weights.items(), key=lambda x: x[1], reverse=True)[:10]
    weights_desc = "、".join(f"{tag}({round(w, 2)})" for tag, w in sorted_weights)

    hard_constraints = memory.get_hard_constraints()
    health_goals = memory.get_health_goals()

    prompt = f"""你是用户的私人饮食管家，请根据以下数据，用温暖亲切的语气写一段"饮食观察"（100-150字），
总结用户的口味偏好，并告诉用户接下来会怎么推荐菜肴。不要用列表，用自然段落。

口味权重（标签:权重，越高越偏好）：{weights_desc}
收敛指数：{round(conv_index * 100)}%（越高说明偏好越稳定）
累计反馈：{feedback_count} 条
硬约束（绝对不吃）：{', '.join(hard_constraints) if hard_constraints else '无'}
健康目标：{', '.join(health_goals) if health_goals else '无'}

请直接输出观察文字，不要加标题或前缀。"""

    try:
        observation = ai_service._post(
            api_key=req.api_key,
            base_url=req.ai_base_url,
            payload={
                "model": req.ai_model,
                "max_tokens": 300,
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        return {"observation": observation}
    except Exception as e:
        # 降级：返回基于规则的文字
        top_tags = [tag for tag, _ in sorted_weights[:3]]
        conv_label = "已基本稳定" if conv_index >= 0.7 else "仍在学习中"
        fallback = (
            f"根据你的 {feedback_count} 条反馈，管家发现你特别偏爱{('、'.join(top_tags)) if top_tags else '多种口味'}。"
            f"你的口味偏好{conv_label}（收敛指数 {round(conv_index * 100)}%）。"
            f"接下来管家会优先推荐符合这些偏好的菜肴，同时兼顾营养均衡。"
        )
        return {"observation": fallback}
