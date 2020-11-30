#!/bin/bash

# Kyle Snow 8/18/20
#
# Bash script to upgrade the existing version of Apache Tomcat on the banstu boxes
#---------------------------------------------------------------------------------
#
# NOTES: 
# > The new tomcat binaries should be be dl'd from the apache archives and verified with checksums!
# The script relies on having the tar.gz in script_home!
# ex. 
# wget https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.51/bin/apache-tomcat-8.5.51.tar.gz
# wget https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.51/bin/apache-tomcat-8.5.51.tar.gz.sha512
# cat apache-tomcat-8.5.51.tar.gz.sha512    # -> some_alphanumericstring  
# sha512sum apache-tomcat-8.5.51.tar.gz | grep ^copy/paste(some_alphanumericstring)

# Variables
#------------

# All the services to update along with tomcat.
# Fill out as such:
# services_array=( service1 service2 )
services_array=( <SANITIZED> )

server_name=banstu2-test
DATE_WITH_TIME=`date "+%Y%m%d-%H%M%S"`
script_home=/home/<SANITIZED>/tomcat-upgrade

# Tomcat specific
tomcat_home=<SANITIZED>/tomcat
toward_tomcat_version=<SANITIZED>
old_tomcat_version=8.5.24
toward_tomcat_file=./apache-tomcat-"$toward_tomcat_version".tar.gz

# Java specific
update_java=false
toward_java=none 
rm_vuln_java=false
vuln_java=none
jdk_location=<SANITIZED>




# user check - must be run as '<SANITIZED>'
#--------------------------------------

if [[ $EUID -ne 304 ]]; then
	echo "This script must be run as <SANITIZED>!"
	exit 1
fi



# Snapshot sanity check
#-----------------------

echo "IMPORTANT: DO NOT PROCEED IF YOU HAVE NOT YET CREATED A SNAPSHOT"
read -p 'To continue type yes: ' contd

if [ $contd != "yes" ]; then
	echo "Go make that snapshot!"
	exit 2
else
	echo "continuing..."
fi



# Preliminary
#-------------
script-prelim (){
	echo "Performing preliminary steps"
	
	echo "Service Status: "
	for i in "${services_array[@]}"
	do
		sudo systemctl status $i
		if [ $? -ne 0 ]; then 
			echo "Could not get status of $i !!"
		fi
	done
	
	echo "Installing tree for detailed logging..."
	sudo yum -y install tree 

	# Create log of previous java version, tomcat version info, and directory info (ownership and whatnot)
	#-----------------------------------------------------------------------------------------------------
	cd $script_home
	echo "logging previous Tomcat information..."
	touch prev_info.txt
	echo "JAVA VERSION" > prev_info.txt
	java -version >> prev_info.txt
	echo "TOMCAT VERSION INFORMATION" >> prev_info.txt
	/u01/app/tomcat/apache-tomcat-"$old_tomcat_version"/bin/version.sh >> prev_info.txt
	echo "DIRECTORY INFORMATION" >> prev_info.txt
	ls -lR /u01/app/tomcat/ >> prev_info.txt   # make more explicit


	touch tomcat_dir_structure.txt
	tree $tomcat_home > tomcat_dir_structure.txt

}

# Java
upgrade-java () {
	echo "Updating Java version..."
	echo "Current Java info: "
	java-version

	mount $jdk_location /mnt
	sudo yum -y localinstall /mnt/$toward_java_version
	#manual java alternatives config
	alternatives --config java

	echo "New Java info: "
	java -version
}

# Tomcat

tomcat-prelim () {
	#copy tomcat archive over to tomcat_home
	echo "Deploying tomcat $toward_tomcat_version from archive..."	
	cp "$script_home"/apache-tomcat-"$toward_tomcat_version".tar.gz "$tomcat_home"/
	cd "$tomcat_home"/
	tar -xzf apache-tomcat-"$toward_tomcat_version".tar.gz
	if [ $? -ne 0 ]; then return 1; fi
		
	# move service start and stop scripts to new tomcat version directory
	# CAUTION!! This assumes that all environments have the service stop scripts in the tomcat folder --Ed says this is an aberration
	# This new implementation is nicer that an immediate quit/fail.
	for k in "${services_array[@]}"
	do
		start_sh="$tomcat_home"/apache-tomcat-"$old_tomcat_version"/start_"$k"_inst.sh
		stop_sh="$tomcat_home"/apache-tomcat-"$old_tomcat_version"/stop_"$k"_inst.sh
		#starts
		if [ -f "$start_sh" ]; then
			echo "Moving $start_sh ..."
			mv "$tomcat_home"/apache-tomcat-"$old_tomcat_version"/start_"$k"_inst.sh "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/
		else 
			echo "$start_sh does not exist."
		fi
		#stops
		if [ -f "$stop_sh" ]; then
			echo "Moving $stop_sh ..."
			mv "$tomcat_home"/apache-tomcat-"$old_tomcat_version"/stop_"$k"_inst.sh "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/
		else 
			echo "$stop_sh does not exist."
		fi
	
	done 
	if [ $? -ne 0 ]; then return 1; fi
	
	# create new tomcat version conf/Catalina/localhost/
	echo "Creating nested directory: Catalina/localhost/ in the toward tomcat directory..."
	mkdir "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/Catalina
	mkdir "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf/Catalina/localhost
	#if [ $? -ne 0 ]; then return 1; fi
	if [ $? -ne 0 ]; then echo "Failed to make subdirectories!! continuing anyway..."; fi

	### add logic to update <SANITIZED>'s .bash_profile ###

}


