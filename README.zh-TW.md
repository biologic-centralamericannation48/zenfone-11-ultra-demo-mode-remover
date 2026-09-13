# AI2401 ADF Rescue

這是一個非官方、安全優先的 Windows 工具，用來解除 **ASUS Zenfone 11 Ultra（`ASUS_AI2401_H`／AI2401）** 在 Recovery 恢復原廠後仍殘留的展示模式管理。

工具會自動完成已在真機驗證過的流程：從已授權的 ADB 進入底層 bootloader，核對手機型號、序號與 `ADF` 分割區資料，最後只清除 `ADF`。

> [!WARNING]
> 本專案不是 ASUS 官方工具。清除分割區屬於不可復原操作，僅限用於你擁有或獲授權維修的裝置，使用者須自行承擔風險。

## 安全設計

- 只接受已驗證型號 `ASUS_AI2401_H`。
- 必須位於底層 bootloader（`is-userspace: no`），不允許在 fastbootd 執行。
- Boot product 必須是 `pineapple`。
- `ADF` 必須是 ext4，大小必須精確等於 `0x2000000`（32 MiB）。
- 執行前要求兩次文字確認，其中一次必須包含當前裝置序號。
- 程式內唯一允許清除的目標是 `ADF`。
- 不會解鎖 bootloader。
- 不會清除 `boot`、`system`、`vendor`、`userdata`、`misc` 或使用者輸入的其他分割區。
- 不會繞過 FRP、螢幕鎖、Google 帳戶或其他所有權保護。
- 不附帶或重新散布 ASUS 韌體、APK、驅動程式或 Google Platform-Tools。

## 準備事項

- Windows 10 或 Windows 11。
- 型號顯示為 `ASUS_AI2401_H` 的 Zenfone 11 Ultra。
- 可傳輸資料的 USB 線，且你能解鎖手機。
- 已啟用並授權 USB 偵錯。
- 最新版 [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)。
- Windows 能辨識 ASUS／Android Bootloader USB 裝置。

把 Google 下載的 `platform-tools` 資料夾放在專案旁邊：

```text
asus-retail-demo-rescue/
  asus-demo-rescue.ps1
  Start-Rescue.cmd
  platform-tools/
    adb.exe
    fastboot.exe
```

工具也會尋找上一層的 `../platform-tools`、`%ANDROID_HOME%\platform-tools` 與系統 `PATH`。

## 使用方式

1. 先備份重要資料。
2. 在手機開啟「開發人員選項 → USB 偵錯」。
3. USB 連接電腦，並在手機上允許偵錯授權。
4. 雙擊 `Start-Rescue.cmd`。
5. 先選 **Diagnose** 進行唯讀檢查。
6. 只有在型號及分割區檢查全部通過後，才選 **Clear ADF**。
7. 如果進入底層 bootloader 時 Windows 遺失連線，依畫面指示重新插線或更換 USB 孔。
8. 手機重開後執行 **Verify**。

也可以在 PowerShell 分階段執行；以下做法只對這次程序略過執行政策，不會修改 Windows 的全域設定：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Diagnose
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Clear
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\asus-demo-rescue.ps1 -Mode Verify
```

## 成功判斷

清除階段必須看到 `ADF` 回覆 `OKAY`。Android 開機後應符合：

- 「設定 → 系統 → 重設選項」不再顯示「已被展示模式管理」。
- 「清除所有資料（恢復原廠設定）」可以正常點選。
- 重新開機後不會回到展示桌面或自動播放展示影片。

由於已移除持久化的 OEM 展示旗標，之後再次恢復原廠通常不會重建 Demo 狀態。恢復原廠仍會刪除使用者資料，Google 帳戶保護也不會被本工具移除。

## 為什麼必須進底層 bootloader

在已驗證的 AI2401 上，userspace fastboot（fastbootd）無法正確存取 `ADF`，並會拒絕清除。底層 bootloader 則回報：

```text
is-userspace: no
partition-type:ADF: ext4
partition-size:ADF: 0x2000000
```

上述資料全部吻合後，`fastboot erase ADF` 才能成功。本工具把這些條件寫成強制檢查，任何一項不同都會停止。

Android 的展示模式實作會因廠商而異。AOSP 文件指出，離開展示模式需要先解除裝置管理，再從 bootloader 恢復原廠；AI2401 額外存在本工具處理的 ASUS OEM `ADF` 狀態。可參考 [AOSP Retail Demo 文件](https://source.android.com/docs/core/display/retail-mode)。

## 疑難排解

請參閱 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)。

請勿下載來源不明的修改版 fastboot、解鎖 APK 或工廠工具。本專案刻意不處理 bootloader 解鎖、Qualcomm EDL、驗證繞過或任意分割區寫入。

## 授權與商標

本專案採 MIT License。ASUS、Zenfone、Android 與 Google 為各自權利人的商標；本專案與 ASUS、Google 無隸屬或背書關係。
