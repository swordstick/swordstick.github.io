---
published: true
author: David Wan
layout: post
title: DB服务化方案(MHA NODE&MANAGER)
category: CONSUL
summary: MHA NODE&MANAGER部署
tags:
  - Other

---



## 知识准备

> http://www.cnblogs.com/mchina/archive/2013/03/15/2956017.html<br>
> http://www.cnblogs.com/gomysql/p/3675429.html<br>
> 源码解析: http://keithlan.github.io/2016/08/18/mha_source/<br> 


## 机器部署参考


| IP地址| 作用 | 安装内容 | 
| -- | -- | -- | 
| 10.16.4.31 | 主MYSQL | mysql,consul client,mha client|
| 10.16.4.33 | 从MYSQL| mysql,consul client,mha client|
| 10.16.4.109 | 从MYSQL | mysql,consul client,mha client |
| 10.16.6.125 | mha manager | mha manager |
| 10.16.4.30 | consul server | consul server |
| 10.16.6.126 | consul server | consul server |
| 10.16.6.127 | consul server | consul server |
| 10.16.6.124 | proxy | kgshard,consul template | 
| 10.16.6.128 | proxy | kgshard,consul template | 
| 10.16.6.129 | proxy | kgshard,consul template | 

## 环境定义 -- 便于理解后面的安装步骤

### 定义各类路径

| Key | Value |
| -- | -- | 
| node base dir | /usr/local/mha/ | 
| manager base dir | /usr/local/mha/ |
| config dir | /data1/mha/etc/ | 
| manager work dir | /data1/mha/mg_apps/ |
| remote workdir | /data1/mha/node_apps/ | 
| manager log dir | /data1/mha/mg_logs/ | 
| binlog_dir | /data1/mysql/{port}/binlog/ | 
| script log dir | /data1/mha/scripts/ | 


### 定义数据库用户

| 类别 | 用户 | 细则| 
| -- | -- | -- |
| SSH | mha | 监控用MYSQL账户 | 


### 定义SSH账户
***mha:mysql***


## 配置SSH

### 建立ssh账号

```
useradd mha -u 512 -G mysql -d /home/mha
passwd mha


[root@Dev_10_16_4_33 mha]# groups mha
mha : mha mysql
//查询可以观察到mha属于mha和mysql2个组
//-G，使得mha有多个组
```

### 公私钥生产和赋予

#### binlog授权（每台DB上执行一次）

```
chmod g+r /data1/mysql/3306/binlog
chmod g+w /data1/mysql/3306/binlog
chmod g+r /data1/mysql/3306
chmod g+w /data1/mysql/3306
```

#### 在mha账号中建立公私密钥（每台机器上执行一次）

```
ssh-keygen
//注意，这里不能设置密码
```

#### 同时将自己的公钥也添加到授权文件中（每台机器上执行一次）

```
cat /home/mha/.ssh/id_rsa.pub > /home/mha/.ssh/authorized_keys
chmod 600 /home/mha/.ssh/authorized_keys
```

#### 建立节点间信任,节点和管理节点信任做法一致


```
// 在公钥所有机器上操作
rsync --log-file=rsync.log -avzuhP     /home/mha/.ssh/id_rsa.pub   rsync@ip::upload
//在获取公钥的机器上操作
cat /data1/upload/id_rsa.pub >> /home/mha/.ssh/authorized_keys
chmod 600 /home/mha/.ssh/authorized_keys
chmod 700 /home/mha/.ssh
```

### 调整sshd配置

```

//root 下
是否允许使用基于 GSSAPI 的用户认证：关闭认证
/etc/ssh/sshd_config
#GSSAPIAuthentication no 
service sshd reload

echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config
service sshd reload

//mha下
su - mha
echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/mha/bin:/root/bin" > /home/mha/.ssh/environment

```




## MYSQL配置

### 建立实例账号

> 在主库执行即可

```
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SUPER ON *.* TO 'mha'@'10.16.%' IDENTIFIED BY 'mha';
```

### 建立MHA的数据库节点，每个节点成为其他节点主库的权限