create-container () {
	
	cd "$tomcat_home"
	echo "Creating new $1 container..."
	
	# rename previous inst container and create a new one 
	mv "$1"_inst "$1"_inst-"$old_tomcat_version"
	mkdir "$1"_inst
	if [ $? -ne 0 ]; then return 1; fi
	
	# create sub directories
	cd "$1"_inst
	mkdir bin lib logs work temp target build  #the subdirs {webapps, conf, lib} are created further down!
		
	echo "updating $1 container..."
	
	#logs
	touch logs/catalina.out
	
	#lib
	# copy lib dir from previous service instance to new. -- This relies on having ojdbc drivers and other specific lib files in previous service instance lib dir
	cp -r "$tomcat_home"/"$1"_inst-"$old_tomcat_version"/lib "$tomcat_home"/"$1"_inst/
	if [ $? -ne 0 ]; then return 1; fi
	
	#bin
	# copy new baseline's juli.jar
	cp /u01/app/tomcat/apache-tomcat-"$toward_tomcat_version"/bin/tomcat-juli.jar "$tomcat_home"/"$1"_inst/bin/
	if [ $? -ne 0 ]; then return 1; fi
	
	# copy setenv per instance
	cp "$tomcat_home"/"$1"_inst-"$old_tomcat_version"/bin/setenv.sh "$tomcat_home"/"$1"_inst/bin/
	if [ $? -ne 0 ]; then return 1; fi
	
	#conf
	# copy conf dir from new tomcat base instance
	cp -r "$tomcat_home"/apache-tomcat-"$toward_tomcat_version"/conf "$tomcat_home"/"$1"_inst/
	if [ $? -ne 0 ]; then return 1; fi
	
	# rename new tomcat server and context xmls to "__.xml.baseline"
	mv "$tomcat_home"/"$1"_inst/conf/server.xml "$tomcat_home"/"$1"_inst/conf/server.xml.baseline
	mv "$tomcat_home"/"$1"_inst/conf/context.xml "$tomcat_home"/"$1"_inst/conf/context.xml.baseline
	mv "$tomcat_home"/"$1"_inst/conf/tomcat-users.xml "$tomcat_home"/"$1"_inst/conf/tomcat-users.xml.baseline
	if [ $? -ne 0 ]; then return 1; fi
	
	# ...and bring the previous tomcat version's ones in as "previous-version-__.xml"
	#cp "$tomcat_home"/"$1"_inst-"$old_tomcat_version"/conf/server.xml "$tomcat_home"/"$1"_inst/conf/"$old_tomcat_version"-server.xml
	#cp "$tomcat_home"/"$1"_inst-"$old_tomcat_version"/conf/context.xml "$tomcat_home"/"$1"_inst/conf/"$old_tomcat_version"-context.xml
	
	# Catalina/localhost/manager.xml
	#mkdir "$tomcat_home"/"$1"_inst/conf/Catalina/localhost/       # can create in base inst deploy
	
	#webapps
	cp -r "$tomcat_home"/"$1"_inst-"$old_tomcat_version"/webapps "$tomcat_home"/"$1"_inst/
	
}


clean-up (){
	# Create old/ and move all artifacts from previous version to it
	mkdir "$tomcat_home"/old/
	
	# old tomcat version & new tomcat's tar.gz archive
	mv "$tomcat_home"/apache-tomcat-"$old_tomcat_version" "$tomcat_home"/old/
	if [ $? -ne 0 ]; then return 1; fi
	mv "$tomcat_home"/apache-tomcat-"$toward_tomcat_version".tar.gz "$tomcat_home"/old/
	if [ $? -ne 0 ]; then return 1; fi
	
	for k in "${services_array[@]}"
	do
		echo "moving $k"
		mv "$tomcat_home"/"$k"_inst-"$old_tomcat_version" "$tomcat_home"/old/
	done

}


# Main
#--------

#preliminary
 script-prelim
 if [ $? -ne 0 ]; then 
		 echo "Error on initial setup! "
		 exit 1
	  fi

#Java
if [ $update_java == true ]; then
	upgrade-java
	if [ $? -ne 0 ]; then 
		echo "Error upgrading Java! "
		exit 1
	 fi
else
	echo "Current Java version: "
	java -version
	echo "Java version assumed sufficient for tomcat upgrade."  # can add a check in V:2.0
	echo "continuing..."
fi

# Tomcat

for i in "${services_array[@]}"
do
	sudo systemctl stop $i
	if [ $? -ne 0 ]; then 
		echo "Could not stop $i !!"
		exit -1
	fi
done

# move tomcat folders
tomcat-prelim
if [ $? -ne 0 ]; then 
	echo "Error on initial set-up!"
	exit 2
fi

# Create new containers for services
for j in "${services_array[@]}"
do
	create-container $j
	if [ $? -ne 0 ]; then 
		echo "Error on creation of $i instance!"
		exit 3
	fi
done

echo "Service containers successfully created."
echo "Cleaning up..."

clean-up
if [ $? -ne 0 ]; then 
	echo "Error cleaning up previous instance files!"
	exit 4
fi


echo "Done!"



