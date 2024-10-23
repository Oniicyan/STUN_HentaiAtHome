## 介绍

Linux（特别是 OpenWrt，包括 WSL2）下通过 [NATMap](https://github.com/heiher/natmap) 或 [Lucky](https://lucky666.cn/) 进行内网穿透后，调用通知脚本修改端口设置并运行 [H@H](https://ehwiki.org/wiki/Hentai@Home) 客户端

需要安装 [curl](https://curl.se/) 与 [screen](https://www.gnu.org/software/screen/)，以及 [JRE](https://docs.oracle.com/goldengate/1212/gg-winux/GDRAD/java.htm)

运行在非主路由时，还需要安装 [miniupnpc](http://miniupnp.free.fr/)

热更新脚本还需要安装 coreutils-sha1sum

[详细说明](https://www.bilibili.com/read/cv35051332/)

[Windows 脚本使用教程](https://www.bilibili.com/read/cv36825243/)

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

网络脚本如要更换代理，请把最后一行改为以下，注意编辑协议、地址与端口

`sh <(curl -Ls stun-hath.pages.dev | sed 's/h.*3/socks5:\/\/192.168.1.1:10808/') ${ip} ${port} $LANPORT $GWLADDR $HATHDIR $HATHCID $EHIPBID $EHIPBPW $IFNAME`

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

**请注意编辑脚本及输出文本的路径**

打开输出文本 `debug.txt`，确认开头的每个变量是否正确，以及 `curl` 提交数据时内容是否对应穿透信息

### Windows 脚本

下载并解压 **stun_hath.zip** 或 **stun_hath_win32.zip** 的内容到 H@H 所在目录

也可自行下载 [handle.exe](https://learn.microsoft.com/en-us/sysinternals/downloads/handle)、[windows-kill.exe](https://github.com/ElyDotDev/windows-kill)、[upnpc.exe](https://github.com/miniupnp/miniupnp)、[stun_hath.cmd](https://github.com/Oniicyan/STUN_HentaiAtHome/blob/main/stun_hath.cmd)

Lucky 中添加以下自定义脚本，注意编辑变量

```
set LANPORT=12345
set HATHDIR=D:\HentaiAtHome
set HATHCID=12345
set EHIPBID=1234567
set EHIPBPW=0123456789abcdef0123456789abcdef

set OUTPUT=%TEMP%\stun_hath.%RANDOM%%RANDOM%
echo createobject^("wscript.shell"^).run "%HATHDIR%\stun_hath.cmd ${ip} ${port} %LANPORT% %HATHDIR% %HATHCID% %EHIPBID% %EHIPBPW% >%OUTPUT%",0 >%TEMP%\stun_hath.vbs
%TEMP%\stun_hath.vbs
echo %OUTPUT%
```

Windows 脚本调试打开用户临时文件夹（`%TEMP%`），找到 `stun_hath.12345678`

--------------------------------------------------------

## 获取信息失败

若因某些问题导致无法获取设置信息，可手动填写

找到获取 H@H 设置信息的部分并改为以下内容

```
# 获取 H@H 设置信息
# 获取失败时，手动填写信息
# 以下 3 个为必须参数，需要填写
f_cname=New+Client        # 客户端名称，空格换成 + 号
f_throttle_KB=25000       # 上行带宽配额，单位是 KB
f_disklimit_GB=1000       # 磁盘空间配额，单位是 GB
# 以下为可选参数
p_mthbwcap=0            # 每月流量上限，单位是 GB，默认为 0，即无限制；不可注释或删除本行
f_diskremaining_MB=0    # 剩余空间保证，单位是 MB，默认为 0，即无限制；不可注释或删除本行
f_enable_bwm=           # 启用客户端侧限速，默认关闭，开启时输入 on 或任意字符
f_disable_logging=      # 禁用日志，默认关闭，开启时输入 on 或任意字符
f_use_less_memory=      # 低内存模式，默认关闭，开启时输入 on 或任意字符
f_is_hathdler=          # 作为默认下载器，默认关闭，开启时输入 on 或任意字符
```