> 切换过程中，从库变为主库，需要提前配好权限

```
GRANT replication slave ON  *.*  TO slave@'' IDENTIFIED BY '';
//此处隐去密码
```


### 从库只读,在线修改而不是配置修改

```
set global read_only=1
```

### relay log的处理

```
//从库调整
# 设置relay log的清除方式
set global relay_log_purge=0
# 设置relay log的清除定时脚本

```


## MHA安装


### 软件下载


##### NODE下载


* 官网下载

```
https://code.google.com/p/mysql-master-ha/wiki/Downloads?tm=2
//rpm包
http://www.mysql.gr.jp/frame/modules/bwiki/index.php?plugin=attach&pcmd=open&file=mha4mysql-node-0.56-0.el6.noarch.rpm&refer=matsunobu
//源码
https://downloads.mariadb.com/MHA/mha4mysql-node-0.56.tar.gz
```

* 平台下载地址为

```
//本次采用了源码安装
wget http://software.kgidc.cn/src/mha/mha4mysql-node-0.56.tar.gz
wget http://software.kgidc.cn/src/mha/mha4mysql-node-0.56-0.el6.noarch.rpm
```

##### MANAGER下载

* 官网下载

```
https://code.google.com/p/mysql-master-ha/wiki/Downloads?tm=2
//rpm包
http://www.mysql.gr.jp/frame/modules/bwiki/index.php?plugin=attach&pcmd=open&file=mha4mysql-manager-0.56-0.el6.noarch.rpm&refer=matsunobu
//源码
https://downloads.mariadb.com/MHA/mha4mysql-manager-0.56.tar.gz
```


* 平台下载地址为

```
//本次采用了源码安装
wget http://software.kgidc.cn/src/mha/mha4mysql-manager-0.56.tar.gz
wget http://software.kgidc.cn/src/mha/mha4mysql-manager-0.56-0.el6.noarch.rpm
```



### 依赖包安装

```
yum install perl-DBD-MySQL -y
yum install perl-DBD-MySQL perl-Config-Tiny perl-Log-Dispatch perl-Parallel-ForkManager perl-Time-HiRes -y
yum -y install perl-CPAN
```

### NODE 源码安装

#### 增加MHA账号权限

```
//若MHA安装过则此处不必采用
//useradd mha -u 512 -G mysql -d /home/mha
//passwd mha


mkdir -p /usr/local/mha
chown -R mha:mysql /usr/local/mha
```

#### 安装

```
tar zxvf mha4mysql-node-0.56.tar.gz
cd mha4mysql-node-0.56
perl Makefile.PL INSTALL_BASE=/usr/local/mha
make && make install
chown -R mha:mysql /usr/local/mha/

//mkdir 很重要，否则后面的ln不能起作用
//若后面内容没有完成，会导致manager安装的时候，无法找到MHA::NodeConst
//原因是，无法定位到mha的lib库

mkdir -p /usr/local/share/perl5/
ln -s /usr/local/mha/lib/perl5/MHA /usr/local/share/perl5/MHA
echo '/usr/local/share/perl5/MHA' >> /etc/ld.so.conf

```


### MANAGER 源码安装

> 因为MANAGER需要使用NODE的lib库，所以在MHA MANAGER节点，需要先行安装NODE，而后在安装MANAGER

#### 增加MHA账号权限

> 因为安装NODE在线，所以此处实际不需要，只是提醒

```
useradd mha -u 512 -G mysql -d /home/mha
passwd mha


mkdir -p /usr/local/mha
chown -R mha:mysql /usr/local/mha
```

#### 安装

```
tar zxvf mha4mysql-manager-0.56.tar.gz
cd mha4mysql-manager-0.56
perl Makefile.PL INSTALL_BASE=/usr/local/mha
make && make install
chown -R mha:mysql /usr/local/mha/
```


### 配置MHA环境

#### 建立mha对mysqlbinlog的操作路径(NODE ONLY)

