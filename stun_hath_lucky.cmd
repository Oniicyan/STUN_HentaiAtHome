:: 以下变量需要填写
set LANPORT=12345
set HATHDIR=D:\HentaiAtHome
set HATHCID=12345
set EHIPBID=1234567
set EHIPBPW=0123456789abcdef0123456789abcdef

:: 公共代理，不保证质量
:: 建议自行指定，注意格式
set PROXY=http://jpfhDg:qawsedrftgyhujikolp@hathproxy.ydns.eu:14913

setlocal enabledelayedexpansion
cd /D %HATHDIR%
set WANADDR=${ip}
set WANPORT=${port}
set RETRY=0

:: 获取上次穿透的时间戳
set OLDTIME=none
if EXIST stun_hath.info (
	for /F "tokens=4" %%a in (stun_hath.info) do (set OLDPORT=%%a)
	for /F "tokens=8" %%a in (stun_hath.info) do (set OLDTIME=%%a)
)

:: 生成时间戳并保存穿透信息
for /F "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do (
	for /F "tokens=1 delims=." %%b in ("%%a") do (set NOWTIME=%%b)
)
echo tcp %WANADDR% : %WANPORT% -^> : %LANPORT% %NOWTIME% >stun_hath.info
echo %date%%time% tcp %WANADDR% : %WANPORT% -^> : %LANPORT% >>stun_hath.log

:: 确保与上次穿透相隔 1 分钟以上
echo %OLDTIME%| findstr "^[0-9]*$" >nul &&^
if %OLDTIME:~,10%==%NOWTIME:~,10% (
	set /A CMPTIME=1%NOWTIME:~8,4%-1%OLDTIME:~8,4%
	if NOT !CMPTIME! GTR 1 (choice /D Y /T 60 >nul)
)

:RETRY

:: 获取 H@H 设置信息
del stun_hath.php 2>nul
curl -s -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"
for /F tokens^=6^ delims^=^" %%a in ('findstr f_cname stun_hath.php') do (set f_cname=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_throttle_KB stun_hath.php') do (set f_throttle_KB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_disklimit_GB stun_hath.php') do (set f_disklimit_GB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr p_mthbwcap stun_hath.php') do (set p_mthbwcap=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_diskremaining_MB stun_hath.php') do (set f_diskremaining_MB=%%a)

:: 停止 H@H，等待 30 秒
for /F "tokens=3" %%a in ('handle.exe -y -nobanner -accepteula %HATHDIR%\HentaiAtHomeGUI.jar') do (windows-kill.exe -SIGINT %%a >nul)
choice /D Y /T 30 >nul

:: 更新 H@H 端口信息
set DATA="settings=1&f_port=%WANPORT%&f_cname=%f_cname: =+%&f_throttle_KB=%f_throttle_KB%&f_disklimit_GB=%f_disklimit_GB%"
if NOT %p_mthbwcap%==0 set DATA="%DATA:"=%&p_mthbwcap=%p_mthbwcap%"
if NOT %f_diskremaining_MB%==0 set DATA="%DATA:"=%&f_diskremaining_MB=%f_diskremaining_MB%"
findstr f_enable_bwm stun_hath.php | findstr checked >nul &&^
set DATA="%DATA:"=%&f_enable_bwm=on"
findstr f_disable_logging stun_hath.php | findstr checked >nul &&^
set DATA="%DATA:"=%&f_disable_logging=on"
findstr f_use_less_memory stun_hath.php | findstr checked >nul &&^
set DATA="%DATA:"=%&f_use_less_memory=on"
findstr f_is_hathdler stun_hath.php | findstr checked >nul &&^
set DATA="%DATA:"=%&f_is_hathdler=on"
curl -s -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
-d %DATA% ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"

:: UPnP 失败则使用 PORTPROXY
upnpc.exe -i -d %LANPORT% tcp >nul
upnpc.exe -i -e "STUN HATH %WANPORT%->%LANPORT%->%WANPORT%" -a @ %WANPORT% %LANPORT% tcp >nul
if NOT %ERRORLEVEL%==0 (
	netsh interface portproxy delete v4tov4 %LANPORT% >nul
	netsh interface portproxy set v4tov4 %LANPORT% * %WANPORT% >nul
)

:: 启动 H@H
del .\log\log_out >nul 2>&1
start javaw -Xms16m -Xmx512m -jar HentaiAtHomeGUI.jar --silentstart
choice /D Y /T 60 >nul
findstr /C:"initialization completed successfully" .\log\log_out >nul 2>&1 &&^
echo HentaiAtHome ok. && exit
choice /D Y /T 60 >nul
curl -s -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o %TEMP%\hentaiathome.php ^
"https://e-hentai.org/hentaiathome.php"
findstr Online %TEMP%\hentaiathome.php >nul &&^
echo HentaiAtHome ok. && exit
if %RETRY% GEQ 3 exit
choice /D Y /T 300 >nul
set /A RETRY=%RETRY%+1
goto RETRY
