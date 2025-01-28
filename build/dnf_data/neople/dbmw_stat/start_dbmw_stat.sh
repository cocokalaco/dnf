# /bin/bash
kill -9 $(pgrep -f "df_dbmw_r dbmw_stat_$SERVER_GROUP_NAME start")
rm -rf pid/*.pid
./df_dbmw_r dbmw_stat_$SERVER_GROUP_NAME start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