```
ln -s /usr/local/mysql/bin/mysqlbinlog /usr/local/bin/
ln -s /usr/local/mysql/bin/mysql /usr/local/bin/
// 将其写入mha账号的环境变量亦可
```

#### 修改配置(NODE ONLY)

> my.cnf

```
//注释掉default-character-set=utf8
```

#### 建立目录(NODE & MANAGER)

```

//manager
mkdir -p /data1/mha/mg_apps/
mkdir -p /data1/mha/mg_logs/
mkdir -p /data1/mha/etc/
mkdir -p /data1/mha/scripts/
chown -R mha:mysql /data1/mha/

//node
mkdir -p /data1/mha/node_apps/
mkdir -p /data1/mha/etc/
mkdir -p /data1/mha/scripts/

chown -R mha:mysql /data1/mha/

```


#### 配置ENV(NODE & MANAGER)


```
echo "MHA_NODE_PATH=/usr/local/mha/bin" >> /etc/profile
echo "export PATH=\$PATH:\$MHA_NODE_PATH" >> /etc/profile

source /etc/profile
```

#### 编写MHA配置文件(MANAGER ONLY)

> manager和node配置放在同一文件，测试为demo.conf
> vi demo.conf


```
# 注意//在MHA的配置文件中不是注释，不可出现
# Manager
[server default]
password=mha
#设置mysql中mha用户的密码，这个密码是前文中创建监控用户的那个密码
user=mha
#设置监控用户mha
repl_password=''
#设置复制用户的密码，注意设置，此处隐去
repl_user=slave         
#设置复制环境中的复制用户名
ssh_user=mha
#设置ssh的登录用户名
ssh_port=32200
log_level=info

# Check
##secondary_check_script= masterha_secondary_check -s 10.16.4.33 -s 10.16.4.109
## 此参数在真实情况下，配置为非本路由器的其他2台稳定机器
## 这是增加链路探测安全性所使用

ping_interval=3
#设置监控主库，发送ping包的时间间隔，默认是3秒，尝试三次没有回应的时候自动进行railover
ping_type=CONNECT
## 使用短连接探测


# Failover DIY Scripts
#注释掉mha中关闭脚本，以便测试用途
# ------------------------
master_ip_failover_script= /data1/mha/scripts/master_ip_failover    
#设置自动failover时候的切换脚本这里可以使用你自己的脚本，结合dns或者haproxy完成切换的完整工作

# shutdown_script= scripts/power_manager 
#设置故障发生后关闭故障主机脚本（该脚本的主要作用是关闭主机放在发生脑裂,这里没有使用）

# Online change Scripts
master_ip_online_change_script= /data1/mha/scripts/master_ip_online_change  
#设置手动切换时候的切换脚本

# report
# report_script= scripts/send_report 
#设置发生切换后发送的报警的脚本

# dir
manager_workdir=/data1/mha/mg_apps            
#设置manager的工作目录
manager_log=/data1/mha/mg_logs/manager.log          
#设置manager的日志
master_binlog_dir=/data1/mysql/3306/binlog                       
#设置master 保存binlog的位置，以便MHA可以找到master的日志，我这里的也就是mysql的数据目录
remote_workdir= /data1/mha/node_apps  
#设置远端mysql在发生切换时binlog的保存位置
# 不要让目录后面带上/，否则会导致类似
# /data1/mha/mg_apps//10.16.4.109_3306_20161127015437.log

# Const
client_bindir=/usr/local/mysql/bin
client_libdir=/usr/local/mysql/lib

# Node
[server1]
hostname=10.16.4.31
port=3306
node_label=demo

[server2]
hostname=10.16.4.33
port=3306
#candidate_master=1   
#设置为候选master，如果设置该参数以后，发生主从切换以后将会将此从库提升为主库，即使这个主库不是集群中事件最新的slave
#check_repl_delay=0   
#默认情况下如果一个slave落后master 100M的relay logs的话，MHA将不会选择该slave作为一个新的master，因为对于这个slave的恢复需要花费很长时间，通过设置check_repl_delay=0,MHA触发切换在选择一个新的master的时候将会忽略复制延时，这个参数对于设置了candidate_master=1的主机非常有用，因为这个候选主在切换的过程中一定是新的master
node_label=demo

[server3]
hostname=10.16.4.109
port=3306
node_label=demo

```

