SDKName=${JOB_NAME%%_*}

# 检查是否状态记录是否是Release，Release意味所有流程都走完了，任务终止
checkState()
{
	IssuesPath=${JENKINS_HOME}/workspace/iOSAutoRelease/Project/$SDKName/workspace/issues
	MAX=0
    
    for file in `ls $IssuesPath`
    do
        prefix=${file%-*}
        num=${file#*-}
        if [ $num -gt $MAX ]
        then
            MAX=$num
        fi
        NEWEST_FILE="${prefix}-${MAX}"
    done
    
    status=$(awk -F ' = ' '/status/ {print $2; exit}' "$IssuesPath/${NEWEST_FILE}")
    if [ $status == "release" ]; 
    then
        echo "无待发布任务或无关触发,任务中止"
        exit 2
    else
    	echo "找到正在发布任务:${NEWEST_FILE}"
    fi
}

# 备份发布构建目录下的最新一次打包
backup()
{
	Backup_Folder="${JENKINS_HOME}/workspace/release/$SDKName"
    Release="${JENKINS_HOME}/workspace/${SDKName}_Start/Release/"
    Release_Path=`find $Release -type d -name "v.*"`
    LastVersion=${Release_Path##*/}
    
    echo "Find Last version:${LastVersion}"
    cp -r $Release_Path ${Backup_Folder}/
}

# 自动帮我们在开发git下打tag
gitlab_project_tag()
{
    username="qinch"
    ssh_PATH="${WORKSPACE}/../iOSAutoRelease/.ssh/${username}_rsa"
    cd ${WORKSPACE}/../${SDKName}_Start
    
    git config --local user.name $username
    git config --local user.email ${username}@yoozoo.com
    
    eval $(ssh-agent)
    ssh-add $ssh_PATH
    
    # 删除相同tag
    for tag in `git tag`
    do    
      if [ $tag == $SDK_Bundle_Version ]
      then
        git tag -d $SDK_Bundle_Version
      fi
    done
        
    for tag in `git ls-remote --tags`
    do   
        if [[ $tag == */tags/$SDK_Bundle_Version ]]
        then
            git push origin :$tag
        fi
    done
    
    git tag $SDK_Bundle_Version
    git push --tags
    
    ssh-agent -k
}

# 更新gitlab 顺便更新了podfile
gitlab_mobclub_update()
{
	PodName="mob_pushsdk"
    # cocoapods的source需要用
    zipName="${SDKName}_For_iOS_${LastVersion}"
	Info_Plist=`find "${WORKSPACE}/SDK/${SDK_Name}" -name "*Info.plist"`
	GitVersion="v$(/usr/libexec/PlistBuddy -c "Print:CFBundleShortVersionString" $Info_Plist)" 
    
    if [ "${GitVersion}" != "${LastVersion}" ]
    then
        # 更新git里的SDK文件
        rm -rf "${WORKSPACE}/SDK"
        rm -rf "${WORKSPACE}/Sample"
        cp -r "${Backup_Folder}/${LastVersion}/" "${WORKSPACE}/"
        
        # 更新podspec
        lineV=`sed -n -e '/[A-Za-z].version[[:space:]]*=/=' "${WORKSPACE}/${PodName}.podspec"`
        ContentV=`sed -n '/[A-Za-z].version[[:space:]]*=/p' "${WORKSPACE}/${PodName}.podspec"`
        oldV=`echo ${ContentV} | grep -Eo '\d{1,}.\d{1,}.\d{1,}'`
        newV=`echo ${LastVersion#*v}`
        sed -i "" "${lineV}s/${oldV}/${newV}/g" "${WORKSPACE}/${PodName}.podspec"
        
        lineS=`sed -n -e '/[A-Za-z].source[[:space:]]*=/=' "${WORKSPACE}/${PodName}.podspec"`
        ContentS=`sed -n '/[A-Za-z].source[[:space:]]*=/p' "${WORKSPACE}/${PodName}.podspec"`
        oldS=`echo ${ContentS} | grep -Eo '\{.*\}'`
        url="https://dev.ios.mob.com/files/download/${BucketName}/${zipName}.zip"
        newS="{ :http => '${url}' }"
        sed -i "" "${lineS}s~${oldS}~${newS}~g" "${WORKSPACE}/${PodName}.podspec"
        
        # git推送
        git add -A
        git commit -m "${LastVersion} update"
        
        # 先删除本地相同tag
        for tag in `git tag`
        do    
          if [ $tag = $LastVersion ]
          then
              git tag -d $LastVersion
          fi
        done
        git tag ${LastVersion}
              
        #启动ssh-agent
        UserName="qinch"
        ssh_PATH="${WORKSPACE}/../iOSAutoRelease/.ssh/${UserName}_rsa"
        eval $(ssh-agent)
        ssh-add $ssh_PATH
        git config --local user.email ${UserName}@yoozoo.com 
        git config --local user.name ${UserName}
        
        # 删除远程相同tag
        for tag in `git ls-remote --tags`
        do   
          if [[ $tag == */tags/$LastVersion ]]
          then
            git push origin :$tag
          fi
        done
        git push --tags
        git push origin HEAD:master
        ssh-agent -k
        
    else
        echo "Gitlab已存在当前最新已发布版本，请知悉！~"
    fi
}


# 更新最新发布版本到我们的服务器，然后更新cocoapods
cocoapods()
{
	BucketName="pushsdk"
	# 更新minio文件服文件
    cd "${Backup_Folder}/${LastVersion}/SDK"
    zip -r "${zipName}.zip" ${SDKName}
    mc cp "${zipName}.zip" "minio/${BucketName}"
    rm -f "${zipName}.zip"
    
    # pod推送
	pod trunk push --verbose --allow-warnings
}

# 修改最新发布状态到Release,说明所有流程已跑完，此版本不可再进行发布操作
end()
{
	echo "status = release">$IssuesPath/${NEWEST_FILE}
}


checkState
backup
gitlab_project_tag
cocoapods
end