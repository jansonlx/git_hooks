#!/bin/bash -e

###############################################################################
# 腳本：Jenkins copy to hooks
# 功能：結合 Jenkins 實現可複製 hook 腳本到指定 Git 倉庫裏
# 作者：
#        ____ __   __  __ _____ ___  __  __
#       /_  /  _ \/ / / / ____/ __ \/ / / /
#        / / /_/ / /|/ /_/_  / / / / /|/ /
#     __/ / /-/ / / | /___/ / /_/ / / | /
#    /___/_/ /_/_/|_|/_____/\____/_/|_|/
#
# 日期： 17 Dec 2016
# 版本： v161217
# 日誌：
#     17 Dec 2016
#         * 對使用方式稍作修改：
#           上個版本設計在 Jenkins 上使用少量腳本來調用本腳本，
#           實際使用過程發現維護成本高且容易操作錯誤（特別是普通維護人員），
#           現在的方案是所有腳本在此維護，Jenkins 上只需複製全文做參數修改即可
#     08 Dec 2016
#         * 修正「hooks」目錄的路徑（倉庫名後缺少了「.git」）
#         * 修正「hooks」目錄的路徑（缺少了「hooks」這一層）
#     08 Dec 2016
#         + 第一版
# 説明：
#     所有內容直接複製到 Jenkins 項目「Send build artifacts over SSH」裏，
#     然後進行以下配置：
#     1. 添加「Choice Parameter」（每個版本庫為一個選項，其中 ALL 代表全部選中）
#        Name: repo_name
#        Choices: ALL
#                 google/fonts
#                 macvim-dev/macvim
#        Description: 請選擇需要操作的 Git 版本庫
#     2. 添加「Boolean Parameter」
#        Name: hook_init
#        Description: 選中表示初始化 hook 腳本（未選中則使用配置好的 hook 腳本）
#     5. 修改下文腳本中「all_repos」參數（和 1 添加的版本庫一一對應，除了「ALL」）
#
###############################################################################


# Jenkins 項目上的「Choice Parameter」
if [[ -z ${repo_name} ]]; then
    echo -e "\n[Error] >>> 請選擇需要操作的版本庫\n"
    exit 1
fi

# 選中表示初始化 hook 腳本（未選中則使用配置好的 hook 腳本）
if [[ -z ${hook_init} ]]; then
    hook_init="false"
fi


# 服務器上 Git 版本庫根目錄
gogs_path="/root/gogs-repositories"
# 配置好的 hook 腳本存放路徑
git_path="/opt/git_hooks"
# 配置好的 update hook 腳本
hook_useful="update.useful.sh"
# 初始 update hook 腳本
hook_useless="update.useless.sh"
# 可供操作的 Git 版本庫（需要包括所屬組織或用户名）
all_repos=" \
    google/fonts \
    macvim-dev/macvim \
    "


# 進入指定目錄後獲取最新腳本
cd ${git_path}
git reset --hard HEAD
git checkout master
git pull origin master


# hook 腳本需要可執行權限
chmod +x ${hook_useful} ${hook_useless}

# 函數：複製腳本到指定倉庫的 hooks 目錄下
# 調用：copy_to_hooks "參數1" "參數2"
#     參數1：需要操作的 Git 倉庫（多個倉庫用空格隔開）
#     參數2：需要複製的腳本文件
# 例子：copy_to_hooks "google/fonts" "update.useful.sh"
#     把「update.useful.sh」腳本複製到「fonts」倉庫裏並重命名為「update」
copy_to_hooks()
{
    for repo in $1
    do
        \cp $2 ${gogs_path}/${repo}.git/hooks/update 2>/dev/null && echo -e "\n[Info] >>> Updated file '${repo}.git/hooks/update.'" \
            || { echo -e "\n[Error] >>> Directory '${gogs_path}/${repo}.git' or file '$2' doesn't exist.\n"; if_fail=1; }
    done
}

# hook_init 不為 true 時使用最新的 hook 腳本
if [[ ${hook_init} != "true" ]]; then
    # repo_name 為 ALL 時表示所有 Git 倉庫都需要操作
    if [[ ${repo_name} == "ALL" ]]; then
        copy_to_hooks "${all_repos}" "${hook_useful}"
    else
        copy_to_hooks "${repo_name}" "${hook_useful}"
    fi
# hook_init 為 true 則使用初始 hook 腳本
else
    if [[ ${repo_name} == "ALL" ]]; then
        copy_to_hooks "${all_repos}" "${hook_useless}"
    else
        copy_to_hooks "${repo_name}" "${hook_useless}"
    fi
fi

# 當存在倉庫沒有實際更新到時進行錯誤退出以提示操作員
if [[ ${if_fail} -eq 1 ]]; then
    exit 1
fi