#### 编写FIALOVER脚本

> master_ip_failover
> masterha_master_switch脚本在ONLINE切换中也会调用
> manager 在探测到故障时，会调用此脚本


```
#!/usr/bin/env perl

#  Copyright (C) 2011 DeNA Co.,Ltd.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

## Note: This is a sample script and is not complete. Modify the script based on your environment.

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use MHA::DBHelper;

my (
  $command,        $ssh_user,         $orig_master_host,
  $orig_master_ip, $orig_master_port, $new_master_host,
  $new_master_ip,  $new_master_port,  $new_master_user,
  $new_master_password
);
GetOptions(
  'command=s'             => \$command,
  'ssh_user=s'            => \$ssh_user,
  'orig_master_host=s'    => \$orig_master_host,
  'orig_master_ip=s'      => \$orig_master_ip,
  'orig_master_port=i'    => \$orig_master_port,
  'new_master_host=s'     => \$new_master_host,
  'new_master_ip=s'       => \$new_master_ip,
  'new_master_port=i'     => \$new_master_port,
  'new_master_user=s'     => \$new_master_user,
  'new_master_password=s' => \$new_master_password,
);

exit &main();

sub main {
  if ( $command eq "stop" || $command eq "stopssh" ) {

    # $orig_master_host, $orig_master_ip, $orig_master_port are passed.
    # If you manage master ip address at global catalog database,
    # invalidate orig_master_ip here.
    my $exit_code = 1;
    eval {

      # updating global catalog, etc
      print "Disabling the old master: $orig_master_host to Fail \n";
      &fail_master();
      $exit_code = 0;
    };
    if ($@) {
      warn "Got Error: $@\n";
      exit $exit_code;
    }
    exit $exit_code;
  }
  elsif ( $command eq "start" ) {

    # all arguments are passed.
    # If you manage master ip address at global catalog database,
    # activate new_master_ip here.
    # You can also grant write access (create user, set read_only=0, etc) here.
    my $exit_code = 10;
    eval {
      my $new_master_handler = new MHA::DBHelper();

      # args: hostname, port, user, password, raise_error_or_not
      $new_master_handler->connect( $new_master_ip, $new_master_port,
        $new_master_user, $new_master_password, 1 );

      ## Set read_only=0 on the new master
      $new_master_handler->disable_log_bin_local();
      print "Set read_only=0 on the new master.\n";
      $new_master_handler->disable_read_only();

      ## Creating an app user on the new master
      print "Creating app user on the new master..\n";
##      FIXME_xxx_create_user( $new_master_handler->{dbh} );
      $new_master_handler->enable_log_bin_local();
      $new_master_handler->disconnect();

      ## Update master ip on the catalog database, etc
      print "Enable the new master: $new_master_ip to Consul \n";
      &register_master();
      ## FIXME_xxx;

      $exit_code = 0;
    };
    if ($@) {
      warn $@;

      # If you want to continue failover, exit 10.
      exit $exit_code;
    }
    exit $exit_code;
  }
  elsif ( $command eq "status" ) {

    # do nothing
    exit 0;
  }
  else {
    &usage();
    exit 1;
  }
}

sub fail_master() {
    `sed -i \"s/master/fail/g\" /etc/consul.d/database.json`;
    `consul reload`;
}


sub register_master() {
    `sed -i \"s/fail/master/g\" /etc/consul.d/database.json`;
    `sed -i \"s/$orig_master_host/$new_master_host/g\" /etc/consul.d/database.json`;
    `consul reload`;
}

sub usage {
  print
"Usage: master_ip_failover --command=start|stop|stopssh|status --orig_master_host=host --orig_master_ip=ip --orig_master_port=port --new_master_host=host --new_master_ip=ip --new_master_p
ort=port\n";
}
```

### 编写master_ip_online_change

> 手动切换所用，即为masterha_master_switch所调用

```
#!/usr/bin/env perl

