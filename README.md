# 介绍

Linux（特别是 OpenWrt，包括 WSL2）下通过 [NATMap](https://github.com/heiher/natmap) 或 [Lucky](https://lucky666.cn/) 进行内网穿透后，调用通知脚本修改 [H@H](https://ehwiki.org/wiki/Hentai@Home) 客户端的公网端口

需要安装 [curl](https://curl.se/)，OpenWrt 下需要安装 `coreutils-sha1sum`

~~[详细说明](https://www.bilibili.com/read/cv35051332/)~~（内容已过时）

~~[Windows 脚本使用教程](https://www.bilibili.com/read/cv36825243/)~~（内容已过时）

## 注意事项

**通知脚本与 H@H 客户端脱离**，可运行在同一设备上，也可运行在不同的设备上

**通知脚本更新端口后，无需重启客户端**

但需要注意的是，必须在首次穿透成功后再启动 H@H 客户端，否则无法完成初始化，客户端将拒绝连接请求

**通知脚本不启动 H@H 客户端**，请自行在运行设备上启动

启动命令末尾加上参数 `--port=<port>`，指定客户端的本地监听端口

Windows：编辑 `autostartgui.bat`

`@start javaw -Xms16m -Xmx512m -jar HentaiAtHomeGUI.jar --silentstart --port=44388`

Linux: 建议使用 [screen](https://www.gnu.org/software/screen/)

`screen -dmS hath java -jar /mnt/sda1/HentaiAtHome.jar --port=44388`

注意 `HentaiAtHome.jar` 的实际路径

# 准备工作

## 端口映射

本脚本不再自动配置端口映射，请手动操作

建议使用路由器的端口映射（或叫“**虚拟服务器**”），本文档示例使用 **OpenWrt**

本脚本使用的默认端口

* `外部端口`：`44377`
  
  对应 **NATMap** 中的 **绑定端口** 或 **Lucky** 中的 **穿透通道本地端口**
  
* `内部端口`：`44388`

  H@H 客户端的本地监听端口，对应启动参数 `--port=<port>`

`内部 IP 地址` 即 H@H 客户端运行设备的 IPv4 地址

![图片](https://github.com/user-attachments/assets/7dca081d-c226-4c2c-bbf3-c0931603d631)

---

**OpenWrt** 上配置端口映射时，`目标区域` 与 `内部 IP 地址` 留空则代表路由器自身

![图片](https://github.com/user-attachments/assets/9c7cfb82-eedb-4dd0-a19c-f143b7e71d74)

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

由于用户态转发uhi改变数据包源地址，需要在 H@H 客户端的启动参数中加上 `--disable-ip-origin-check `

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
opkg install curl coreutils-sha1sum luci-app-natmap
```

## Debian

```
apt update
apt install curl
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

### OpenWrt

#### 配置脚本

把脚本下载到本地，赋予执行权限并编辑变量

```
curl -Lso /usr/stun_hath.sh stun-hath.pages.dev/natmap
# 如下载失败，请使用国内镜像
# curl -Lso /usr/stun_hath.sh https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath.sh
chmod +x /usr/stun_hath.sh
vi /usr/stun_hath.sh
```

```
# 以下变量需按要求填写
PROXY=socks5://192.168.1.168:10808          # 可用的代理协议、地址与端口；留空则不使用代理
IFNAME=                                     # 指定接口，默认留空；仅多 WAN 时需要，仅 AUTONAT=1 时生效；拨号接口的格式为 "pppoe-wancm"
AUTONAT=1                                   # 默认由脚本自动配置 DNAT；0 为手动配置，需要固定本地端口 (LANPORT)
GWLADDR=192.168.1.1                         # 主路由 LAN 的 IPv4 地址
APPADDR=192.168.1.168                       # H@H 客户端运行设备的 IPv4 地址，可以是主路由本身
APPPORT=44388                               # H@H 客户端的本地监听端口，对应启动参数 --port=<port>
HATHCID=12345                               # H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE                # H@H 客户端密钥 (Client Key)
EHIPBID=1234567                             # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef    # ipb_pass_hash
INFODIR=/tmp                                # 穿透信息保存目录，默认为 /tmp
```

#### 配置 NATMap

![图片](https://github.com/user-attachments/assets/ed87788e-6a9f-45a2-ac67-833a2bcb5945)

或可编辑配置文件 `vi /etc/config/natmap`

**注意实际的接口名称**

```
config natmap
	option udp_mode '0'
	option family 'ipv4'
	option interface 'wancm'
	option interval '25'
	option stun_server 'turn.cloudflare.com'
	option http_server 'qq.com'
	option port '44377'
	option notify_script '/usr/stun_hath.sh'
	option enable '1'
```

### Debian

`natmap -d -4 -k 25 -s turn.cloudflare.com -h qq.com -e "/usr/stun_hath.sh"`

可添加自启动，具体方法因发行版而异

## Lucky (Linux)

![QQ20241025-1158542](https://github.com/user-attachments/assets/0bcac64d-0165-4605-905d-66e151481549)

自定义脚本内容如下，请正确编辑变量内容

```
LANPORT=44377                             # 穿透通道本地端口
GWLADDR=192.168.1.1                       # 主路由 LAN 的 IPv4 地址
APPADDR=192.168.1.168	                  # H@H 客户端运行设备的 IPv4 地址，可以是主路由本身
APPPORT=44388                             # H@H 客户端的监听端口，对应启动参数 --port=<port>
HATHCID=12345                             # H@H 客户端 ID (Client ID)
HATHKEY=12345abcde12345ABCDE              # H@H 客户端密钥 (Client Key)
EHIPBID=1234567                           # ipb_member_id
EHIPBPW=0123456789abcdef0123456789abcdef  # ipb_pass_hash
INFODIR=/tmp                              # 穿透信息保存目录，默认为 /tmp
PROXY=socks5://192.168.1.168:10808        # 可用的代理协议、地址与端口；留空则不使用代理
AUTONAT=1                                 # 默认由脚本自动配置 DNAT；0 为手动配置，需要固定本地端口 (LANPORT)
IFNAME=                                   # 指定接口，默认留空；仅多 WAN 时需要，仅 AUTONAT=1 时生效；拨号接口的格式为 "pppoe-wancm"

[ -e /usr/stun_hath_lucky.sh ] || curl -Lso /usr/stun_hath_lucky.sh https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath_lucky2.sh
sh /usr/stun_hath_lucky.sh ${ip} ${port} $LANPORT $GWLADDR $APPADDR $APPPORT $HATHCID $HATHKEY $EHIPBID $EHIPBPW $INFODIR $PROXY $AUTONAT $IFNAME
```

默认使用国内镜像，脚本地址可改为 `stun-hath.pages.dev/lucky`

需要注意，Lucky 指定接口需要开启定制模式

## Lucky (Windows)

![图片](https://github.com/user-attachments/assets/f6edc1fb-8135-49a4-8e0b-840f5a10cbee)

自定义脚本内容如下，请正确编辑变量内容

```
set PROXY=socks5://192.168.1.168:10808        :: 可用的代理协议、地址与端口；留空则不使用代理
set HATHDIR=D:\HentaiAtHome                   :: H@H 客户端所在路径；留空则不自动执行（非本机客户端请留空）
set APPPORT=44388                             :: H@H 客户端的监听端口，对应启动参数 --port=<port>
set HATHCID=12345                             :: H@H 客户端 ID (Client ID)
set HATHKEY=12345abcde12345ABCDE              :: H@H 客户端密钥 (Client Key)
set EHIPBID=1234567                           :: ipb_member_id
set EHIPBPW=0123456789abcdef0123456789abcdef  :: ipb_pass_hash

if NOT EXIST %HATHDIR% set HATHDIR=%TEMP%
if NOT EXIST %HATHDIR%\stun_hath.cmd ^
curl -Lso %HATHDIR%\stun_hath.cmd https://gitee.com/oniicyan/stun_hath/raw/master/stun_hath.cmd

%HATHDIR%\stun_hath.cmd ${ip} ${port} %APPPORT% %HATHCID% %HATHKEY% %EHIPBID% %EHIPBPW% %HATHDIR% %PROXY%
```

默认使用国内镜像，脚本地址可改为 `stun-hath.pages.dev/cmd`

## 自启方案

### Linux

使用 Screen 时，可使用以下命令在 H@H 未检测到运行时启动

```
screen -ls | grep hath || \
screen -dmS hath java -jar /mnt/sda1/HentaiAtHome.jar --port=44388
```

* 使用 NATMap 的，可添加在**脚本文件**的最后
* 使用 Lucky 的，可加在**自定义脚本**的最后
