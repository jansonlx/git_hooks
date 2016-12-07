#!/bin/bash

###############################################################################
# 腳本：Git Update Hook
# 功能：對每個推送分支進行特定限制，包括合併分支、刪除分支（標籤）、強制推送等
# 作者：
#        ____ __   __  __ _____ ___  __  __
#       /_  /  _ \/ / / / ____/ __ \/ / / /
#        / / /_/ / /|/ /_/_  / / / / /|/ /
#     __/ / /-/ / / | /___/ / /_/ / / | /
#    /___/_/ /_/_/|_|/_____/\____/_/|_|/
#
# 日期： 24 Nov 2016
# 版本： v161207
# 日誌：
#     07 Dec 2016
#         + 重構後第一版
# 説明：
#   The update hook runs once for each branch the pusher is trying to update.
#   It takes three arguments: the name of the reference (branch), the SHA-1
#   that reference pointed to before the push, and the SHA-1 the user is trying
#   to push. If the update script exits non-zero, only that reference is
#   rejected; other references can still be updated.
#
###############################################################################


# Gogs (Go Git Service) 自帶的「update」腳本裏的默認內容
"/home/git/gogs/gogs" update $1 $2 $3 --config='/home/git/gogs/custom/conf/app.ini'


# 待更新分支
ref_name=$1
# 推送前分支所指向的提交ID；值為「0{40}」時表示推送新分支
old_rev=$2
# 準備推送的最近一個提交ID；值為「0{40}」表示刪除分支
new_rev=$3


# 函數：判斷指定字符串是否在一組以空格隔開的字符串組內
# 調用：item_in_array "參數1" "參數2"
#     參數1：待判斷的字符串
#     參數2：以空格隔開的一組字符串
# 返回：是則打印出該元素，否則返回 1
# 例子： item_in_array "master" "release hotfix master"
#    判斷「release hotfix master」裏是否包含了「master」
item_in_array()
{
    # $1 為參數1
    array_item=$1
    # $2 為參數2
    array_name=$2
    # egrep 中「-o」表示只打印出匹配到的內容（未有匹配內容時返回 1）
    echo ${array_name} | egrep -o "(^|\s)${array_item}(\s|$)"
}


# 函數：禁止刪除標籤
# 調用：prohibit_deleting_tag
# 返回：直接拒絕更新
prohibit_deleting_tag()
{
    if [[ ${new_rev} =~ 0{40} ]]; then
        echo "[Rejected] Deleting tag '${ref_name_abbr}' is prohibited."
        exit 1
    fi
}


# 函數：禁止覆蓋標籤
# 調用：prohibit_overwriting_tag
# 返回：直接拒絕更新
prohibit_overwriting_tag()
{
    if [[ ! (${old_rev} =~ 0{40} || ${new_rev} =~ 0{40}) ]]; then
        echo "[Rejected] Overwriting tag '${ref_name_abbr}' is prohibited."
        exit 1
    fi
}


# 函數：指定分支禁止刪除
# 調用：prohibit_deleting_branch "參數1"
#     參數1：不允許刪除的分支（多個分支用空格隔開）
# 返回：直接拒絕更新
# 例子：prohibit_deleting_branch "master release"
#     不允許刪除「master」和「release」分支
prohibit_deleting_branch()
{
    specified_branches=$1
    # 待更新分支非指定的分支時直接返回 0
    [[ $(item_in_array "${ref_name_abbr}" "${specified_branches}") ]] || return 0

    if [[ ${new_rev} =~ 0{40} ]]; then
        echo "[Rejected] Deleting branch '${ref_name_abbr}' is prohibited."
        exit 1
    fi
}