#  Copyright (C) 2011 DeNA Co.,Ltd.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

## Note: This is a sample script and is not complete. Modify the script based on your environment.

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use MHA::DBHelper;
use MHA::NodeUtil;
use Time::HiRes qw( sleep gettimeofday tv_interval );
use Data::Dumper;

my $_tstart;
my $_running_interval = 0.1;
my (
  $command,          $orig_master_host, $orig_master_ip,
  $orig_master_port, $orig_master_user, $orig_master_password,
  $new_master_host,  $new_master_ip,    $new_master_port,
  $new_master_user,  $new_master_password
);
GetOptions(
  'command=s'              => \$command,
  'orig_master_host=s'     => \$orig_master_host,
  'orig_master_ip=s'       => \$orig_master_ip,
  'orig_master_port=i'     => \$orig_master_port,
  'orig_master_user=s'     => \$orig_master_user,
  'orig_master_password=s' => \$orig_master_password,
  'new_master_host=s'      => \$new_master_host,
  'new_master_ip=s'        => \$new_master_ip,
  'new_master_port=i'      => \$new_master_port,
  'new_master_user=s'      => \$new_master_user,
  'new_master_password=s'  => \$new_master_password,
);

exit &main();

sub current_time_us {
  my ( $sec, $microsec ) = gettimeofday();
  my $curdate = localtime($sec);
  return $curdate . " " . sprintf( "%06d", $microsec );
}

sub sleep_until {
  my $elapsed = tv_interval($_tstart);
  if ( $_running_interval > $elapsed ) {
    sleep( $_running_interval - $elapsed );
  }
}

sub get_threads_util {
  my $dbh                    = shift;
  my $my_connection_id       = shift;
  my $running_time_threshold = shift;
  my $type                   = shift;
  $running_time_threshold = 0 unless ($running_time_threshold);
  $type                   = 0 unless ($type);
  my @threads;

  my $sth = $dbh->prepare("SHOW PROCESSLIST");
  $sth->execute();

  while ( my $ref = $sth->fetchrow_hashref() ) {
    my $id         = $ref->{Id};
    my $user       = $ref->{User};
    my $host       = $ref->{Host};
    my $command    = $ref->{Command};
    my $state      = $ref->{State};
    my $query_time = $ref->{Time};
    my $info       = $ref->{Info};
    $info =~ s/^\s*(.*?)\s*$/$1/ if defined($info);
    next if ( $my_connection_id == $id );
    next if ( defined($query_time) && $query_time < $running_time_threshold );
    next if ( defined($command)    && $command eq "Binlog Dump" );
    next if ( defined($user)       && $user eq "system user" );
    next
      if ( defined($command)
      && $command eq "Sleep"
      && defined($query_time)
      && $query_time >= 1 );

    if ( $type >= 1 ) {
      next if ( defined($command) && $command eq "Sleep" );
      next if ( defined($command) && $command eq "Connect" );
    }

    if ( $type >= 2 ) {
      next if ( defined($info) && $info =~ m/^select/i );
      next if ( defined($info) && $info =~ m/^show/i );
    }

    push @threads, $ref;
  }
  return @threads;
}

