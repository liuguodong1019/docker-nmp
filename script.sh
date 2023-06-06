#!/bin/bash
projectPath="${HOME}/www/html"
phpServer='skystars/php:8.0-fpm'
phpConfigPath="${HOME}/dockerConfig/php"
nginxConfigPath="${HOME}/dockerConfig/nginx"
mysqlConfigPath="${HOME}/dockerConfig/mysql"
mysqlPass=123456
function evalCmd {
	for cmd in "$@"
	do
	        eval "${cmd}"
	        if [ $? == 0 ];then
	                echo "执行成功"
	        else
	                echo "执行失败  \ ${cmd}"
	                break
	        fi
	done
}
function cmd {
	for cmd in "$@"
	do
	        ${cmd}
	        if [ $? == 0 ];then
	                echo "执行成功"
	        else
	                echo "执行失败 \ ${cmd}"
	                break
	        fi
	done
}
init () {
	echo "请选择需要安装的服务，输入序号即可"
	select name in "php" "nginx" "mysql" "all"
	do
	    case $name in
	        "php")
	            installPhp
	            break
	            ;;
	        "nginx")
	            installNginx
	            break
	            ;;
	        "mysql")
	            installMysql
	            break
	            ;;
	      	"all")
	      	    compose
	                  break
	                  ;;
	              *)
	            echo "输入错误，请重新输入"
	    esac
	done
}
installPhp () {
	exec=(
		"mkdirNotDir ${phpConfigPath}"
		"pull ${phpServer}"
		"run  php ${phpServer}"
		"copy php:/usr/local/etc/.  ${phpConfigPath}"
   		"del php"
   		"sudo docker run --name php -v ${phpConfigPath}:/usr/local/etc -v ${projectPath}:/var/www/html -d ${phpServer}"
   		ps
   		"echo '安装php扩展教程请看：https://hub.docker.com/_/php'"
   		"configText ${phpServer} ${phpConfigPath}"
	)
	cmd "${exec[@]}"
}
installNginx () {
	is=$(isVm $1)
    exec=(
		"mkdirNotDir ${nginxConfigPath}"
		"mkdirNotDir ${nginxConfigPath}/log"
		"pull nginx"
		"run  nginx nginx"
	   	"copy nginx:/etc/nginx/.  ${nginxConfigPath}"
	    "copy nginx:/var/log/nginx/. ${nginxConfigPath}/log"
	   	"delAll"
	)
    cmd "${exec[@]}"
    if [ $? == 0 ];then
	    if [ $is == "y" ];then
	      sudo docker run --name nginx --network host -v ${nginxConfigPath}:/etc/nginx -v ${projectPath}:/var/www/html -v /etc/hosts:/etc/hosts  -v ${nginxConfigPath}/log:/var/log/nginx -p 8080:8080 -d nginx
	    else 
	      sudo docker run --name nginx -v ${nginxConfigPath}:/etc/nginx -v ${projectPath}:/var/www/html -v /etc/hosts:/etc/hosts  -v ${nginxConfigPath}/log:/var/log/nginx -p 8080:8080 -d nginx
	    fi
    fi
    if [ $? == 0 ];then
    	exec=(
    		ps
    		"echo 'https://hub.docker.com/_/nginx'"
			"configText nginx ${nginxConfigPath}"
    	)
    	cmd "${exec[@]}"
    fi
}
installMysql () {
	m=(
		"pull mysql"
		"dbisSetPass ${1}"
		"mkdirNotDir ${mysqlConfigPath}"
		"run mysql mysql:latest"
		"copy mysql:/etc/my.cnf ${mysqlConfigPath}/my.cnf"
		"delAll"
	)
	if [ $? == 0 ];then
		cmd "${m[@]}"
	fi
	if [ $? == 0 ];then
		is=$(isVm $2)
		if [ $is == "y" ];then
			sudo docker run --name mysql --network host -e MYSQL_ROOT_PASSWORD=${mysqlPass} -v $mysqlConfigPath/my.cnf:/etc/my.cnf -v $mysqlConfigPath/data:/var/lib/mysql -p 3306:3306 -d mysql:latest
		else
			sudo docker run --name mysql -e MYSQL_ROOT_PASSWORD=${mysqlPass} -v $mysqlConfigPath/my.cnf:/etc/my.cnf -v $mysqlConfigPath/data:/var/lib/mysql -p 3306:3306 -d mysql:latest
		fi
	fi
	if [ $? == 0 ];then
		last=(
			ps
			"echo 'https://hub.docker.com/_/mysql'"
			"configText mysql ${mysqlConfigPath}"
			"echo 'mysql初始账户密码：root:${mysqlPass}'"
		)
		cmd "${last[@]}"
	fi
}
compose () {
	all=(
		installPhp
		"installNginx y"
		"installMysql y y"
		delAll
		rmiAll
		dbisSetPass
	)
	cmd "${all[@]}"
	if [ $? == 0 ];then
		is=$(isVm)
		if [ $is == "y" ];then
			composeVmOut
		else
			composeOut
		fi
	fi
	if [ $? == 0 ];then
		docker compose up -d
	fi
	if [ $? == 0 ];then
  		echo "安装成功"
		docker compose ps -a
		echo "注意：要执行docker compose 相关命令，必须在compose.yaml文件所属目录下执行，命令才会生效，否则会报错(no configuration file provided: not found)"
	else
		echo "安装失败，删除所有镜像"
		sudo docker compose stop
		sudo docker compose rm -f
		#该命令会先列出所有镜像的ID，并强制删除它们
        docker rmi -f $(docker images -q)
	fi
}


