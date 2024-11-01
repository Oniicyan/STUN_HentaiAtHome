# 以下变量需按要求填写
PROXY=socks5://192.168.1.168:10808			# 可用的代理协议、地址与端口；留空则不使用代理
INFODIR=/tmp								# 穿透信息保存目录，默认为 /tmp
APPPORT=44388								# H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=12345								# H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE				# H@H 客户端密钥 (Client Key)
EHIPBID=1234567								# ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef	# ipb_pass_hash

WANADDR=$1
WANPORT=$2
LANPORT=$4
L4PROTO=$5
OWNADDR=$6

OWNNAME=$(echo stun_hath_${APPADDR}_${APPPORT}$([ -n "$IFNAME" ] && echo @$IFNAME) | sed 's/[[:punct:]]/_/g')
RELEASE=$(grep ^ID= /etc/os-release | awk -F '=' '{print$2}' | tr -d \")

[ -n "$PROXY" ] && PROXY=$(echo "-x $PROXY")

# 防止脚本重复运行
PIDNF=$( ( ps aux 2>/dev/null; ps ) | awk '{for(i=1;i<=NF;i++)if($i=="PID")n=i}NR==1{print n}' )
while :; do
  ( ps aux 2>/dev/null; ps ) | grep $0 | grep -v -e "$$\|grep" | awk 'NR==1{print$'$PIDNF'}' | xargs kill >/dev/null 2>&1 || break
done

# 保存穿透信息
echo $L4PROTO $WANADDR:$WANPORT '->' $OWNADDR:$LANPORT $(date +%s) >$INFODIR/$OWNNAME.info
echo $(date) $L4PROTO $WANADDR:$WANPORT '->' $OWNADDR:$LANPORT >>$INFODIR/$OWNNAME.log

# 获取 H@H 设置信息
while [ -z $f_cname ]; do
	let GET++
 	if [ $GET -gt 3 ]; then
  		echo -n $OWNNAME: Failed to get the settings. Please check the PROXY. >&2
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

# 若外部端口未变，则退出
[ "$(grep f_port $HATHPHP | awk -F '"' '{print$6}')" = $WANPORT ] && \
echo -n $OWNNAME: The external port has not changed. >&2 && exit 0

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
ACTION client_suspend >/dev/null
while :; do
	let SET++
 	if [ $SET -gt 3 ]; then
  		echo -n $OWNNAME: Failed to update the external port. Please check the PROXY. >&2
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
	echo -n $OWNNAME: The external port is updated successfully. && break
done

# 发送 client_start 后，校验响应消息
# 若客户端已启动，则自动恢复连接，无需重启
# 若客户端未启动，client_suspend 与 client_start 不会造成实质影响
# 本脚本不启动 H@H 客户端，请自行在运行设备上启动
# 启动命令末尾加上参数 --port=44388，指定客户端的本地监听端口 (APPPORT)
# 必须在穿透成功后再启动，否则无法完成初始化，客户端将拒绝连接请求
# [[ $(ACTION client_start | head -1) != "OK" ]] && \
ACTION client_start
echo -n Now please check that the client is running correctly.
