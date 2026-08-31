#!/usr/bin/env bash
# ============================================================
#  一键批量编译脚本 - 欧加真系列 6.12 内核全版本
#  编译：KPM开启 / KPM关闭  ×  6 个内核版本  = 共 12 个版本
#  防格机(BBG) 默认全部关闭
#  By Coolapk@cctv18
# ============================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/build_logs_$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${SCRIPT_DIR}/../outputs"
BUILD_SUCCESS=()
BUILD_FAILED=()

# --- 统一配置（所有版本共用，BBG 关闭，其它全机型兼容默认值） ---
export APPLY_BBG="n"              # 防格机：默认关闭 (核心要求)
export APPLY_SUSFS="y"            # susfs 增强隐藏挂载：开启（全机型兼容）
export KSU_BRANCH="r"             # ReSukiSU 默认
export APPLY_LZ4="y"              # lz4+zstd 压缩优化：开启
export APPLY_LZ4KD="n"            # lz4kd：关闭（与 lz4+zstd 互斥/冗余）
export APPLY_BETTERNET="y"        # 网络功能增强：开启
export APPLY_BBR="n"              # BBR 拥塞控制：关闭（手机日用可能负优化）
export APPLY_DROIDSPACES="n"      # Droidspaces 容器：关闭（按需开）
export APPLY_ADIOS="y"            # ADIOS IO 调度：开启（提升IO性能）
export APPLY_REKERNEL="n"         # Re-Kernel：关闭（部分机型不兼容）

# --- 版本定义 ---
declare -a BUILDERS=(
  "builder_6.12.23.sh|SM8850-6.12.23"
  "builder_6.12.23_gki.sh|GKI-6.12.23"
  "builder_6.12.23_mtk.sh|MT6993-6.12.23"
  "builder_6.12.38.sh|SM8850-6.12.38"
  "builder_6.12.58.sh|SM8850-6.12.58"
  "builder_6.12.58_mtk.sh|MT6993-6.12.58"
)

declare -a KPM_MODES=(
  "y|KPM-ON"
  "n|KPM-OFF"
)

mkdir -p "${LOG_DIR}"

BANNER="========================================================"
echo -e "\n${BANNER}"
echo -e "  一键批量编译 - 6.12 全内核版本 (KPM开+KPM关)"
echo -e "  防格机(BBG) 默认为全部关闭"
echo -e "  共 ${#BUILDERS[@]} 个内核 × ${#KPM_MODES[@]} 种KPM模式 = $((${#BUILDERS[@]} * ${#KPM_MODES[@]})) 个编译任务"
echo -e "${BANNER}\n"
echo -e "  日志目录: ${LOG_DIR}"
echo -e "  开始时间: $(date '+%Y-%m-%d %H:%M:%S')\n"

TOTAL=$((${#BUILDERS[@]} * ${#KPM_MODES[@]}))
CURRENT=0

for BUILDER_ENTRY in "${BUILDERS[@]}"; do
  BUILDER_SCRIPT="${BUILDER_ENTRY%%|*}"
  BUILDER_LABEL="${BUILDER_ENTRY##*|}"
  BUILDER_PATH="${SCRIPT_DIR}/${BUILDER_SCRIPT}"

  if [[ ! -f "${BUILDER_PATH}" ]]; then
    echo -e "\n[跳过] 找不到构建脚本: ${BUILDER_PATH}"
    BUILD_FAILED+=("${BUILDER_LABEL}(脚本缺失)")
    continue
  fi

  for KPM_ENTRY in "${KPM_MODES[@]}"; do
    KPM_VAL="${KPM_ENTRY%%|*}"
    KPM_LABEL="${KPM_ENTRY##*|}"
    CURRENT=$((CURRENT + 1))
    TASK_LABEL="${BUILDER_LABEL}_${KPM_LABEL}"
    LOG_FILE="${LOG_DIR}/${TASK_LABEL}.log"

    echo -e "${BANNER}"
    echo -e "[${CURRENT}/${TOTAL}] 正在编译: ${TASK_LABEL}"
    echo -e "  构建脚本: ${BUILDER_SCRIPT}"
    echo -e "  KPM: ${KPM_VAL}  BBG: ${APPLY_BBG}"
    echo -e "  日志: ${LOG_FILE}"
    echo -e "${BANNER}"

    START_TIME=$(date +%s)

    # 设置 KPM 环境变量，通过 yes "" 提供所有 read 的默认回车（接受默认值）
    if USE_PATCH_LINUX="${KPM_VAL}" \
       CUSTOM_SUFFIX="" \
       yes "" | bash "${BUILDER_PATH}" >"${LOG_FILE}" 2>&1; then
      DURATION=$(( $(date +%s) - START_TIME ))
      echo -e "[OK]  ${TASK_LABEL}  编译成功  (耗时: $((DURATION/60))分$((DURATION%60))秒)"
      BUILD_SUCCESS+=("${TASK_LABEL}($((DURATION/60))m${DURATION%60}s)")
    else
      DURATION=$(( $(date +%s) - START_TIME ))
      echo -e "[失败] ${TASK_LABEL}  编译失败  (耗时: $((DURATION/60))分$((DURATION%60))秒)  查看日志: ${LOG_FILE}"
      BUILD_FAILED+=("${TASK_LABEL}($((DURATION/60))m${DURATION%60}s)")
      # 可选：出错是否继续？默认继续下一个
    fi
  done
done

# --- 输出总结 ---
echo -e "\n\n${BANNER}"
echo -e "  全部编译任务完成！  结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BANNER}"
echo -e "\n  成功 (${#BUILD_SUCCESS[@]} / ${TOTAL}):"
if [[ ${#BUILD_SUCCESS[@]} -eq 0 ]]; then
  echo -e "    （无）"
else
  for item in "${BUILD_SUCCESS[@]}"; do echo -e "    - ${item}"; done
fi

echo -e "\n  失败 (${#BUILD_FAILED[@]} / ${TOTAL}):"
if [[ ${#BUILD_FAILED[@]} -eq 0 ]]; then
  echo -e "    （无）✓ 全部成功"
else
  for item in "${BUILD_FAILED[@]}"; do echo -e "    - ${item}"; done
fi

echo -e "\n  产物输出目录: ${OUTPUT_DIR}"
echo -e "  所有日志目录: ${LOG_DIR}"
echo -e "${BANNER}\n"

[[ ${#BUILD_FAILED[@]} -eq 0 ]] && exit 0 || exit 1
