# git\_hooks

## Git Hooks 説明

* update

本倉庫裏所有 update.* 的文件在實際使用中需要把文件名修改成「update」，  
並給予可執行權限 `chmod +x update`，之後把它放在遠程倉庫的 hooks 目錄中，  
這樣在客戶端進行 push 操作時就會觸發執行 update 腳本。

* commit-msg

commit-msg.* 文件在實際使用中需要把文件名修改成「commit-msg」，  
並給予可執行權限 `chmod +x commit-msg`，之後把它放在本地的 .git/hooks 目錄中，  
這樣本地進行 commit 操作時就會觸發 commit-msg 腳本。


## 目錄簡單説明

* 【更新 - 08 Dec 2016】jenkins\_copy\_to\_hooks.sh

shell script - 結合 Jenkins 實現可複製 hook 腳本到指定 Git 倉庫裏，具體使用方式見文件內説明。


* 【更新 - 07 Dec 2016】update.sh

update hook - 本倉庫下幾個 update hook 進行了重構，每塊功能使用函數方便後續調用，目前功能包括了：  

  1. 指定分支禁止強制推送  
  2. 指定分支禁止刪除  
  3. 指定分支禁止 merge 特定分支  
  4. 指定分支只允許 merge 操作（且只能 merge 特定分支）  
  5. 非指定提交者限制合併特定分支  
  6. 禁止刪除標籤  
  7. 禁止覆蓋標籤

* update.rule\_push\_branch

update hook - 限制特定分支的合併來源

* update.check\_message\_format

update hook - 提交日誌不允許隨意填寫

* update.check\_force\_push

update hook - 拒絕加「--force」參數的推送（通常是在 rebase 遠程分支或 reset 之後）

* update.check\_commit\_author

update hook - 僅指定用户可推送特定分支

* commit-msg.check\_message\_format

commit-msg hook - 提交日誌不允許隨意填寫
