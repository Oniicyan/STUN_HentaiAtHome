# 从 Lucky 自定义脚本中传递参数
WANADDR=$1  # 公网地址
WANPORT=$2  # 公网端口
LANPORT=    # Lucky 不传递穿透通道本地端口，留空
L4PROTO=tcp
OWNADDR=    # Lucky 不传递穿透通道本地地址，留空

APPPORT=$3  # H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=$4  # H@H 客户端 ID (Client ID)
HATHKEY=$5  # H@H 客户端密钥 (Client Key)
EHIPBID=$6  # ipb_member_id
EHIPBPW=$7  # ipb_pass_hash
HATHDIR=$8	# H@H 客户端所在路径；留空则不自动执行（留空时传递 /tmp）
[ -n "$9" ] && PROXY=$(echo "-x $9") # 可用的代理协议、地址与端口；留空则不使用代理

OWNNAME=stun_hath_$HATHCID

# 防止脚本重复运行
PIDNF=$( ( ps aux 2>/dev/null; ps ) | awk '{for(i=1;i<=NF;i++)if($i=="PID")n=i}NR==1{print n}' )
while :; do
  ( ps aux 2>/dev/null; ps ) | grep $0 | grep -v -e "$$\|grep" | awk 'NR==1{print$'$PIDNF'}' | xargs kill >/dev/null 2>&1 || break
done

# 保存穿透信息
echo $(date) $L4PROTO $WANADDR:$WANPORT $([ -n "$LANPORT" ] && echo '->' $OWNADDR:$LANPORT) >>$HATHDIR/$OWNNAME.log

# 获取 H@H 设置信息
while [ -z $f_cname ]; do
	let GET++
 	if [ $GET -gt 3 ]; then
  		logger -st $OWNNAME Failed to get the settings. Please check the PROXY.
    	exit 1
	fi
 	[ $GET -ne 1 ] && sleep 15
	HATHPHP=/tmp/$OWNNAME.php
	echo >$HATHPHP
	curl $PROXY -Ls -m 15 \
	-b 'ipb_member_id='$EHIPBID'; ipb_pass_hash='$EHIPBPW'' \
	-o $HATHPHP \
	'https://e-hentai.org/hentaiathome.php?cid='$HATHCID'&act=settings'
	f_cname=$(grep f_cname $HATHPHP | awk -F '"' '{print$6}' | sed 's/[ ]/+/g')
	f_throttle_KB=$(grep f_throttle_KB $HATHPHP | awk -F '"' '{print$6}')
	f_disklimit_GB=$(grep f_disklimit_GB $HATHPHP | awk -F '"' '{print$6}')
	p_mthbwcap=$(grep p_mthbwcap $HATHPHP | awk -F '"' '{print$6}')
	f_diskremaining_MB=$(grep f_diskremaining_MB $HATHPHP | awk -F '"' '{print$6}')
	f_enable_bwm=$(grep f_enable_bwm $HATHPHP | grep checked)
	f_disable_logging=$(grep f_disable_logging $HATHPHP | grep checked)
	f_use_less_memory=$(grep f_use_less_memory $HATHPHP | grep checked)
	f_is_hathdler=$(grep f_is_hathdler $HATHPHP | grep checked)
done

# 检测是否需要更改端口
[ "$(grep f_port $HATHPHP | awk -F '"' '{print$6}')" = $WANPORT ] && \
logger -st $OWNNAME The external port $WANPORT/tcp has not changed. && SKIP=1

# 定义与 RPC 服务器交互的函数
# 访问 http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=server_stat 查询当前支持的 client_build
ACTION() {
	ACT=$1
	ACTTIME=$(date +%s)
	ACTKEY=$(echo -n "hentai@home-$ACT--$HATHCID-$ACTTIME-$HATHKEY" | sha1sum | cut -c -40)
	curl -Ls "http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=$ACT&add=&cid=$HATHCID&acttime=$ACTTIME&actkey=$ACTKEY"
}

# 发送 client_suspend 后，更新端口信息
# 更新后，发送 client_settings 验证端口
[ -z "$SKIP" ] && ACTION client_suspend >/dev/null
while [ -z "$SKIP" ]; do
	let SET++
 	if [ $SET -gt 3 ]; then
  		logger -st $OWNNAME Failed to update the external port. Please check the PROXY.
    	exit 1
	fi
	[ $SET -ne 1 ] && sleep 15
	DATA="settings=1&f_port=$WANPORT&f_cname=$f_cname&f_throttle_KB=$f_throttle_KB&f_disklimit_GB=$f_disklimit_GB"
	[ "$p_mthbwcap" = 0 ] || DATA="$DATA&p_mthbwcap=$p_mthbwcap"
	[ "$f_diskremaining_MB" = 0 ] || DATA="$DATA&f_diskremaining_MB=$f_diskremaining_MB"
	[ -n "$f_enable_bwm" ] && DATA="$DATA&f_enable_bwm=on"
	[ -n "$f_disable_logging" ] && DATA="$DATA&f_disable_logging=on"
	[ -n "$f_use_less_memory" ] && DATA="$DATA&f_use_less_memory=on"
	[ -n "$f_is_hathdler" ] && DATA="$DATA&f_is_hathdler=on"
	curl $PROXY -Ls -m 15 \
	-b 'ipb_member_id='$EHIPBID'; ipb_pass_hash='$EHIPBPW'' \
	-o $HATHPHP \
	-d ''$DATA'' \
	'https://e-hentai.org/hentaiathome.php?cid='$HATHCID'&act=settings'
	ACTION client_settings | grep port=$WANPORT >/dev/null && \
	logger -st $OWNNAME The external port $WANPORT/tcp is updated successfully. && break
done

# 发送 client_start 后，检测是否需要启动 H@H 客户端
# 若客户端已启动，则自动恢复连接，无需重启
# 若客户端未启动，client_suspend 与 client_start 不会造成实质影响
[ -z "$SKIP" ] && ACTION client_start >/dev/null
if [ $HATHDIR != /tmp ]; then
	sleep 5 && cd $HATHDIR
	screen -ls | grep $OWNNAME || \
	screen -dmS $OWNNAME java -jar $HATHDIR/HentaiAtHome.jar --port=44388
fi
logger -st $OWNNAME Now please check if the client is running correctly.