#拉取镜像
function pull {
	sudo docker pull $1
}
#启动镜像运行容器
function run {
	sudo docker run --name $1 -itd $2
}
#将容器内的文件复制到宿主机指定目录
function copy {
	sudo docker cp $1 $2
}
#强制删除正在运行的容器
function del {
	sudo docker rm -f $1
}
#停止运行所有容器并删除
delAll () {
	sudo docker rm -f $(sudo docker ps -aq)
}
#删除镜像
function rmi {
	sudo docker image rm $1
}
#删除所有镜像
function rmiAll {
  sudo docker rmi $(sudo docker images -q)
}
function ps {
	sudo docker ps -a
}
function configText {
	echo "${1} 配置文件在 ${2}"
}
#文件夹不存在则创建
function mkdirNotDir {
	if [ ! -d "/data/" ];then
  		sudo mkdir -p -m 777 $1
  	else
  		echo "文件夹已经存在"
	fi
}
function dbisSetPass {
  if [ $# == 0 ];then
    read -p "是否设置root账户密码,默认是${mysqlPass}（y/n）：" isSetPass
    if [ $isSetPass == "y"  ];then
        read -sp "请设置密码：" password
        if [ ${#password} == 0 ];then
          echo "不能为空，请重新输入！"
        else
          mysqlPass=$password
        fi
    fi
  fi
}
# 是否是虚拟机，如果是将network设置为host，这样才主机才可以访问到容器服务
isVm () {
	if [ $# == 0 ];then
		read -p "使用的是虚拟机吗？（y/n）：" isVm
		echo $isVm
		return $?
	fi
}
composeOut () {
cat <<EOF > compose.yaml
services:
  php:
    image: skystars/php:8.0-fpm
    volumes:
        - ${phpConfigPath}:/usr/local/etc
        - ${projectPath}:/var/www/html
    container_name: php
    expose:
      - "9000"
  nginx:
    image: nginx
    container_name: nginx
    depends_on:
      - php
    ports:
      - "80:80"
    volumes:
      - /etc/hosts:/etc/hosts
      - ${nginxConfigPath}:/etc/nginx
      - ${projectPath}:/var/www/html
  db:
    image: mysql
    ports:
      - "3306:3306"
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${mysqlPass}
    volumes:
      - ${mysqlConfigPath}/my.cnf:/etc/my.cnf
      #- ${mysqlConfigPath}/my.cnf.d:/etc/my.cnf.d
      #- ${mysqlConfigPath}/conf.d:/etc/mysql/conf.d
      #数据存储位置
      - ${mysqlConfigPath}/data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    restart: always
EOF
}
composeVmOut () {
cat <<EOF > compose.yaml
services:
  php:
    image: skystars/php:8.0-fpm
    volumes:
        - ${phpConfigPath}:/usr/local/etc
        - ${projectPath}:/var/www/html
    container_name: php
    expose:
      - "9000"
  nginx:
    image: nginx
    container_name: nginx
    depends_on:
      - php
    ports:
      - "80:80"
    network_mode: "host"
    volumes:
      - /etc/hosts:/etc/hosts
      - ${nginxConfigPath}:/etc/nginx
      - ${projectPath}:/var/www/html
  db:
    image: mysql
    ports:
      - "3306:3306"
    network_mode: "host"
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${mysqlPass}
    volumes:
      - ${mysqlConfigPath}/my.cnf:/etc/my.cnf
      #- ${mysqlConfigPath}/my.cnf.d:/etc/my.cnf.d
      #- ${mysqlConfigPath}/conf.d:/etc/mysql/conf.d
      #数据存储位置
      - ${mysqlConfigPath}/data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    restart: always
EOF
}
# 仅限mac，安装国内源brew，可自选
homeBrew () {
	/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
}

init