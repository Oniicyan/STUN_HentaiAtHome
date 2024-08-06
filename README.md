## 介绍

Linux（特别是 OpenWrt，包括 WSL2）下通过 [NATMap](https://github.com/heiher/natmap) 进行内网穿透后，调用通知脚本修改端口设置并运行 [H@H](https://ehwiki.org/wiki/Hentai@Home) 客户端

需要安装 [curl](https://curl.se/) 与 [screen](https://www.gnu.org/software/screen/)，以及 [JRE](https://docs.oracle.com/goldengate/1212/gg-winux/GDRAD/java.htm)

运行在非主路由时，还需要安装 [miniupnpc](http://miniupnp.free.fr/)

[详细说明](https://www.bilibili.com/read/cv35051332/)

## Lucky

使用 Lucky 进行穿透时，粘贴并正确编辑以下自定义脚本

### 网络脚本

在自定义命令中，通过网络获取在线获取脚本并传递参数执行

```
LANPORT=12345        # 穿透通道本地端口
GWLADDR=192.168.1.1  # 主路由 LAN 的 IPv4 地址
HATHDIR=/mnt/hath    # H@H 所在目录
HATHCID=12345        # H@H 的客户端 ID
EHIPBID=1234567      # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash
IFNAME=              # 指定接口，可留空；仅在多 WAN 时需要；拨号接口的格式为 "pppoe-wancm"

sh <(curl -Ls stun-hath.pages.dev) ${ip} ${port} $LANPORT $GWLADDR $HATHDIR $HATHCID $EHIPBID $EHIPBPW $IFNAME
```

--------------------------------------------------------

**如要指定接口，请配置页中选择定制模式并正确指定 IP 或网卡**

--------------------------------------------------------

### 本地脚本

把脚本下载到本地，事先编辑好开头部分除了 `WANADDR` 与 `WANPORT` 之外的变量值

Lucky 中使用以下自定义命令，**注意编辑脚本路径**

由于本地脚本中已编辑好变量，因此只需要一行命令

Lucky 变量 `${ip}` `${port}` 不可省略大括号

```
sh /mnt/hath/stun_hath_lucky.sh ${ip} ${port}
```

也可把脚本直接粘贴到自定义脚本框中修改变量值，注意此时的 `WANADDR` 与 `WANPORT`

```
# 公共代理，不保证质量
PROXY='http://jpfhDg:qawsedrftgyhujikolp@hathproxy.ydns.eu:14913'

# 使用网络脚本时，从 Lucky 自定义命令中传递参数
# 使用本地脚本时，请事先修改好变量值
IFNAME=              # 指定接口，可留空；仅在多 WAN 时需要；拨号接口的格式为 "pppoe-wancm"
GWLADDR=192.168.1.1  # 主路由 LAN 的 IPv4 地址
HATHDIR=/mnt/hath    # H@H 所在目录
HATHCID=12345        # H@H 的客户端 ID
EHIPBID=1234567      # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash

WANADDR=${ip}
WANPORT=${port}
LANPORT=12345        # 穿透通道本地端口
L4PROTO=tcp
OWNADDR=             # Lucky 不传递穿透通道本地地址，留空

    ...... 剩余脚本内容 ......
```

**需要使用自己的代理时，请使用本地脚本并修改 PROXY 变量值**

### 调试脚本

若发现 H@H 启动不成功，可把自定义脚本的最后一行改为

`sh -x <(curl -Ls stun-hath.pages.dev) ${ip} ${port} $LANPORT $GWLADDR $HATHDIR $HATHCID $EHIPBID $EHIPBPW $IFNAME 2>/mnt/hath/debug.txt`

或

`sh -x /mnt/hath/stun_hath_lucky.sh ${ip} ${port} 2>/mnt/hath/debug.txt`

请注意编辑脚本及输出文本的路径

打开输出文本 `debug.txt`，确认开头的每个变量是否正确，以及 `curl` 提交数据时内容是否对应穿透信息
