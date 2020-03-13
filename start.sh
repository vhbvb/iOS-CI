SDK_Name=${JOB_NAME%%_*}

#执行CreatePackage打包
createPackage()
{
	echo "123456" | sudo -S xcode-select -s /Applications/Xcode10.1.app
    Scheme="CreatePackage"
    Workspace="${WORKSPACE}/${SDK_Name}SDK.xcworkspace"
    xcodebuild -scheme $Scheme -workspace $Workspace -configuration Release build
}

#检查版本是否已经发布
checkSDKVerisonValid()
{
	Info_Plist=`find "${WORKSPACE}/SDK/${SDK_Name}/${SDK_Name}.framework" -name "*Info.plist"`
	Version="v$(/usr/libexec/PlistBuddy -c "Print:CFBundleShortVersionString" $Info_Plist)"    
    Release_Path="${JENKINS_HOME}/workspace/release/$SDK_Name"
    for file in `ls ${Release_Path}`
	do
    	echo $file
    	if [ $file == $Version ]; then
			echo "已存在重复版本,请检查本次发布的项目版本"
        	exit 1
    	fi
	done
}

#整理发布文件
organizeFolders()
{
	Release="${WORKSPACE}/Release"
    if [ -d $Release ]
    then
        rm -rf Release
    fi
    mkdir $Release
    cd $Release
    mkdir ${Version}
    
    cp -R "${WORKSPACE}/Sample" "${Release}/${Version}"
    cp -R "${WORKSPACE}/SDK" "${Release}/${Version}"
    
    #删除Build、PrivateHeaders、unittest
    find "${Version}/Sample" -type d -name Build -exec rm -rf {} \+
    find "${Version}/Sample" -type d -name "*DemoTests" -exec rm -rf {} \+
    find "${WORKSPACE}/SDK" -type d -name PrivateHeaders -exec rm -rf {} \+
    
    zip -r "${Version}.zip" $Version
}

#打包ipa
createIPA()
{
	xcodebuild -scheme "${SDK_Name}Demo" -project "${Release}/${Version}/Sample/${SDK_Name}Demo/${SDK_Name}Demo.xcodeproj" -configuration Release clean build SYMROOT=${Release}/ipa_package
    xcrun -sdk iphoneos PackageApplication -v ipa_package/Release-iphoneos/${SDK_Name}Demo.app -o "${Release}/${SDK_Name}Demo.ipa"
}

#上传fir
uploadFir()
{
	fir login fc36a7d8dd26020fe32572408fcf98e1
    cd ${Release}
    fir publish ${SDK_Name}Demo.ipa -c ${SDK_Name}Demo -Q
    mv *.png ${SDK_Name}Demo.png 
}

#发布jira
jira()
{  
    SDKWorkSpace=${JENKINS_HOME}/workspace/iOSAutoRelease/Project/$SDK_Name
    PythonSpace=${JENKINS_HOME}/workspace/iOSAutoRelease/Python
    IssuesPath=$SDKWorkSpace/workspace/issues
    
    filelist=()
    i=0
    
    for file in `ls -t $IssuesPath`
    do
        filelist[$i]=$file
        ((i++))
    done

	num=${#filelist[@]}

    if [[ $num == 0 ]]; 
    then
        echo "首次运行,新建jira"
        issue=`python $PythonSpace/createIssue.py $SDK_Name`
        echo "status = test">$IssuesPath/${issue}    
    else
        status=$(awk -F ' = ' '/status/ {print $2; exit}' "$IssuesPath/${filelist[0]}")
        if [ $status == "release" ]; 
        then
            echo "最新的记录是已发布,新建jira"
            issue=`python $PythonSpace/createIssue.py $SDK_Name`
            echo "status = test">$IssuesPath/${issue}
        elif [ $status == "test" ]; then
            echo "测试状态,重发"
            #传入issue名和SDK名字
            python $PythonSpace/updateIssue.py ${filelist[0]} $SDK_Name $Version
        fi
    fi
}


createPackage
checkSDKVerisonValid
organizeFolders
createIPA
uploadFir
jira
