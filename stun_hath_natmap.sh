# 以下变量需按要求填写
PROXY=socks5://192.168.1.168:10808        # 可用的代理协议、地址与端口；留空则不使用代理
HATHDIR=/mnt/sda1                         # H@H 客户端所在路径；留空则不自动执行（非本机客户端请留空）
APPPORT=44388                             # H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=12345                             # H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE              # H@H 客户端密钥 (Client Key)
EHIPBID=1234567                           # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash

WANADDR=$1
WANPORT=$2
LANPORT=$4
L4PROTO=$5
OWNADDR=$6

OWNNAME=stun_hath_$HATHCID
[ -n "$PROXY" ] && PROXY=$(echo "-x $PROXY")
[ -z "$HATHDIR" ] && HATHDIR=/tmp

BUILD=169

curl -V >/dev/null || (logger -st $OWNNAME Please install curl.; exit 127)
sha1sum --version >/dev/null || (logger -st $OWNNAME Please install coreutils-sha1sum; exit 127)

# 防止脚本重复运行
PIDNF=$( ( ps aux 2>/dev/null; ps ) | awk '{for(i=1;i<=NF;i++)if($i=="PID")n=i}NR==1{print n}' )
while :; do
  ( ps aux 2>/dev/null; ps ) | grep $0 | grep -v -e "$$\|grep" | awk 'NR==1{print$'$PIDNF'}' | xargs kill >/dev/null 2>&1 || break
done

# 保存穿透信息
echo $(date) $L4PROTO $WANADDR:$WANPORT $([ -n "$LANPORT" ] && echo '->' $OWNADDR:$LANPORT) >>$HATHDIR/$OWNNAME.log

# 获取 H@H 客户端设置信息
while [ -z $f_cname ]; do
	let GET++
 	[ $GET -gt 3 ] && logger -st $OWNNAME Failed to get the settings. Please check the PROXY. && exit 1
 	[ $GET -ne 1 ] && logger -st $OWNNAME Failed to get the settings. Wait 15 seconds ... && sleep 15
	HATHPHP=/tmp/$OWNNAME.php
	>$HATHPHP
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
ACTION() {
	ACT=$1
	ACTTIME=$(date +%s)
	ACTKEY=$(echo -n "hentai@home-$ACT--$HATHCID-$ACTTIME-$HATHKEY" | sha1sum | cut -c -40)
	curl -Ls 'http://rpc.hentaiathome.net/15/rpc?clientbuild='$BUILD'&act='$ACT'&add=&cid='$HATHCID'&acttime='$ACTTIME'&actkey='$ACTKEY''
}

# 发送 client_suspend 后，更新端口信息
# 更新后，发送 client_settings 验证端口
[ $SKIP ] || ACTION client_suspend >/dev/null
while [ ! $SKIP ]; do
	let SET++
 	[ $SET -gt 3 ] && logger -st $OWNNAME Failed to update the external port. Please check the PROXY. && exit 1
	[ $SET -ne 1 ] && logger -st $OWNNAME Failed to update the external port. Wait 15 seconds ... && sleep 15
	DATA='settings=1&f_port='$WANPORT'&f_cname='$f_cname'&f_throttle_KB='$f_throttle_KB'&f_disklimit_GB='$f_disklimit_GB''
	[ "$p_mthbwcap" = 0 ] || DATA=''$DATA'&p_mthbwcap='$p_mthbwcap''
	[ "$f_diskremaining_MB" = 0 ] || DATA=''$DATA'&f_diskremaining_MB='$f_diskremaining_MB''
	[ $f_enable_bwm ] && DATA=''$DATA'&f_enable_bwm=on'
	[ $f_disable_logging ] && DATA=''$DATA'&f_disable_logging=on'
	[ $f_use_less_memory ] && DATA=''$DATA'&f_use_less_memory=on'
	[ $f_is_hathdler ] && DATA=''$DATA'&f_is_hathdler=on'
	curl $PROXY -Ls -m 15 \
	-b 'ipb_member_id='$EHIPBID'; ipb_pass_hash='$EHIPBPW'' \
	-o $HATHPHP \
	-d ''$DATA'' \
	'https://e-hentai.org/hentaiathome.php?cid='$HATHCID'&act=settings'
	[ $(ACTION client_settings | grep port=$WANPORT) ] && \
	logger -st $OWNNAME The external port $WANPORT/tcp is updated successfully. && break
done

# 发送 client_start 后，检测是否需要启动 H@H 客户端
# 若客户端已启动，则自动恢复连接，无需重启
# 若客户端未启动，client_suspend 与 client_start 不会造成实质影响
[ $SKIP ] || ACTION client_start >/dev/null
if [ $HATHDIR != /tmp ]; then
	if screen -v >/dev/null; then
		sleep 5 && cd $HATHDIR
		screen -ls | grep $OWNNAME || \
		screen -dmS $OWNNAME java -jar $HATHDIR/HentaiAtHome.jar --port=$APPPORT
	else
		logger -st $OWNNAME Please install screen.
	fi
fi

logger -st $OWNNAME Now please confirm if the client is running correctly.
