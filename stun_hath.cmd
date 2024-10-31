:: 由 Lucky 传递参数，注意顺序
set PROXY=%1
set WANADDR=%2
set WANPORT=%3
set APPPORT=%4
set HATHCID=%5
set HATHKEY=%6
set EHIPBID=%7
set EHIPBPW=%8
set HATHDIR=%9

:: 初始化
if NOT EXIST %HATHDIR% set HATHDIR=%TEMP%
cd /D %HATHDIR%
set TRYGET=0
set TRYSET=0
setlocal enabledelayedexpansion

:: 保存穿透信息
echo %date%%time% tcp %WANADDR% : %WANPORT% >stun_hath.info
echo %date%%time% tcp %WANADDR% : %WANPORT% >>stun_hath.log

:: 获取 H@H 设置信息
:TRYGET
del stun_hath.php 2>nul
curl -Ls -m 10 ^
-x %PROXY% ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"

:: 检测是否获取成功
findstr Miscellaneous stun_hath.php >nul ||(
if %TRYGET% GEQ 3 (
	echo Failed to get the settings. Please check the PROXY.
	exit 1
)
timeout 15 /NOBREAK >nul
set /A TRYGET=%TRYGET%+1
goto TRYGET
)

:: 若端口未发送变化，则退出
findstr f_port stun_hath.php | findstr %WANPORT% >nul &&^
echo The external port has not changed. && exit 0

:: 读取 H@H 设置信息
for /F tokens^=6^ delims^=^" %%a in ('findstr f_cname stun_hath.php') do (set f_cname=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_throttle_KB stun_hath.php') do (set f_throttle_KB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_disklimit_GB stun_hath.php') do (set f_disklimit_GB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr p_mthbwcap stun_hath.php') do (set p_mthbwcap=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_diskremaining_MB stun_hath.php') do (set f_diskremaining_MB=%%a)

:: 创建 RPC 脚本
:: 访问 http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=server_stat 查询当前支持的 client_build
echo $ACTTIME = [DateTimeOffset]::Now.ToUnixTimeSeconds() >%TEMP%\stun_hath.ps1
echo $ACTKEY = $(-Join [security.cryptography.sha1managed]::new().ComputeHash([Text.Encoding]::Utf8.GetBytes("hentai@home-$args[0]--%HATHCID%-$ACTTIME-%HATHKEY%")).ForEach{$_.ToString("x2")}) >>%TEMP%\stun_hath.ps1
echo curl.exe "http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=$args[0]&add=&cid=%HATHCID%&acttime=$ACTTIME&actkey=$ACTKEY" >>%TEMP%\stun_hath.ps1

:: 发送 client_suspend
powershell %TEMP%\stun_hath.ps1 client_suspend

:: 更新 H@H 端口信息
:TRYSET
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

:: 发送 client_settings 验证端口
for /F %%a in ('powershell %TEMP%\stun_hath.ps1 client_settings') do (
	echo %%a | findstr port=%WANPORT% >nul
	if %ERRORLEVEL% ==0 (
		echo The external port is updated successfully.
	) else (
		if %TRYSET% GEQ 3 (
			echo Failed to update the external port. Please check the PROXY.
			exit 1
		)
		timeout 15 /NOBREAK >nul
		set /A TRYSET=%TRYSET%+1
		goto TRYSET
	)
)

:: 若未配置 H@H 文件夹，则不启动 H@H
if %HATHDIR%==%TEMP% goto DONE

:: 若已启动 H@H，则结束
set MATCH="CommandLine like '%%%HATHDIR%%%\HentaiAtHomeGUI.jar'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId') do (
	echo %%a| findstr "^[0-9]*$" >nul && goto DONE
)

:: 启动 H@H
runas /trustlevel:0x20000 "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" && goto DONE
:: Windows 11 22H2 及部分版本 runas 存在 Bug，需指定 /machine
:: 若提示计算机类型不匹配，则尝试 x86
runas /trustlevel:0x20000 /machine:amd64 "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" && goto DONE
runas /trustlevel:0x20000 /machine:x86 "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" && goto DONE

:DONE
echo HentaiAtHome ok.
