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
# 日期： 08 Dec 2016
# 版本： v161208
# 日誌：
#     08 Dec 2016
#         * 修正「hooks」目錄的路徑（倉庫名後缺少了「.git」）
#         * 修正「hooks」目錄的路徑（缺少了「hooks」這一層）
#     08 Dec 2016
#         + 第一版
# 説明：
#     對 Jenkins 項目進行參數化，分別配置一個 Choice Parameter「repo_name」，
#     表示需要操作的 Git 倉庫，需要包括所屬組織或用户名，如「google/fonts」，
#     另外可以加「ALL」選項代表所有倉庫；一個 Boolean Parameter「hook_init」，
#     表示是否需要初始化 hook 腳本；另外 Jenkins 上執行本腳本時還需要加上可供
#     操作的所有 Git 倉庫「all_repos」。例如：
#     ./jenkins_copy_to_hooks.sh "${repo_name}" "${hook_init}" "${all_repos}"
#
###############################################################################

# Jenkins 參數化中選擇需要操作的 Git 倉庫；需要包括所屬組織或用户名
repo_name=$1
# Jenkins 參數化中選擇是否清除配置（true 表示清除）
hook_init=$2
# Jenkins 中列出所有可供操作的 Git 倉庫（以空格隔開）；需要包括所屬組織或用户名
all_repos=$3

# 服務器上 Git 倉庫根目錄
gogs_path="/root/gogs-repositories"
# 需要使用的 update hook 腳本
hook_useful="update.useful.sh"
# 初始 update hook 腳本
hook_useless="update.useless.sh"

#cd /opt/gogs/git_hooks
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
        \cp $2 ${gogs_path}/${repo}.git/hooks/update 2>/dev/null && echo "[Info] Updated file '${repo}.git/hooks/update.'" \
            || { echo "[Error] Directory '${gogs_path}/${repo}.git' doesn't exist."; if_fail=1; }
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