sub main {
  if ( $command eq "stop" ) {
    ## Gracefully killing connections on the current master
    # 1. Set read_only= 1 on the new master
    # 2. DROP USER so that no app user can establish new connections
    # 3. Set read_only= 1 on the current master
    # 4. Kill current queries
    # * Any database access failure will result in script die.
    my $exit_code = 1;
    eval {
      ## Setting read_only=1 on the new master (to avoid accident)
      my $new_master_handler = new MHA::DBHelper();

      # args: hostname, port, user, password, raise_error(die_on_error)_or_not
      $new_master_handler->connect( $new_master_ip, $new_master_port,
        $new_master_user, $new_master_password, 1 );
      print current_time_us() . " Set read_only on the new master.. ";
      $new_master_handler->enable_read_only();
      if ( $new_master_handler->is_read_only() ) {
        print "ok.\n";
      }
      else {
        die "Failed!\n";
      }
      $new_master_handler->disconnect();

      # Connecting to the orig master, die if any database error happens
      my $orig_master_handler = new MHA::DBHelper();
      $orig_master_handler->connect( $orig_master_ip, $orig_master_port,
        $orig_master_user, $orig_master_password, 1 );

      ## Drop application user so that nobody can connect. Disabling per-session binlog beforehand
      $orig_master_handler->disable_log_bin_local();
      print current_time_us() . " Drpping app user on the orig master..\n";
##FIXME_xxx_drop_app_user($orig_master_handler);

      ## Waiting for N * 100 milliseconds so that current connections can exit
      my $time_until_read_only = 15;
      $_tstart = [gettimeofday];
      my @threads = get_threads_util( $orig_master_handler->{dbh},
        $orig_master_handler->{connection_id} );
      while ( $time_until_read_only > 0 && $#threads >= 0 ) {
        if ( $time_until_read_only % 5 == 0 ) {
          printf
"%s Waiting all running %d threads are disconnected.. (max %d milliseconds)\n",
            current_time_us(), $#threads + 1, $time_until_read_only * 100;
          if ( $#threads < 5 ) {
            print Data::Dumper->new( [$_] )->Indent(0)->Terse(1)->Dump . "\n"
              foreach (@threads);
          }
        }
        sleep_until();
        $_tstart = [gettimeofday];
        $time_until_read_only--;
        @threads = get_threads_util( $orig_master_handler->{dbh},
          $orig_master_handler->{connection_id} );
      }

      ## Setting read_only=1 on the current master so that nobody(except SUPER) can write
      print current_time_us() . " Set read_only=1 on the orig master.. ";
      $orig_master_handler->enable_read_only();
      if ( $orig_master_handler->is_read_only() ) {
        print "ok.\n";
      }
      else {
        die "Failed!\n";
      }

      ## Waiting for M * 100 milliseconds so that current update queries can complete
      my $time_until_kill_threads = 5;
      @threads = get_threads_util( $orig_master_handler->{dbh},
        $orig_master_handler->{connection_id} );
      while ( $time_until_kill_threads > 0 && $#threads >= 0 ) {
        if ( $time_until_kill_threads % 5 == 0 ) {
          printf
"%s Waiting all running %d queries are disconnected.. (max %d milliseconds)\n",
            current_time_us(), $#threads + 1, $time_until_kill_threads * 100;
          if ( $#threads < 5 ) {
            print Data::Dumper->new( [$_] )->Indent(0)->Terse(1)->Dump . "\n"
              foreach (@threads);
          }
        }
        sleep_until();
        $_tstart = [gettimeofday];
        $time_until_kill_threads--;
        @threads = get_threads_util( $orig_master_handler->{dbh},
          $orig_master_handler->{connection_id} );
      }

      ## Terminating all threads
      print current_time_us() . " Killing all application threads..\n";
      $orig_master_handler->kill_threads(@threads) if ( $#threads >= 0 );
      print current_time_us() . " done.\n";
      $orig_master_handler->enable_log_bin_local();
      $orig_master_handler->disconnect();

      ## After finishing the script, MHA executes FLUSH TABLES WITH READ LOCK
      $exit_code = 0;
    };
    if ($@) {
      warn "Got Error: $@\n";
      exit $exit_code;
    }
    exit $exit_code;
  }
  elsif ( $command eq "start" ) {
    ## Activating master ip on the new master
    # 1. Create app user with write privileges
    # 2. Moving backup script if needed
    # 3. Register new master's ip to the catalog database

# We don't return error even though activating updatable accounts/ip failed so that we don't interrupt slaves' recovery.
# If exit code is 0 or 10, MHA does not abort
    my $exit_code = 10;
    eval {
      my $new_master_handler = new MHA::DBHelper();

      # args: hostname, port, user, password, raise_error_or_not
      $new_master_handler->connect( $new_master_ip, $new_master_port,
        $new_master_user, $new_master_password, 1 );

      ## Set read_only=0 on the new master
      $new_master_handler->disable_log_bin_local();
      print current_time_us() . " Set read_only=0 on the new master.\n";
      $new_master_handler->disable_read_only();

      ## Creating an app user on the new master
      print current_time_us() . " Creating app user on the new master..\n";
      ## FIXME_xxx_create_app_user($new_master_handler);
      $new_master_handler->enable_log_bin_local();
      $new_master_handler->disconnect();

      ## Update master ip on the catalog database, etc
      print "Enable the new master: $new_master_ip to Consul \n";
      &register_master();
      $exit_code = 0;
    };
    if ($@) {
      warn "Got Error: $@\n";
      exit $exit_code;
    }
    exit $exit_code;
  }
  elsif ( $command eq "status" ) {

    # do nothing
    exit 0;
  }
  else {
    &usage();
    exit 1;
  }
}

sub register_master() {
    `sed -i \"s/$orig_master_host/$new_master_host/g\" /etc/consul.d/database.json`;
    `consul reload`;
}

sub usage {
  print
"Usage: master_ip_online_change --command=start|stop|status --orig_master_host=host --orig_master_ip=ip --orig_master_port=port --new_master_host=host --new_master_ip=ip --new_master_port
=port\n";
  die;
}
```


## MHA检查

### 检查ssh通讯

```
mha$ masterha_check_ssh --conf=/data1/mha/etc/demo.conf
```

### 检查集群同步

```
mha$ masterha_check_repl --conf=/data1/mha/etc/demo.conf
// master_ip_failover_script 没有编写,为了便于测试,可以在demo.yaml中注释掉
// 当master_ip_failover_script编写正常后，其不妨碍集群同步的检查
```


## MHA手动切换 

> 特别注意：此时不可打开自动切换用的MANAGER进程<br>
> 管理进程会干扰手动切换<br>
> 其会调用ONLINE和FAILOVER脚本<br>


```
masterha_master_switch --conf=/data1/mha/etc/demo.conf --master_state=alive --new_master_host=10.16.4.31 --new_master_port=3306 --orig_master_is_new_slave --running_updates_limit=10000  
# 该命令不会在原master上面，关闭掉原来的slave连接，说明需要在online脚本中写入
# 该命令会自动调整只读为0
# 该命令如果中间退出，则容易导致混乱
# 所有的slave账号都应该互通有无
# 该命令完成后，manager会退出
```



## 启动MHA MANAGER

```
// 必须在mha账号启动，否则会失败，ssh检测会失败

mha$ setsid masterha_manager --conf=/data1/mha/etc/demo.conf &

// 本次测试，实际封装在supervisord中
supervisord -c /etc/supervisord.conf 启动
supervisorctl shutdown
supervisorctl status
supervisorctl reload
```


## MHA测试过程遇到问题

* manager启动下，掐断某个slave，并未启动真实的切换

```
masterha_manager 启动下
# manager启动下，掐断某个slave，并未启动真实的切换
# 检查为，candidate_master=1   配置在了33，而当时33已然是主库
# 这说明指定candidate_master=1   ，在切换过之后，该配置需要修改
```

* manager切换完成后,进程manager会退出

* manager 上次切换太久则会放弃反复切换

```
manager启动切换前，会检查/data1/mha/mg_apps/demo.failover.complete，如果生产时间过近，则会放弃切换，并报警到/data1/mha/mg_logs/manager.log中

检查日志文件 ： /data1/mha/mg_logs/manager.log
并生成文件 ：demo.failover.complete

若在测试中，可手动删除demo.failover.complete文件

```



### 补充信息

```
参数的说明：

1. no_master
no_master=1是默认值,意思是这个server从来不会成为新的master,这个参数用来标记某些从来不用成为new master的服务器。
2. ignore_fail
默认是0,当某个slave的ssh或者mysql当掉或者复制失败的时候,MHA manager不启动failover。但是有些环境下,你想要在某个特定的slave失败的时候继续执行failover,把么就设置这个 ignore_fail=1,即时这个slave失败的时候,failover依然继续执行.
```



