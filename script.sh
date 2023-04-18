#!/bin/bash
projectPath=/var/www/html
phpServer="php:fpm"
phpConfigPath=/dockerConfig/php
nginxConfigPath=/dockerConfig/nginx
mysqlConfigPath=/dockerConfig/mysql
mysqlPass=123456
nowDir=$(basename $(pwd))
function installPhp {
sudo docker buildx build -t $phpServer -<<EOF
FROM $phpServer
RUN apt-get update && apt-get install -y \
               libfreetype6-dev \
               libjpeg62-turbo-dev \
               libpng-dev \
               libmemcached-dev \
               zlib1g-dev \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && docker-php-ext-install -j$(nproc) gd \
        && pecl install redis \
        memcached \
        xdebug \
        && docker-php-ext-enable redis \
        memcached \
        xdebug \
        opcache \
        && docker-php-ext-install bcmath
EOF
   run php $phpServer
   mkdirNotDir $phpConfigPath
   copy php:/usr/local/etc/.  $phpConfigPath
   del php
   sudo docker run --name php -v $phpConfigPath:/usr/local/etc -v $projectPath:$projectPath -d $phpServer
   ps
   echo "安装php扩展教程请看：https://hub.docker.com/_/php"
   configText $phpServer $phpConfigPath
}
function pecl {
	echo "扩展：gd、redis、memcached、xdebug、opcache、bcmath"
	read -p "是否安装这些扩展（y/n）：" val
	if [ $val == "y" ];then
		echo $val
	fi
}
function installNginx {
	pull nginx
	run nginx nginx
   	mkdirNotDir $nginxConfigPath
    mkdirNotDir $nginxConfigPath/log
   	copy nginx:/etc/nginx/.  $nginxConfigPath
    copy nginx:/var/log/nginx/. $nginxConfigPath/log
   	del nginx
	sudo docker run --name nginx -v $nginxConfigPath:/etc/nginx -v $projectPath:$projectPath -v /etc/hosts:/etc/hosts  -v $nginxConfigPath/log:/var/log/nginx -p 8080:8080 -d nginx
	ps
	echo "https://hub.docker.com/_/nginx"
	configText nginx $nginxConfigPath
}
function installMysql {
  dbisSetPass
sudo docker buildx build -t mysql -<<EOF
FROM mysql
ENV MYSQL_ROOT_PASSWORD=$mysqlPass
EOF
	run mysql mysql
	mkdirNotDir $mysqlConfigPath
	copy mysql:/etc/my.cnf $mysqlConfigPath/my.cnf
	del mysql
	sudo docker run --name mysql -v $mysqlConfigPath/my.cnf:/etc/my.cnf -v $mysqlConfigPath/data:/var/lib/mysql -p 3306:3306 -d mysql
	ps
	echo "https://hub.docker.com/_/mysql"
	configText mysql $mysqlConfigPath
	echo "mysql初始账户密码：root:${mysqlPass}"
}
function dbisSetPass {
   read -p "是否设置root账户密码,默认是${mysqlPass}（y/n）：" isSetPass
   if [ $isSetPass == "y"  ];then
        read -sp "请设置密码：" password
        if [ ${#password} == 0 ];then
          echo "不能为空，请重新输入！"
        else
          mysqlPass=$password
        fi
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
#删除镜像
function rmi {
	sudo docker rmi $1
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
  		sudo mkdir -p $1
  	else
  		echo "文件夹已经存在"
	fi
}
function compose {
  dbisSetPass
	curl -OL https://github.com/liuguodong1019/docker-nmp/archive/refs/heads/master.zip
	if [ $? == 0 ];then
    unzip main.zip
		sudo rm -rf main.zip
		sudo mv docker-nmp-main/* ./
		sudo rm -rf docker-nmp-main/
		sudo rm -rf README.md
    read -p "使用的是虚拟机吗？（y/n）：" isVm
    if [ $isVm == "y" ];then
      sudo rm -rf compose.yaml
      sudo mv compose-vm.yaml compose.yaml
    else 
      sudo rm -rf compose-vm.yaml
    fi
		sudo docker compose up -d
		if [ $? == 0 ];then
      echo "安装成功"
			sudo docker compose ps -a
			echo "注意：要执行docker compose 相关命令，必须在compose.yaml文件所属目录下执行，命令才会生效，否则会报错(no configuration file provided: not found)"
		else
			sudo docker compose stop
			sudo docker compose rm -f
			sudo docker image rm ${nowDir}-db:latest
			sudo docker image rm ${nowDir}-nginx:latest
			sudo docker image rm ${nowDir}-php:latest
		fi
        fi
}
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
