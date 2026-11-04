#!/usr/bin/env bash
# 可选彩蛋：把 PX4 SITL + MAVROS 拉起来，把本任务的接口换成真机接口跑一次。
#
#   ./run_px4_sitl.sh
#   PX4_DIR=~/PX4-Autopilot ./run_px4_sitl.sh
#
# ⚠️ SITL 上失控保护是真的会触发，第一次跑请留一个人手放在急停上。
#    这不是必做项，也不参与判定；缺东西时脚本会告诉你缺什么，然后正常退出。

set -o pipefail

PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
FCU_URL="${FCU_URL:-udp://:14540@127.0.0.1:14557}"

missing=()
command -v rosrun >/dev/null 2>&1 || missing+=("ROS（先 source /opt/ros/noetic/setup.bash）")
[ -d "$PX4_DIR" ] || missing+=("PX4-Autopilot 源码（默认找 $PX4_DIR，可用 PX4_DIR 指定）")
rosrun mavros mavros_node --help >/dev/null 2>&1 || true
rospack find mavros >/dev/null 2>&1 || missing+=("mavros（sudo apt install ros-noetic-mavros ros-noetic-mavros-extras）")

if [ "${#missing[@]}" -gt 0 ]; then
  printf '%s\n' "还差这些才能起 PX4 SITL："
  for item in "${missing[@]}"; do
    printf '  - %s\n' "$item"
  done
  printf '\n%s\n' "装好之后重跑本脚本；不想折腾就跳过——主路径不需要 PX4。"
  exit 0
fi

printf '%s\n' "== 启动 MAVROS（fcu_url: $FCU_URL）"
roslaunch mavros px4.launch fcu_url:="$FCU_URL" &
MAVROS_PID=$!
sleep 5

printf '%s\n' "== 启动 PX4 SITL（headless）"
(
  cd "$PX4_DIR" || exit 1
  make px4_sitl gazebo
) &
PX4_PID=$!

trap 'kill "$MAVROS_PID" "$PX4_PID" 2>/dev/null; exit 0' INT TERM

printf '%s\n' "== 起来了。把 /drone/setpoint 换成 /mavros/setpoint_position/local，"
printf '%s\n' "   /drone/state 换成 /mavros/state + /mavros/local_position/pose，再跑你的节点。"

wait
