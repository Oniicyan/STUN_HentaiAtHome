:: 使用说明请参照以下链接
:: https://github.com/Oniicyan/STUN_HentaiAtHome
:: https://gitee.com/oniicyan/stun_hath

:: 由穿透工具传递参数，注意顺序
set WANADDR=%1
set WANPORT=%2
set APPPORT=%3
set HATHCID=%4
set HATHKEY=%5
set EHIPBID=%6
set EHIPBPW=%7
set HATHDIR=%8
echo %9 | findstr :// >nul && set PROXY=-x %9

:: 防止脚本重复运行
set MATCH="CommandLine like '%%%~0%%' and Not CommandLine like '%%%WANADDR% %WANPORT%%%'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId') do (
	echo %%a| findstr "^[0-9]*$" >nul && taskkill /PID %%a 2>nul
)

:: 初始化
cd /D %HATHDIR%
set TRYGET=0
set TRYSET=0

:: 保存穿透信息
echo %date%%time% tcp %WANADDR%:%WANPORT% >>stun_hath.log

:: 获取 H@H 设置信息
:TRYGET
del stun_hath.php 2>nul
curl %PROXY% -Lsm 15 ^
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
echo The external port %WANPORT%/tcp has not changed. && goto START

:: 读取 H@H 设置信息
for /F tokens^=6^ delims^=^" %%a in ('findstr f_cname stun_hath.php') do (set f_cname=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_throttle_KB stun_hath.php') do (set f_throttle_KB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_disklimit_GB stun_hath.php') do (set f_disklimit_GB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr p_mthbwcap stun_hath.php') do (set p_mthbwcap=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_diskremaining_MB stun_hath.php') do (set f_diskremaining_MB=%%a)

:: 创建 RPC 脚本
:: 访问 http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=server_stat 查询当前支持的 client_build
echo $ACTTIME = [DateTimeOffset]::Now.ToUnixTimeSeconds() >%TEMP%\stun_hath.ps1
echo $ACTKEY = $(-Join [security.cryptography.sha1managed]::new().ComputeHash([Text.Encoding]::Utf8.GetBytes("hentai@home-$args--%HATHCID%-$ACTTIME-%HATHKEY%")).ForEach{$_.ToString("x2")}) >>%TEMP%\stun_hath.ps1
echo curl.exe -Ls "http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=$args&add=&cid=%HATHCID%&acttime=$ACTTIME&actkey=$ACTKEY" >>%TEMP%\stun_hath.ps1

:: 发送 client_suspend
powershell -ExecutionPolicy Bypass %HATHDIR%\stun_hath.ps1 client_suspend >nul

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
curl %PROXY% -Lsm 15 ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
-d %DATA% ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"

:: 发送 client_settings 验证端口
for /F %%a in ('powershell -ExecutionPolicy Bypass "%HATHDIR%\stun_hath.ps1 client_settings | Select-String 'port'"') do (
	echo %%a | findstr port=%WANPORT% >nul
	if %ERRORLEVEL%==0 (
		echo The external port %WANPORT%/tcp is updated successfully.
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

:START
powershell -ExecutionPolicy Bypass %HATHDIR%\stun_hath.ps1 client_start >nul

:: 若未配置 H@H 文件夹，则不启动 H@H
if %HATHDIR%==%TEMP% goto DONE

:: 若已启动 H@H，则结束
set MATCH="CommandLine like '%%%HATHDIR%\HentaiAtHomeGUI.jar%%'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId 2^>nul') do (
	echo %%a| findstr "^[0-9]*$" >nul && goto DONE
)

timeout 5 /NOBREAK >nul

:: 若未启动 H@H，则降权执行
runas /trustlevel:0x20000 "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" >nul && goto DONE
:: Windows 11 22H2 及部分版本 runas 存在 Bug，需指定 /machine
for %%a in (amd64,x86,arm64,arm) do (
	runas /trustlevel:0x20000 /machine:%%a "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" >nul && goto DONE
)

:DONE
echo Now please confirm if the client is running correctly.:: 使用说明请参照以下链接
:: https://github.com/Oniicyan/STUN_HentaiAtHome
:: https://gitee.com/oniicyan/stun_hath

:: 由穿透工具传递参数，注意顺序
set WANADDR=%1
set WANPORT=%2
set APPPORT=%3
set HATHCID=%4
set HATHKEY=%5
set EHIPBID=%6
set EHIPBPW=%7
set HATHDIR=%8
echo %9 | findstr :// >nul && set PROXY=-x %9

:: 防止脚本重复运行
set MATCH="CommandLine like '%%%~0%%' and Not CommandLine like '%%%WANADDR% %WANPORT%%%'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId 2>nul') do (
	echo %%a| findstr "^[0-9]*$" >nul && taskkill /PID %%a 2>nul
)

