#! /bin/bash

# 检查是否配置MYSQL地址
if [ -n "$CUR_SG_DB_HOST" ] && [ -n "$CUR_SG_DB_PORT" ]; then
  # 代理本地3307端口并转发
  ./forward --forward 3307/$CUR_SG_DB_HOST:$CUR_SG_DB_PORT/tcp
else
    echo "no need to start mysql proxy"
fi
# 等待5秒后退出
sleep 5
