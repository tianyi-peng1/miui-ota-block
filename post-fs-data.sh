#!/system/bin/sh
# 显式 bind mount，避免不同 root 管理器 magic mount 对单文件处理不一致
MODDIR=${0%/*}
HOSTS="$MODDIR/system/etc/hosts"

[ -f "$HOSTS" ] || exit 0

mount -o bind "$HOSTS" /system/etc/hosts 2>/dev/null
