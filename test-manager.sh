#!/bin/sh

#
# Bash script to augment the tomcat upgrade by moving specific files
#--------------------------------------------------------------------

# Variables
tomcat_home=<SANITIZED>/tomcat
toward_tomcat_version=<SANITIZED>
old_tomcat_version=8.5.24

duplicate (){
	echo "duplicating manager files: "
	# tomcat-users
	echo "tomcat-users.xml.."
	cp "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/tomcat-users.xml "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/tomcat-users.xml.baseline
	# context.xml
	echo "context.xml.."
	cp "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/webapps/manager/META-INF/context.xml "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/webapps/manager/META-INF/context.xml.baseline

	echo "done."
	
	echo "You must now modify:"
	echo "apache-tomcat-$toward_tomcat_version/webapps/manager/META-INF/context.xml"
	echo "apache-tomcat-$toward_tomcat_version/conf/tomcat-users.xml"
	echo "See documentation!"
}

rm_reset () {
	echo "restoring test files to original versions..."
	# tomcat-users
	echo "tomcat-users.xml.."
	rm "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/tomcat-users.xml
	mv "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/tomcat-users.xml.baseline "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/tomcat-users.xml
	
	# context.xml
	echo "context.xml.."
	rm "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/webapps/manager/META-INF/context.xml
	mv "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/webapps/manager/META-INF/context.xml.baseline "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/webapps/manager/META-INF/context.xml
	
}


help_page="Usage: \nstarting test: ./test_manager.sh -s \nending test: ./test_manager.sh -e \n"

# switch statement to determine which flags have been passed to the script
# -s starts
# -e ends
# -h prints a brief help page
while getopts hse flag
do
    case "${flag}" in
        h) echo -e "$help_page";;
        s) duplicate;;
        e) rm_reset;;
    esac
done

