SDKName=${JOB_NAME%%_*}
PythonSpace=${JENKINS_HOME}/workspace/iOSAutoRelease/Python
IssuesPath=${JENKINS_HOME}/workspace/iOSAutoRelease/Project/$SDKName/workspace/issues

checkStatus()
{
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
    if [ $status == "release" ]; then
    
        echo "无待发布任务,本次不执行单元测试"
        exit 2
    fi
}


addCommentToJIRA()
{    
	jira_name="${prefix}-${MAX}"
    test_report="单元测试结果:${BUILD_URL}testReport/"
    memory_profile="内存检测结果:${BUILD_URL%:*}/${SDKName}/RetainCycles/retainCycles.html"
    oclint_res="代码效验结果:${BUILD_URL}pmd/"
    comment="${test_report}；${memory_profile}；${oclint_res}"
    python $PythonSpace/addComment.py ${jira_name} $SDKName $comment
}

checkStatus
addCommentToJIRA