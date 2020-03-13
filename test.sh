SDKName=${JOB_NAME%%_*}
Space=${SDKName}SDK
Demo="${SDKName}Demo"
Scheme="MobPushDemo"
UnitTest="${Scheme}Tests"


# 更新预览用的本地html
updatePreview()
{
	RetainCycles="${WORKSPACE}/RetainCycles"
    if [ -d $RetainCycles ]
    then
        rm -r $RetainCycles
    fi
    cp -r "${WORKSPACE}/../FBMemoryProfiler/RetainCycles" "${WORKSPACE}/"
    
    RetainCycleLog="${WORKSPACE}/RetainCycles/Log/log.text"
    if [ -d $RetainCycleLog ]
    then
        rm $RetainCycleLog
    fi
}

# 配置单元测试工程
configUnitTest()
{
	Manager="${WORKSPACE}/../FBMemoryProfiler/Sample/TestDemoTests/FBTestManager.mm"
    Framework="${WORKSPACE}/../FBMemoryProfiler/Package/FBMemoryLeakDetecter.framework"
    
    TestPath="${WORKSPACE}/Sample/${Demo}/${UnitTest}"
    FrameworkPath="${WORKSPACE}/SDK"
    
    if [ -d "${TestPath}/FBTestManager.mm" ]
    then
        rm "${TestPath}/FBTestManager.mm"
    fi
    
    if [ -d "${FrameworkPath}/FBMemoryLeakDetecter.framework" ]
    then
        rm -r "${FrameworkPath}/FBMemoryLeakDetecter.framework"
    fi
    
    cp $Manager  "${TestPath}/"
    cp -r $Framework "${FrameworkPath}/"
    
    python "${WORKSPACE}/../FBMemoryProfiler/py/Import.py" 0 1 "${WORKSPACE}/Sample/${Demo}/${Demo}.xcodeproj/project.pbxproj" "${Framework}/FBMemoryLeakDetecter.framework" "${TestPath}/FBTestManager.mm"
}

# 执行UnitTest
unitTest()
{
	echo "123456" | sudo -S xcode-select -s /Applications/Xcode10.1.app
    ReportsDir="${WORKSPACE}/Reports"
    if [ -d $ReportsDir ]
    then
        rm -r $ReportsDir
    fi
    mkdir -p $ReportsDir
    
    #编译
    xcodebuild -workspace ${Space}.xcworkspace -scheme ${Scheme} -sdk iphonesimulator
    #测试
    xcodebuild test -scheme ${Scheme} -target $UnitTest -destination 'platform=iOS Simulator,name=iPhone 7 Plus' -enableCodeCoverage YES 2>&1 | ocunit2junit
    
    slather coverage --html --input-format profdata --binary-basename ${Scheme} --scheme ${Scheme} --workspace ${Space}.xcworkspace --configuration Debug --ignore **View** --ignore **AppText** --output-directory Reports Sample/${Demo}/${Scheme}.xcodeproj
}

# 提取jenkins日志里面的输出，copy到Apache目录下
FormReport()
{
	ApacheDocumentPath="/Library/WebServer/Documents/${SDKName}"
    LogPath="${WORKSPACE}/../../jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/log"
    
    leftStr=$(grep -n '>>retainCycleLeft<<' ${LogPath})
    rightStr=$(grep -n '>>retainCycleRight<<' ${LogPath})
    
    leftLine=$((10#${leftStr%%:*}+1))
    rightLine=$((10#${rightStr%%:*}-1))
    
    sedL=${leftLine}
    sedR=${rightLine}'p'
    sedStr=${sedL}','${sedR}
    
    echo "123456" | sudo -S sed -n ${sedStr} ${LogPath} > ${RetainCycleLog}
    
    # retainCycle日志放到apache的document下
    if [ -d "${ApacheDocumentPath}/RetainCycles"]
    then
        echo 123456 | sudo rm -rf "${ApacheDocumentPath}/RetainCycles"
    fi
    echo 123456 | sudo cp -r "${WORKSPACE}/RetainCycles" "${ApacheDocumentPath}/"
}

oclint()
{
	cd ${WORKSPACE}
    
	if [ -d ./derivedData ]; then
      rm -rf ./derivedData
    fi
    
   	if [ -d ./compile_commands.json ]; then
      rm -f ./compile_commands.json
    fi
    
	if [ -d ./oclintReport.xml ]; then
      rm -f ./oclintReport.xml
    fi    
    
    find . -type d -name Build -exec rm -rf {} \+
    
    xcodebuild -scheme $Scheme -workspace $Space.xcworkspace clean
    
    xcodebuild -scheme $Scheme -workspace $Space.xcworkspace -configuration Debug COMPILER_INDEX_STORE_ENABLE=NO | xcpretty -r json-compilation-database -o compile_commands.json
    
    if [ -f ./compile_commands.json ]; then
        echo  '-----编译数据生成完毕-----'
    else
        echo  '-----编译数据生成失败-----'
        exit 1
    fi
        
    /Users/vimfung/oclint/bin/oclint-json-compilation-database -e Sample -- -report-type pmd -o oclintReport.xml \
    -rc LONG_LINE=200 \
    -disable-rule ShortVariableName \
    -disable-rule ObjCAssignIvarOutsideAccessors \
    -disable-rule AssignIvarOutsideAccessors \
    -disable-rule UnusedMethodParameter \
    -disable-rule UnusedLocalVariable \
    -max-priority-1=1000000 \
    -max-priority-2=1000000 \
    -max-priority-3=1000000 || true
    
    
   	if [ -f ./oclintReport.xml ]; then
    	echo '-----分析完毕-----'
    else 
        echo '-----分析失败-----'
        exit 1
    fi
}


memoryProfiler()
{
	updatePreview
    configUnitTest
    unitTest
    FormReport
}

memoryProfiler
oclint


