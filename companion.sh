#!/bin/sh

#
# Bash script to augment the tomcat upgrade by moving specific files
#--------------------------------------------------------------------

# Variables
script_home=/home/<SANITIZED>/tomcat-upgrade/service-files
tomcat_home=<SANITIZED>/tomcat
toward_tomcat_version=<SANITIZED>
services_array=( <SANITIZED> )



move (){

	# move application specific files to those application instances.
	
	server="$script_home"/$1.server.xml
	context="$script_home"/$1.context.xml
	
	echo "Copying $i "
	cp $server "$tomcat_home"/"$1"_inst/conf/server.xml
	if [ $? -ne 0 ]; then return 1; fi
	cp $context "$tomcat_home"/"$1"_inst/conf/context.xml
	if [ $? -ne 0 ]; then return 1; fi
	cp tomcat-users.xml "$tomcat_home"/"$1"_inst/conf/tomcat-users.xml
	if [ $? -ne 0 ]; then return 1; fi
	cp manager.xml "$tomcat_home"/"$1"_inst/conf/Catalina/localhost/manager.xml
	if [ $? -ne 0 ]; then return 1; fi
	
}


for i in "${services_array[@]}"
	do
		move $i
		if [ $? -ne 0 ]; then 
		echo "Error moving files for "$i"!"
		exit 1
	fi
	done
echo "all files moved successfully."

echo "You must now modify systemd/system as root..."
echo "do: "
echo "cd /etc/systemd/system"
echo "find . -type f -exec sed -i 's/tomcat-8.5.24/tomcat-$(toward_tomcat_version)/g' {} \;"
echo "reboot"