# 函數：指定分支禁止強制推送
# 調用：prohibit_force_pushing "參數1"
#     參數1：不允許強制推送的分支（多個分支用空格隔開）
# 例子：prohibit_force_pushing "master release"
#     不允許強制推送「master」和「release」分支
# 説明：一般是在執行了「rebase」或「reset」命令後，
#     需要在執行 push 命令時加上「--force」選項
prohibit_force_pushing()
{
    specified_branches=$1
    # 待更新分支非指定的分支時直接返回 0
    [[ $(item_in_array "${ref_name_abbr}" "${specified_branches}") ]] || return 0
    # 推送新分支或刪除分支時直接返回 0
    [[ ${old_rev} =~ 0{40} || ${new_rev} =~ 0{40} ]] && return 0

    # 如果遠程中被引用分支的某個提交不存在於即將推送的提交中時，可認為是加了「--force」選項
    # 「git rev-list ${new_rev}..${old_rev}」等同「git rev-list ^${new_rev} ${old_rev}」
    old_commits=$(git rev-list ${new_rev}..${old_rev})
    if [[ ${old_commits} ]]; then
        echo "[Rejected] Pushing branch '${ref_name_abbr}' with 'force' option is prohibited."
        echo -e "[Hint] Missing commit(s):\n${old_commits}"
        exit 1
    fi
}


# 函數：指定分支禁止 merge 特定分支
# 調用：prohibit_merging_branch "參數1" "參數2"
#     參數1：不允許隨意合併的分支（多個分支用空格隔開）
#     參數2：禁止當合併源的分支（多個分支用空格隔開）
# 例子：prohibit_merging_branch "master hotfix" "develop feature"
#     不允許合併「develop」或「feature」分支到「master」和「hotfix」分支
prohibit_merging_branch()
{
    specified_branches=$1
    restricted_branches=$2
    # 待更新分支非指定的分支時直接返回 0
    [[ $(item_in_array "${ref_name_abbr}" "${specified_branches}") ]] || return 0
    # 推送新分支或刪除分支時直接返回 0
    [[ ${old_rev} =~ 0{40} || ${new_rev} =~ 0{40} ]] && return 0

    # 查找出有 merge 的提交紀錄（顯示所有父提交）
    merge_commit_parents=$(git rev-list ${old_rev}..${new_rev} --merges --parents)
    if [[ ${merge_commit_parents} ]]; then
        # 通過 awk 命令查找出 merge 提交紀錄中第三列及之後列的數據（這些提交ID自己暫時叫「遠親提交」吧）
        # 「遠親提交」代表 merge 的父提交中從其他分支合併過來的那些提交（之後一些註釋也會用到這個名字）
        merge_commit_distant_parents=$(echo ${merge_commit_parents} | awk '{for(r=3; r<=NF; r++) print $r}')
        # 查找出所有被禁止當合併源的分支的新提交（排除掉當前指定分支推送前的提交）
        restricted_branch_new_commits=$(git rev-list ^${old_rev} ${restricted_branches})
        # for 循環中判斷每個「遠親提交」是否在被禁止當合併源的分支中（是則禁止提交）
        for commit_id in ${merge_commit_distant_parents}
        do
            [[ $(item_in_array "${commit_id}" "${restricted_branch_new_commits}") ]] && prohibited=1 || prohibited=0

            if [[ "${prohibited}" -eq 1 ]]; then
                echo "[Rejected] Merging branch(es) '${restricted_branches}' into '${ref_name_abbr}' is prohibited."
                echo -e "[Hint] Prohibited commit:\n${commit_id}"
                exit 1
            fi

            # for 循環中判斷每個被禁止當合併源的分支HEAD與每個「遠親提交」的共同父提交，是否在被禁止當合併源的分支中（是則禁止提交）
            for branch in ${restricted_branches}
            do
                # 查出共同父提交
                common_ancestor=$(git merge-base ${branch} ${commit_id})
                [[ $(item_in_array "${common_ancestor}" "${restricted_branch_new_commits}") ]] && prohibited=1 || prohibited=0
                if [[ ${prohibited} -eq 1 ]]; then
                    echo "[Rejected] Merging branch(es) '${restricted_branches}' into '${ref_name_abbr}' is prohibited."
                    echo -e "[Hint] Prohibited commit:\n${common_ancestor}"
                    exit 1
                fi
            done
        done
    fi
}


