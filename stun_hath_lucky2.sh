# 从 Lucky 自定义命令中传递参数
WANADDR=$1		# 公网地址
WANPORT=$2		# 公网端口
LANPORT=$3		# 穿透通道本地端口
L4PROTO=tcp
OWNADDR=		# Lucky 不传递穿透通道本地地址，留空

GWLADDR=$4		# 主路由 LAN 的 IPv4 地址
APPADDR=$5		# H@H 客户端运行设备的 IPv4 地址，可以是主路由本身
APPPORT=$6		# H@H 客户端的监听端口，对应 --port= 参数
HATHCID=$7		# H@H 客户端 ID (Client ID)
HATHKEY=$8		# H@H 客户端密钥 (Client Key)
EHIPBID=$9		# ipb_member_id
EHIPBPW=${10}	# ipb_pass_hash
INFODIR=${11}	# 穿透信息保存目录，默认为 /tmp

if echo ${12} | grep '://' >/dev/null; then
	PROXY=${12}		# 可用的代理协议、地址与端口；留空则不使用代理
	IFNAME=${13}	# 指定接口，默认留空；仅在多 WAN 时需要；拨号接口的格式为 "pppoe-wancm"
else
	IFNAME=${12}
fi

OWNNAME=$(echo stun_hath_${APPADDR}_${APPPORT}$([ -n "$IFNAME" ] && echo @$IFNAME) | sed 's/[[:punct:]]/_/g')
RELEASE=$(grep ^ID= /etc/os-release | awk -F '=' '{print$2}' | tr -d \")

[ -n "$PROXY" ] && PROXY=$(echo -x $PROXY)

# 防止脚本重复运行
PIDNF=$( ( ps aux 2>/dev/null; ps ) | awk '{for(i=1;i<=NF;i++)if($i=="PID")n=i}NR==1{print n}' )
while :; do
  ( ps aux 2>/dev/null; ps ) | grep $0 | grep -v -e "$$\|grep" | awk 'NR==1{print$'$PIDNF'}' | xargs kill >/dev/null 2>&1 || break
done

# 保存穿透信息
echo $L4PROTO $WANADDR:$WANPORT '->' $OWNADDR:$LANPORT $(date +%s) >$INFODIR/$OWNNAME.info
echo $(date) $L4PROTO $WANADDR:$WANPORT '->' $OWNADDR:$LANPORT >>$INFODIR/$OWNNAME.log

# 若 H@H 运行在主路由上，则添加 DNAT 规则
# 系统为 OpenWrt，且未指定 IFNAME 时，使用 uci
# 其他情况使用 nft，并检测是否需要填充 uci
SETDNAT() {
	nft delete rule ip STUN DNAT handle $(nft -a list chain ip STUN DNAT 2>/dev/null | grep \"$OWNNAME\" | awk '{print$NF}') 2>/dev/null
	iptables -t nat $(iptables-save | grep $OWNNAME | sed 's/-A/-D/') 2>/dev/null
	if [ "$RELEASE" = "openwrt" ] && [ -z "$IFNAME" ]; then
		nft delete rule ip STUN DNAT handle $(nft -a list chain ip STUN DNAT 2>/dev/null | grep \"$OWNNAME\" | awk '{print$NF}') 2>/dev/null
		uci -q delete firewall.stun_foo
		uci -q delete firewall.$OWNNAME
		uci set firewall.$OWNNAME=redirect
		uci set firewall.$OWNNAME.name=${OWNNAME}_$LANPORT'->'$APPPORT
		uci set firewall.$OWNNAME.src=wan
		uci set firewall.$OWNNAME.proto=tcp
		uci set firewall.$OWNNAME.src_dport=$LANPORT
		uci set firewall.$OWNNAME.dest_port=$APPPORT
		[ "$GWLADDR" != "$APPADDR" ] && \
		uci set firewall.$OWNNAME.dest='lan' && \
		uci set firewall.$OWNNAME.dest_ip=$APPADDR
		uci commit firewall
		/etc/init.d/firewall reload >/dev/null 2>&1
		UCI=1
	elif nft -v >/dev/null 2>&1; then
		[ -n "$IFNAME" ] && IIFNAME="iifname $IFNAME"
		nft add table ip STUN
		nft add chain ip STUN DNAT { type nat hook prerouting priority dstnat \; }
		if [ "$GWLADDR" != "$APPADDR" ]; then
			nft insert rule ip STUN DNAT $IIFNAME tcp dport $LANPORT counter dnat to $APPADDR:$APPPORT comment $OWNNAME
		else
			nft insert rule ip STUN DNAT $IIFNAME tcp dport $LANPORT counter redirect to :$APPPORT comment $OWNNAME
		fi
	elif iptables -V >/dev/null 2>&1; then
		[ -n "$IFNAME" ] && IIFNAME="-i $IFNAME"
		if [ "$GWLADDR" != "$APPADDR" ]; then
			iptables -t nat -I PREROUTING $IIFNAME -p tcp --dport $LANPORT -m comment --comment $OWNNAME -j DNAT --to-destination $APPADDR:$APPPORT
		else
			iptables -t nat -I PREROUTING $IIFNAME -p tcp --dport $LANPORT -m comment --comment $OWNNAME -j REDIRECT --to-ports $APPPORT
		fi
	fi
	if [ "$RELEASE" = "openwrt" ] && [ "$UCI" != 1 ]; then
		uci -q delete firewall.stun_foo && RELOAD=1
		uci -q delete firewall.$OWNNAME && RELOAD=1
		if uci show firewall | grep =redirect >/dev/null; then
			for CONFIG in $(uci show firewall | grep =redirect | awk -F = '{print$1}'); do
				[ "$(uci -q get $CONFIG.src)" = "wan" ] && [ "$(uci -q get $CONFIG.enabled)" != 0 ] && \
				RULE=1 && break
			done
		fi
		if [ "$RULE" != 1 ]; then
			uci set firewall.stun_foo=redirect
			uci set firewall.stun_foo.name=stun_foo
			uci set firewall.stun_foo.src=wan
			uci set firewall.stun_foo.mark=$RANDOM
			RELOAD=1
		fi
		uci commit firewall
		[ "$RELOAD" = 1 ] && /etc/init.d/firewall reload >/dev/null 2>&1
	fi
	DNAT=1
}
for LANADDR in $(ip -4 a | grep inet | awk '{print$2}' | awk -F '/' '{print$1}'); do
	[ "$DNAT" = 1 ] && break
	[ "$LANADDR" = $GWLADDR ] && SETDNAT
done
for LANADDR in $(nslookup -type=A $HOSTNAME | grep Address | grep -v -e ':\d' | awk '{print$2}'); do
	[ "$DNAT" = 1 ] && break
	[ "$LANADDR" = $GWLADDR ] && SETDNAT
done

# 若 H@H 运行在主路由下，则通过 UPnP 请求规则
if [ "$DNAT" != 1 ]; then
	nft delete rule ip STUN DNAT handle $(nft -a list chain ip STUN DNAT 2>/dev/null | grep \"$OWNNAME\" | awk '{print$NF}') 2>/dev/null
	iptables -t nat $(iptables-save | grep $OWNNAME | sed 's/-A/-D/') 2>/dev/null
	[ "$RELEASE" = "openwrt" ] && uci -q delete firewall.$OWNNAME
	upnpc -i -e "STUN HATH $WANPORT->$LANPORT->$APPPORT" -a @ $APPPORT $LANPORT tcp >/dev/null 2>&1 &
fi

# 获取 H@H 设置信息
while [ -z "$f_cname" ]; do
	let GET++
 	if [ $GET -gt 3 ]; then
  		echo -n $OWNNAME: Failed to get settings. Please check the PROXY. >&2
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
# 更新后，发送 client_login 验证端口
ACTION client_suspend >/dev/null
while :; do
	let SET++
 	if [ $SET -gt 3 ]; then
  		echo -n $OWNNAME: Failed to update port. Please check the PROXY. >&2
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
	ACTION client_settings | grep port=$WANPORT >/dev/null && break
done

# 发送 client_resume 后，直接退出
# 若客户端已启动，将在下次 Check-In 时恢复连接，无需重启
# 若客户端未启动，client_suspend 与 client_resume 不会有任何实质影响
# 本脚本不启动 H@H 客户端，请在首次穿透后，自行在运行设备上启动
# 启动命令末尾加上参数 --port=44388，固定内部监听端口
ACTION client_resume >/dev/null &

echo -n $OWNNAME: The external port is updated successfully.
