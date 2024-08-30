:: 公共代理，不保证质量
:: 建议自行指定，注意格式
set PROXY=http://jpfhDg:qawsedrftgyhujikolp@hathproxy.ydns.eu:14913

:: 由穿透工具传递参数，注意顺序
set WANADDR=%1
set WANPORT=%2
set LANPORT=%3
set HATHDIR=%4
set HATHCID=%5
set EHIPBID=%6
set EHIPBPW=%7
set BATCHID=%8

cd /D %HATHDIR%
set GETRY=0
set RETRY=0
setlocal enabledelayedexpansion

:: 防止脚本重复执行
set MATCH="CommandLine like '%%%~0%%' and Not CommandLine like '%%%BATCHID%%%'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId') do (
	echo %%a| findstr "^[0-9]*$" >nul && taskkill /PID %%a
)

:: 获取上次穿透的时间戳
set OLDPORT=0
set OLDTIME=none
if EXIST stun_hath.info (
	for /F "tokens=7" %%a in (stun_hath.info) do (set OLDPORT=%%a)
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
	if NOT !CMPTIME! GTR 1 (timeout 60 /NOBREAK >nul)
)

:RETRY

:: 获取 H@H 设置信息
del stun_hath.php 2>nul
curl -Ls -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"
for /F tokens^=6^ delims^=^" %%a in ('findstr f_cname stun_hath.php') do (set f_cname=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_throttle_KB stun_hath.php') do (set f_throttle_KB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_disklimit_GB stun_hath.php') do (set f_disklimit_GB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr p_mthbwcap stun_hath.php') do (set p_mthbwcap=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_diskremaining_MB stun_hath.php') do (set f_diskremaining_MB=%%a)

:: 检测是否获取成功
findstr Miscellaneous stun_hath.php >nul ||(
if %GETRY% GEQ 3 exit 1
timeout 5 /NOBREAK >nul
set /A GETRY=%GETRY%+1
goto RETRY
)

:: 停止 H@H，等待 30 秒
for /F "tokens=3" %%a in ('handle.exe -nobanner -accepteula %HATHDIR%\HentaiAtHomeGUI.jar') do (
	echo createobject^("wscript.shell"^).run "%HATHDIR%\windows-kill.exe -SIGINT %%a",0 >%TEMP%\windows-kill.vbs
	start %TEMP%\windows-kill.vbs)
timeout 30 /NOBREAK >nul

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
curl -Ls -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
-d %DATA% ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"

:: UPnP 失败则使用 PORTPROXY
upnpc.exe -i -d %OLDPORT% tcp >nul 2>&1
upnpc.exe -i -e "STUN HATH %WANPORT%->%LANPORT%->%WANPORT%" -a @ %WANPORT% %LANPORT% tcp >nul
if NOT %ERRORLEVEL%==0 (
	netsh interface portproxy delete v4tov4 %LANPORT% >nul
	netsh interface portproxy set v4tov4 %LANPORT% * %WANPORT% >nul
)

:: 启动 H@H
del .\log\log_out >nul 2>&1
runas /trustlevel:0x20000 "javaw -Xms16m -Xmx512m -jar HentaiAtHomeGUI.jar --silentstart"
:: Windows 11 22H2 及部分版本 runas 存在 Bug，需指定 /machine
:: 若提示计算机类型不匹配，请自行修改为 x86
if NOT %ERRORLEVEL%==0 (runas /trustlevel:0x20000 /machine:amd64 "javaw -Xms16m -Xmx512m -jar HentaiAtHomeGUI.jar --silentstart")
timeout 60 /NOBREAK >nul
findstr /C:"initialization completed successfully" .\log\log_out >nul 2>&1 && goto DONE
timeout 60 /NOBREAK >nul
findstr /C:"initialization completed successfully" .\log\log_out >nul 2>&1 && goto DONE
timeout 30 /NOBREAK >nul
curl -Ls -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o %TEMP%\hentaiathome.%BATCHID%.php ^
"https://e-hentai.org/hentaiathome.php"
findstr Online %TEMP%\hentaiathome.%BATCHID%.php >nul && goto DONE
if %RETRY% GEQ 3 exit 1
timeout 300 /NOBREAK >nul
set /A RETRY=%RETRY%+1
goto RETRY

:DONE
echo HentaiAtHome ok.
