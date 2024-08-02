Linux（特别是 OpenWrt，包括 WSL2）下通过 [NATMap](https://github.com/heiher/natmap) 进行内网穿透后，调用通知脚本修改端口设置并运行 [H@H](https://ehwiki.org/wiki/Hentai@Home) 客户端

需要安装 [curl](https://curl.se/) [screen](https://www.gnu.org/software/screen/) [miniupnpc](http://miniupnp.free.fr/)，以及 [JRE](https://docs.oracle.com/goldengate/1212/gg-winux/GDRAD/java.htm)

[详细说明](https://www.bilibili.com/read/cv35051332/)

使用 Lucky 进行穿透时，粘贴并正确编辑以下自定义脚本

```
LANPORT=12345        # 穿透通道本地端口
GWLADDR=192.168.1.1  # 主路由 LAN 的 IPv4 地址
HATHDIR=/mnt/hath    # H@H 所在目录
HATHCID=12345        # H@H 的客户端 ID
EHIPBID=1234567      # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash
IFNAME=              # 指定接口，可留空；仅在多 WAN 时需要；拨号接口的格式为 "pppoe-wancm"

sh <(curl -Ls https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath_lucky.sh) $ip $port $LANPORT $GWLADDR $HATHDIR $HATHCID $EHIPBID $EHIPBPW $IFNAME

echo -n HentaiAtHome OK.
```

**如要指定接口，请确认在 Lucky 的 STUN 穿透中选择定制模式并正确指定 IP 或网卡**

示例中使用网络脚本

可把脚本存放到本地，也可把完整脚本内容粘贴到自定义脚本框中
