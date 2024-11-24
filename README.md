# 介绍

Linux（特别是 OpenWrt，包括 WSL2）或 Windows 下通过 [NATMap](https://github.com/heiher/natmap) 或 [Lucky](https://lucky666.cn/) 进行内网穿透后，调用通知脚本修改 [H@H](https://ehwiki.org/wiki/Hentai@Home) 客户端的公网端口

需要安装 [curl](https://curl.se/)（Windows 10 以后自带）

OpenWrt 下需要安装 `coreutils-sha1sum`

Linux 下如需自动启动 H@H 客户端，需要安装 [Screen](https://www.gnu.org/software/screen/) 与 [JRE](https://docs.oracle.com/goldengate/1212/gg-winux/GDRAD/java.htm)

~~[详细说明](https://www.bilibili.com/read/cv35051332/)~~（内容已过时）

~~[Windows 脚本使用教程](https://www.bilibili.com/read/cv36825243/)~~（内容已过时）

## 注意事项

**通知脚本与 H@H 客户端脱离**，可运行在同一设备上，也可运行在不同的设备上

**通知脚本更新端口后，无需重启客户端**

但需要注意的是，必须在首次穿透成功后再启动 H@H 客户端，否则无法完成初始化，客户端将拒绝连接请求

**若通知脚本与 H@H 客户端运行在不同设备上**，请自行启动

启动命令末尾加上参数 `--port=<port>`，指定客户端的本地监听端口

Windows: 编辑 `autostartgui.bat`

`@start javaw -Xms16m -Xmx512m -jar HentaiAtHomeGUI.jar --silentstart --port=44388`

Linux: 建议使用 `screen`

`screen -dmS hath java -jar /mnt/sda1/HentaiAtHome.jar --port=44388`

注意 `HentaiAtHome.jar` 的实际路径

# 准备工作

## 端口映射

本脚本不再自动配置端口映射，请手动操作

建议使用路由器的端口映射（或叫“**虚拟服务器**”），本文档示例使用 **OpenWrt**

### OpenWrt

![图片](https://github.com/user-attachments/assets/6d547218-5a66-4c0f-9786-2eb33aa7b5e1)

* `地址族限制`：`仅 IPv4`

  仅针对 IPv4 进行穿透，并非所有路由器都有此选项

* `协议`：`TCP`

* `外部端口`：`44377`
  
  对应 **NATMap** 中的 **绑定端口** 或 **Lucky** 中的 **穿透通道本地端口**

* `内部 IP 地址`

  H@H 客户端运行设备的 IPv4 地址
  
* `内部端口`：`44388`

  H@H 客户端的本地监听端口，对应启动参数 `--port=<port>`

---

**OpenWrt** 上配置端口映射时，`目标区域` 与 `内部 IP 地址` 留空则代表路由器自身

![图片](https://github.com/user-attachments/assets/f7c3074c-3f00-4255-9604-839e267301b2)

保存后如下

![图片](https://github.com/user-attachments/assets/7a0582fc-4e5d-4ff8-bbd5-4c6a0548c1ab)

### nftables / iptables

在需要指定网络接口，或需要在其他 Linux 发行版上配置端口映射时，可使用 `nft` 或 `iptables`

* nftables
  
```
# 创建 table 与 chain
nft add table ip STUN
nft add chain ip STUN DNAT { type nat hook prerouting priority dstnat \; }
# 转发至其他设备，使用 dnat
nft insert rule ip STUN DNAT iifname pppoe-wancm tcp dport 44377 counter dnat to 192.168.1.168:44388 comment stun_hath
# 转发至本设备，使用 redirect
nft insert rule ip STUN DNAT iifname pppoe-wancm tcp dport 44377 counter redirect to :44388 comment stun_hath
```

* iptables

```
# 转发至其他设备，使用 DNAT
iptables -t nat -I PREROUTING -i pppoe-wancm -p tcp --dport 44377 -m comment --comment stun_hath -j DNAT --to-destination 192.168.1.168:44388
# 转发至本设备，使用 REDIRECT
iptables -t nat -I PREROUTING -i pppoe-wancm -p tcp --dport 44377 -m comment --comment stun_hath -j REDIRECT --to-ports 44388
```

### 用户态转发

建议仅在无法对路由器配置端口映射时，才使用 Lucky 或其他用户态端口转发工具

由于用户态转发会改变数据包源地址，需要在 H@H 客户端的启动参数中加上 `--disable-ip-origin-check `

## 获取账号 Cookie

登录 E-Hentai 后，按 `F12` 打开浏览器开发人员工具，抓取网络通信

在 E-Hentai 的任意页面按 `Ctrl + R` 键刷新，点击捕获到的请求并下拉

从 `Cookie` 项目中复制 `ipb_member_id` 与 `ipb_pass_hash`

![图片](https://github.com/user-attachments/assets/fe5a99a3-238f-45e2-afdb-426c83a70e9b)

---

## 获取 H@H 的 ID 与密钥

打开 https://e-hentai.org/hentaiathome.php 点击你申请到的 H@H 客户端详情

记下在顶部显示的 `Client ID` 与 `Client Key`

![图片](https://github.com/user-attachments/assets/ebf88a7b-a639-456c-a95a-d2dabbeb210d)

# 安装软件

## OpenWrt

```
# 可选替换国内软件源
# sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf
opkg update
opkg install curl coreutils-sha1sum screen luci-app-natmap
```

[OpenWrt 下安装 Java 运行环境（JRE）](https://www.bilibili.com/read/cv35593253)

## Debian

```
apt update
apt install curl screen openjdk-17-jdk-headless
```

NATMap 需手动安装，注意指令集架构

```
curl -Lo /usr/bin/natmap https://github.com/heiher/natmap/releases/download/20240813/natmap-linux-x86_64
chmod +x /usr/bin/natmap
```

---

Lucky 的安装方法请参照 [官网文档](https://lucky666.cn/docs/install)

# 配置方法

## NATMap

### 配置脚本

把脚本下载到本地，赋予执行权限并编辑变量

```
curl -Lso /usr/stun_hath_natmap.sh stun-hath.pages.dev/natmap
# 如下载失败，请使用国内镜像
# curl -Lso /usr/stun_hath_natmap.sh https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath_natmap.sh
chmod +x /usr/stun_hath_natmap.sh
vi /usr/stun_hath_natmap.sh
```

```
# 以下变量需按要求填写
PROXY=socks5://192.168.1.168:10808        # 可用的代理协议、地址与端口；留空则不使用代理
HATHDIR=/mnt/sda1                         # H@H 客户端所在路径；留空则不自动执行（非本机客户端请留空）
APPPORT=44388                             # H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=12345                             # H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE              # H@H 客户端密钥 (Client Key)
EHIPBID=1234567                           # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash
```

### 配置 OpenWrt

![图片](https://github.com/user-attachments/assets/e5a1cd17-8861-42c6-af31-5a53cf0ce8b7)

或可编辑配置文件 `vi /etc/config/natmap`

**注意实际的接口名称**

**如要屏蔽日志输出，需编辑配置文件**

```
config natmap
	option udp_mode '0'
	option family 'ipv4'
	option interval '25'
	option stun_server 'turn.cloudflare.com'
	option http_server 'qq.com'
	option port '44377'
	option notify_script '/usr/stun_hath_natmap.sh'
	option log_stdout '0'
	option log_stderr '0'
	option enable '1'
```

### 配置 Debian

`natmap -d -4 -k 25 -s turn.cloudflare.com -h qq.com -e "/usr/stun_hath_natmap.sh"`

可添加自启动，具体方法因发行版而异

## Lucky 

### Linux

![图片](https://github.com/user-attachments/assets/1f259450-d6f5-4b38-a8e1-30e402dbde30)

自定义脚本内容如下，请正确编辑变量内容

```
PROXY=socks5://192.168.1.168:10808        # 可用的代理协议、地址与端口；留空则不使用代理
HATHDIR=/mnt/sda1                         # H@H 客户端所在路径；留空则不自动执行（非本机客户端请留空）
APPPORT=44388                             # H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=12345                             # H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE              # H@H 客户端密钥 (Client Key)
EHIPBID=1234567                           # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash

[ -z "$HATHDIR" ] && HATHDIR=/tmp
[ -e /usr/stun_hath_lucky.sh ] || curl -Lso /usr/stun_hath_lucky.sh https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath_lucky.sh
sh /usr/stun_hath_lucky.sh ${ip} ${port} $APPPORT $HATHCID $HATHKEY $EHIPBID $EHIPBPW $HATHDIR $PROXY
```

默认使用国内镜像，脚本地址可改为 `stun-hath.pages.dev/lucky`

### Windows

![图片](https://github.com/user-attachments/assets/f6edc1fb-8135-49a4-8e0b-840f5a10cbee)

自定义脚本内容如下，请正确编辑变量内容

```
set PROXY=socks5://192.168.1.168:10808
set HATHDIR=D:\HentaiAtHome
set APPPORT=44388
set HATHCID=12345
set HATHKEY=12345abcde12345ABCDE
set EHIPBID=1234567
set EHIPBPW=0123456789abcdef0123456789abcdef

if NOT EXIST %HATHDIR% set HATHDIR=%TEMP%
if NOT EXIST %HATHDIR%\stun_hath.cmd ^
curl -Lso %HATHDIR%\stun_hath.cmd https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath.cmd

%HATHDIR%\stun_hath.cmd ${ip} ${port} %APPPORT% %HATHCID% %HATHKEY% %EHIPBID% %EHIPBPW% %HATHDIR% %PROXY%
```

默认使用国内镜像，脚本地址可改为 `stun-hath.pages.dev/cmd`

变量说明（请勿粘贴注释内容）

```
PROXY=socks5://192.168.1.168:10808        :: 可用的代理协议、地址与端口；留空则不使用代理
HATHDIR=D:\HentaiAtHome                   :: H@H 客户端所在路径；留空则不自动执行（非本机客户端请留空）
APPPORT=44388                             :: H@H 客户端的监听端口，对应启动参数 --port=<port>
HATHCID=12345                             :: H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE              :: H@H 客户端密钥 (Client Key)
EHIPBID=1234567                           :: ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  :: ipb_pass_hash
```

---

需要调试时，请把最后一行改为

`%HATHDIR%\stun_hath.cmd ${ip} ${port} %APPPORT% %HATHCID% %HATHKEY% %EHIPBID% %EHIPBPW% %HATHDIR% %PROXY% >%HATHDIR%\stun_hath.log 2>&1`

将会在 H@H 目录或临时文件夹输出 `stun_hath.log`，包含实际执行的命令及结果