:: 初始化
cd /D %HATHDIR%
set TRYGET=0
set TRYSET=0

:: 保存穿透信息
echo %date%%time% tcp %WANADDR%:%WANPORT% >>stun_hath.log

:: 获取 H@H 设置信息
:TRYGET
del stun_hath.php 2>nul
curl %PROXY% -Lsm 15 ^
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
echo The external port %WANPORT%/tcp has not changed. && goto START

:: 读取 H@H 设置信息
for /F tokens^=6^ delims^=^" %%a in ('findstr f_cname stun_hath.php') do (set f_cname=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_throttle_KB stun_hath.php') do (set f_throttle_KB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_disklimit_GB stun_hath.php') do (set f_disklimit_GB=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr p_mthbwcap stun_hath.php') do (set p_mthbwcap=%%a)
for /F tokens^=6^ delims^=^" %%a in ('findstr f_diskremaining_MB stun_hath.php') do (set f_diskremaining_MB=%%a)

:: 创建 RPC 脚本
:: 访问 http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=server_stat 查询当前支持的 client_build
echo $ACTTIME = [DateTimeOffset]::Now.ToUnixTimeSeconds() >%HATHDIR%\stun_hath.ps1
echo $ACTKEY = $(-Join [security.cryptography.sha1managed]::new().ComputeHash([Text.Encoding]::Utf8.GetBytes("hentai@home-$args--%HATHCID%-$ACTTIME-%HATHKEY%")).ForEach{$_.ToString("x2")}) >>%HATHDIR%\stun_hath.ps1
echo curl.exe -Ls "http://rpc.hentaiathome.net/15/rpc?clientbuild=169&act=$args&add=&cid=%HATHCID%&acttime=$ACTTIME&actkey=$ACTKEY" >>%HATHDIR%\stun_hath.ps1

:: 发送 client_suspend
powershell -ExecutionPolicy Bypass %HATHDIR%\stun_hath.ps1 client_suspend >nul

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
curl %PROXY% -Lsm 15 ^
-b "ipb_member_id=%EHIPBID%; ipb_pass_hash=%EHIPBPW%" ^
-o stun_hath.php ^
-d %DATA% ^
"https://e-hentai.org/hentaiathome.php?cid=%HATHCID%^&act=settings"

:: 发送 client_settings 验证端口
for /F %%a in ('powershell -ExecutionPolicy Bypass "%HATHDIR%\stun_hath.ps1 client_settings | Select-String 'port'"') do (
	echo %%a | findstr port=%WANPORT% >nul
	if %ERRORLEVEL%==0 (
		echo The external port %WANPORT%/tcp is updated successfully.
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

:START
powershell -ExecutionPolicy Bypass %HATHDIR%\stun_hath.ps1 client_start >nul

:: 若未配置 H@H 文件夹，则不启动 H@H
if %HATHDIR%==%TEMP% goto DONE

:: 若已启动 H@H，则结束
set MATCH="CommandLine like '%%%HATHDIR%\HentaiAtHomeGUI.jar%%'"
for /F %%a in ('wmic process where %MATCH:\=\\% get ProcessId 2^>nul') do (
	echo %%a| findstr "^[0-9]*$" >nul && goto DONE
)

timeout 5 /NOBREAK >nul

:: 若未启动 H@H，则降权执行
runas /trustlevel:0x20000 "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" >nul && goto DONE
:: Windows 11 22H2 及部分版本 runas 存在 Bug，需指定 /machine
for %%a in (amd64,x86,arm64,arm) do (
	runas /trustlevel:0x20000 /machine:%%a "javaw -Xms16m -Xmx512m -jar %HATHDIR%\HentaiAtHomeGUI.jar --silentstart --port=%APPPORT%" >nul && goto DONE
)

:DONE
echo Now please confirm if the client is running correctly.
