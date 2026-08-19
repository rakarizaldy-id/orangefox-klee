#!/system/bin/sh
# Build49 transparent TWRP CLI wrapper. Preserve every existing command by
# exec'ing the original binary; only prepare metadata-backed settings binds
# before the two destructive CLI forms that can format /metadata.
REAL=/system/bin/twrp.real
if [ "$1" = "format" ] && [ "$2" = "data" ]; then
    /system/bin/klee-wipe-prep DATAMEDIA "" >/dev/null 2>&1
elif [ "$1" = "wipe" ] && [ "$2" = "metadata" ]; then
    /system/bin/klee-wipe-prep LIST "/metadata;" >/dev/null 2>&1
fi
exec "$REAL" "$@"