# 函數：指定分支只允許 merge 操作（且只能 merge 特定分支）
# 調用：merge_only "參數1" "參數2"
#     參數1：被限制只能通過 merge 操作後提交的分支（多個分支用空格隔開）
#     參數2：指定參數1只能 merge 的分支（多個分支用空格隔開）
# 例子：merge_only "master" "release hotfix"
#     「master」分支只能通過合併「release」或「hotfix」分支後提交
merge_only()
{
    specified_branches=$1
    restricted_branches=$2
    # 待更新分支非指定的分支時直接返回 0
    [[ $(item_in_array "${ref_name_abbr}" "${specified_branches}") ]] || return 0
    # 推送新分支或刪除分支時直接返回 0
    [[ ${old_rev} =~ 0{40} || ${new_rev} =~ 0{40} ]] && return 0

    # 查出參數2中所有分支的最新提交
    for branch in ${restricted_branches}
    do
        current_commit=$(git rev-list -1 ${branch} 2>/dev/null || echo "")
        restricted_branches_commits="${restricted_branches_commits} ${current_commit}"
    done
    # 獲取準備推送的分支的一個「遠親提交」
    distant_parent=$(git rev-list --parents -1 ${new_rev} | egrep -o "[0-9a-z]{40}$")
    # 僅當該「遠親提交」等於參數2中分支的最新提交才認為是進行了符合要求的 merge 操作
    item_in_array "${distant_parent}" "${restricted_branches_commits}"
    if [[ $? -eq 1 ]]; then
        echo "[Rejected] Branch '${ref_name_abbr}' is allowed to push only merging from branch(es) '${restricted_branches}'."
        exit 1
    fi
}


# 函數：非指定提交者限制合併特定分支
# 調用：restricted_merge_author "參數1" "參數2" "參數3"
#     參數1：不允許隨意合併的分支（多個分支用空格隔開）
#     參數2：禁止當合併源的分支（多個分支用空格隔開）
#     參數3：指定可以合併特定分支的提交者的電郵地址（多個電郵地址用空格隔開）
# 例子：restricted_merge_author "release" "develop" "jacky@abc.xyz andy@abc.xyz"
#     只有「jacky」和「andy」可以合併「develop」分支到「release」分支
# 説明：本函數裏調用了「prohibit_merging_branch」函數
restricted_merge_author()
{
    specified_branches=$1
    restricted_branches=$2
    vip_authors=$3
    # 待更新分支非指定的分支時直接返回 0
    [[ $(item_in_array "${ref_name_abbr}" "${specified_branches}") ]] || return 0
    # 推送新分支或刪除分支時直接返回 0
    [[ ${old_rev} =~ 0{40} || ${new_rev} =~ 0{40} ]] && return 0

    # 查出準備推送的最近一個提交的提交者電郵地址
    commit_author=$(git log ${new_rev} -1 --pretty="%ce")
    # 非指定提交者則需要調用「prohibit_merging_branch」函數判斷該分支的合併是否符合要求
    if [[ ! $(item_in_array "${commit_author}" "${vip_authors}") ]]; then
        prohibit_merging_branch "${specified_branches}" "${restricted_branches}"
    fi
}



# 判斷推送的是分支還是標籤
ref_type=$(echo ${ref_name} | sed -n "s#refs/\([^/]*\)/.*#\1#p")
if [[ ${ref_type} == "heads" ]]; then
    ref_name_abbr=${ref_name#refs/${ref_type}/}

    ############################################
    # 所有分支相關的函數調用放下方
    ############################################

    # 函數：指定分支禁止強制推送
    prohibit_force_pushing "master hotfix release"

    # 函數：指定分支禁止 merge 特定分支
    prohibit_merging_branch "master hotfix" "develop"

    # 函數：指定分支只允許 merge 操作（且只能 merge 特定分支）
    merge_only "master" "release hotfix"

    # 函數：非指定提交者限制合併特定分支
    restricted_merge_author "release" "develop" "jacky@abc.xyz"

elif [[ ${ref_type} == "tags" ]]; then
    ref_name_abbr=${ref_name#refs/${ref_type}/}

    ############################################
    # 所有標籤相關的函數調用放下方
    ############################################

    # 定義需要限制的標籤格式（如：v12.3.456）
    tag_format="^v[0-9]+\.[0-9]+\.[0-9]+$"
    echo ${ref_name_abbr} | egrep -q ${tag_format}
    if [[ $? -eq 0 ]]; then
        # 這裏「true」用於預防臨時註釋掉所有 if 條件裏的函數調用時出現錯誤
        true

        # 函數：禁止刪除標籤
        prohibit_deleting_tag

        # 函數：禁止覆蓋標籤
        prohibit_overwriting_tag
    fi
else
    exit 0
fi

