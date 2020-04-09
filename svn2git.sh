
# git config --global gc.auto 0

SVNPATH="svn://svn.xxx.com/ios/project/"
projects=()
for SVNPATH="svn://svn.xxx.com/ios/project/" in ${projects[@]}
do
	svn co --username xxx --password xxx@email.com ${SVNPATH}${element} ${element}
	cd ${element}
	svn log --xml | grep author | sort -u | perl -pe 's/.*>(.*?)<.*/$1 = /' > ../auth_files/users_${element}.txt
	cd ../
	rm -rf ${element}

	while read line
	do
	    new_str="${new_str}${line} ${line%% *} <${line%% *}@email.com>\n"
	done <<< "$(cat ./auth_files/users_${element}.txt)"

	echo $new_str >> ./auth_files/users_${element}_edited.txt
	git svn clone ${SVNPATH}${element}  --authors-file=./auth_files/users_${element}_edited.txt  --no-metadata -T trunk -b branches -t tags ${element}_git
	cd ${element}_git/.git

	if [ -f "./packed-refs" ]; then
	    while read line
	    do
	        if [[ ${line:0:1} != "#" ]]; then
	            ID=${line% *}
	            PATH=${line#* }
	            echo $ID >> ./$PATH
	        fi
	    done <<< "$(cat ./packed-refs)"
	fi

	if [ -d "./refs/tags" ]; then
		rm -r "./refs/tags"
	fi

	mv "./refs/remotes/origin/tags" "./refs/"
	cp -rf ./refs/remotes/* ./refs/heads/

	cd ../
	git remote add origin http://gitlab.code.mob.com/iosteam/svn_copy/${element}.git
	git push origin --all
	git push --tags
	cd ../
done

