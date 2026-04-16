from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.models import UserMemory, Feedback
import json
import math


#记忆统计

router = APIRouter(prefix="/memory", tags=["memory"])
DECAY = 0.9

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
            "taste_weights": memory.get_taste_weights(),
            "hard_constraints": memory.get_hard_constraints(),
            "health_goals": memory.get_health_goals(),
            "preference_summary": memory.preference_summary or "",
            "feedback_count": feedback_count,
        },
        "ab_comparison": ab_comparison,#一个json，对比不同推荐模式
        "summary": summary,
    }
