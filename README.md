# git_hooks

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

* update.rule_push_branch

update hook - 限制特定分支的合併來源

* update.check_message_format

update hook - 提交日誌不允許隨意填寫

* update.check_force_push

update hook - 拒絕加「--force」參數的推送（通常是在 rebase 遠程分支或 reset 之後）

* update.check_commit_author

update hook - 僅指定用户可推送特定分支

* commit-msg.check_message_format

commit-msg hook - 提交日誌不允許隨意填寫
