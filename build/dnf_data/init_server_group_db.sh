#! /bin/bash

# 针对大区数据库定义局部变量
CUR_SG_DB_HOST=$MYSQL_HOST
CUR_SG_DB_PORT=$MYSQL_PORT
CUR_SG_DB_ROOT_PASSWPRD=$DNF_DB_ROOT_PASSWORD
CUR_SG_DB_GAME_ALLOW_IP=$MYSQL_GAME_ALLOW_IP

# 本地数据库地址配置
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  CUR_SG_DB_HOST=127.0.0.1
  CUR_SG_DB_PORT=4000
  CUR_SG_DB_GAME_ALLOW_IP=127.0.0.1
fi

# 导出环境变量
export CUR_SG_DB_HOST
export CUR_SG_DB_PORT
export CUR_SG_DB_ROOT_PASSWPRD

# 试图自动获取CUR_SG_DB_GAME_ALLOW_IP
if [ -z "$CUR_SG_DB_GAME_ALLOW_IP" ];then
  CUR_SG_DB_GAME_ALLOW_IP=$(ip route | awk '/default/ { print $3 }')
  # 尝试连接mysql自动配置ALLOW_IP
  check_result=$(mysql --connect_timeout=2 -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u game 2>&1)
  error_code=$?
  if [ $error_code -ne 0 ]; then
    echo "try to get game allow ip....."
    mysql_error_code=$(echo "$check_result" | awk '{print $2}')
    if [ "$mysql_error_code" == "1045" ]; then
        CUR_SG_DB_GAME_ALLOW_IP=$(echo $check_result | awk -F"'" '{print $4}')
        echo "set CUR_SG_DB_GAME_ALLOW_IP=$CUR_SG_DB_GAME_ALLOW_IP"
    fi
  fi
fi

echo "init server group db $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
# 循环初始化大区数据库
SG_DB_LIST=("taiwan_$SERVER_GROUP_NAME" "taiwan_${SERVER_GROUP_NAME}_2nd" "taiwan_${SERVER_GROUP_NAME}_log" "taiwan_${SERVER_GROUP_NAME}_web" "taiwan_${SERVER_GROUP_NAME}_auction_gold" "taiwan_${SERVER_GROUP_NAME}_auction_cera" "taiwan_login" "taiwan_prod" "taiwan_game_event" "taiwan_se_event" "taiwan_login_play" "taiwan_billing")

for db_name in "${SG_DB_LIST[@]}"
do
    echo "prepare init $db_name....."
    check_result=$(mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWPRD -e "use $db_name" 2>&1)
    error_code=$?
    if [ $error_code -eq 0 ]; then
      echo "server group db: $db_name already inited."
    else
      mysql_error_code=$(echo "$check_result" | awk '{print $2}')
      if [ "$mysql_error_code" == "1049" ]; then
          echo "server group db: prepare to init remote mysql service dnf data."
          mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWPRD <<EOF
          CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
          use $db_name;
          source /home/template/init/init_sql/$db_name.sql;
          flush PRIVILEGES;
EOF
      else
          echo "server group db: can not connect to mysql service $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
          echo $check_result
          exit -1
      fi
    fi
done

# game账户连接大区数据库需要配置game账户权限[主数据库和大区数据库可能是独立的需要单独配置]
echo "server group db: flush privileges....."
mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWPRD <<EOF
delete from mysql.user where user='game' and host='$CUR_SG_DB_GAME_ALLOW_IP';
flush privileges;
grant all privileges on *.* to 'game'@'$CUR_SG_DB_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
EOF
# 测试并查询数据库连接设置
echo "server group db: show db_connect config, server_group is $SERVER_GROUP"
mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
select gc_type, gc_ip, gc_channel from taiwan_$SERVER_GROUP_NAME.game_channel where gc_type=$SERVER_GROUP;
EOF
echo "server_group_db: init server group-$SERVER_GROUP($SERVER_GROUP_NAME) done."
