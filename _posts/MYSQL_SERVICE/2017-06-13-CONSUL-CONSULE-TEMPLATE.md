---
published: true
author: David Wan
layout: post
title: DB服务化方案(CONSUL&CONSULE-TEMPLATE)
category: CONSUL
summary: CONSUL以及CONSUL-TEMPLATE部署
tags:
  - Other

---


## CONSUL部署


###基础知识学习

> 基本学习<br>
> https://skyao.gitbooks.io/leaning-consul/content/docs/internals/architecture.html<br>
> http://tonybai.com/2015/07/06/implement-distributed-services-registery-and-discovery-by-consul/<br>
> http://zenvv.com/2016/05/17/consul-cluster-config/<br>
> http://minjing.coding.me/2016/05/01/Consul-Getting-Started-06-KeyValue-Data/<br>


## CONSUL安装配置


### 机器部署参考

| IP地址| 作用 | 安装内容 | 
| -- | -- | -- | 
| 10.16.4.31 | 主MYSQL | mysql,consul client,mha node |
| 10.16.4.33 | 从MYSQL| mysql,consul clint,mha node |
| 10.16.4.109 | 从MYSQL | mysql,consul clint,mha node |
| 10.16.6.125 | mha manager | mha manager |
| 10.16.4.30 | consul server | consul server |
| 10.16.6.126 | consul server | consul server |
| 10.16.6.127 | consul server | consul server |
| 10.16.6.124 | proxy | kgshard,consul template,consul clint | 
| 10.16.6.128 | proxy | kgshard,consul template,consul clint | 
| 10.16.6.129 | proxy | kgshard,consul template,consul clint | 


###软件下载

* 官方下载

```
https://releases.hashicorp.com/consul/0.7.1/consul_0.7.1_linux_amd64.zip
```
* 公司下载 

```
wget http://software.kgidc.cn/src/mha/consul_0.7.1_linux_amd64.zip
```


### 建立集群

> 建立SERVER节点

* 安装

```
mkdir -p /data1/software/
cd /data1/software/
wget http://software.kgidc.cn/src/mha/consul_0.7.1_linux_amd64.zip
unzip consul_0.7.1_linux_amd64.zip 
cp consul /usr/local/bin/
```

* 启动

```
//4.30
mkdir -p /tmp/consul/
setsid consul agent -server -bootstrap-expect 3 -data-dir /tmp/consul -node=n1 -bind=10.16.4.30 -dc=dc1 &
//6.126
mkdir -p /tmp/consul/
setsid consul agent -server -bootstrap-expect 3 -data-dir /tmp/consul -node=n2 -bind=10.16.6.126 -dc=dc1 &
//6.127
mkdir -p /tmp/consul/
setsid consul agent -server -bootstrap-expect 3 -data-dir /tmp/consul -node=n3 -bind=10.16.6.127 -dc=dc1 &
//每台机器执行
consul join 10.16.6.125
consul join 10.16.6.125
consul join 10.16.6.125

```

* 检查

```
$consul info
$consul members
$consul leave
```



> 建立client节点

* 安装

```
mkdir -p /data1/software
cd /data1/software
wget http://software.kgidc.cn/src/mha/consul_0.7.1_linux_amd64.zip
unzip consul_0.7.1_linux_amd64.zip 
cp consul /usr/local/bin/
```

* 服务注册文件及check脚本配置

//consul client一般用来注册服务，所以带有配置文件和检测脚本

```
mkdir -p /etc/consul.d
cd /etc/consul.d
## 服务注册文件
mkdir -p /etc/consul_script
cd /etc/consul_script
## check.sh文件

//如果检测命令返回一个非0的返回码，那么该节点将被标记为不健康。
//检测和配置实例
```

>vi check.sh

```
#!/bin/bash

# process status check.
# check.sh mysqld

id=$(ps -C $1|grep $1|awk '{print $1}')

len=${#id}
if [ "$len" -gt 0 ]
then
	echo "running, pid: $id";
	exit 0;
else
	echo 'not running';
	exit 1;
fi
```

> database.json 在所有的数据库上面部署，tag都是slave



```
{
	  "service": {
	    "name": "dbdemo",
	    "tags": ["slave"],
	    "address": "10.16.4.31",
	    "port": 3306,
	    "checks": [
	      {
	        "script": "/etc/consul_script/check.sh mysqld",
	        "interval": "5s"
	      }
	    ]
	  }
	}
```


> database.json 在MHA上面部署，tag是master



```
{
	  "service": {
	    "name": "dbdemo",
	    "tags": ["master"],
	    "address": "10.16.4.31",
	    "port": 3306
	  }
	}
```




> 主机方面的检测.目前价值并不大，暂未部署

>vi ping.json

```
{
"check": 
	{"name": "ping",
	 "script": "ping ddd >/dev/null", 
	}
}
```


* 启动DB上的agent，都是slave标签

```
//4.31
setsid consul agent -data-dir /tmp/consul -node=dbn1 -bind=10.16.4.31 -dc=dc1 -config-dir=/etc/consul.d &
//4.33
setsid consul agent -data-dir /tmp/consul -node=dbn2 -bind=10.16.4.33 -dc=dc1 -config-dir=/etc/consul.d &
//4.109
setsid consul agent -data-dir /tmp/consul -node=dbn3 -bind=10.16.4.109 -dc=dc1 -config-dir=/etc/consul.d &

consul join 10.16.6.125
consul join 10.16.6.125
consul join 10.16.6.125
```

* 启动mha上的agent，标签为master

```
//6.125
setsid consul agent -data-dir /tmp/consul -node=dbn0 -bind=10.16.6.125 -dc=dc1 -config-dir=/etc/consul.d &

consul join 10.16.6.126
```


* 检查

```
$consul info
$consul members
$consul leave
```


## CONSUL注册发现使用方式

### 查询方式

#### 第一类: DNS API

```
对于DNS API，服务的DNS名称是 NAME.service.consul 。默认所有的DNS名称都是在 consul 名称空间下，当然这个是可配置的。service 子域名告诉Consul我们正在查询服务，并且 NAME 就是要查询的服务的名称。

dig @127.0.0.1 -p 8600 dbdemo.service.consul 
dig @127.0.0.1 -p 8600 master.dbdemo.service.consul 

dig @127.0.0.1 -p 8600 dbdemo.service.consul SRV
dig @127.0.0.1 -p 8600 master.dbdemo.service.consul SRV

//dbdemo为database.json中的server名称，应该设计为DB所属业务模块的server名称
//master是标签，也就是database.json中的tag名称

```

#### 第二类: HTTP

```
$ curl http://localhost:8500/v1/catalog/service/dbdemo
$ curl 'http://localhost:8500/v1/health/service/dbdemo?passing'
```

#### 第三类：CONSUL TEMPLATE

请参考consul template页面

### KV的使用

> 查询参考

```
$ curl http://localhost:8500/v1/catalog/service/web
$ curl 'http://localhost:8500/v1/health/service/web?passing'
```


> 增加参考,?号代表后面跟着一个变量

```
$ curl -X PUT -d 'test' http://localhost:8500/v1/kv/dbdemo/key1
true
$ curl -X PUT -d 'test' http://localhost:8500/v1/kv/dbdemo/key2?flags=42
true
$ curl -X PUT -d 'test'  http://localhost:8500/v1/kv/dbdemo/sub/key3
true
$ curl http://localhost:8500/v1/kv/?recurse
[{"CreateIndex":97,"ModifyIndex":97,"Key":"dbdemo/key1","Flags":0,"Value":"dGVzdA=="},
 {"CreateIndex":98,"ModifyIndex":98,"Key":"dbdemo/key2","Flags":42,"Value":"dGVzdA=="},
 {"CreateIndex":99,"ModifyIndex":99,"Key":"dbdemo/sub/key3","Flags":0,"Value":"dGVzdA=="}]
```


> 删除参考

```
$ curl http://localhost:8500/v1/kv/dbdemo/key1
$ curl -X DELETE http://localhost:8500/v1/kv/dbdemo/sub?recurse
$ curl http://localhost:8500/v1/kv/dbdemo?recurse
https://github.com/ynu/consul/blob/master/scripts/psc.sh
```




## CONSUL TEMPLATE部署



## 基础知识学习


> https://github.com/hashicorp/consul-template<br>
> https://www.hashicorp.com/blog/introducing-consul-template.html<br>


## CONSUL TAMPLATE安装配置

### 机器部署参考

| IP地址| 作用 | 安装内容 | 
| -- | -- | -- | 
| 10.16.4.31 | 主MYSQL | mysql,consul client,mha node |
| 10.16.4.33 | 从MYSQL| mysql,consul clint,mha node |
| 10.16.4.109 | 从MYSQL | mysql,consul clint,mha node |
| 10.16.6.125 | mha manager | mha manager |
| 10.16.4.30 | consul server | consul server |
| 10.16.6.126 | consul server | consul server |
| 10.16.6.127 | consul server | consul server |
| 10.16.6.124 | proxy | kgshard,consul template,consul clint | 
| 10.16.6.128 | proxy | kgshard,consul template,consul clint | 
| 10.16.6.129 | proxy | kgshard,consul template,consul clint | 



### 软件下载

* 官方下载


```
https://github.com/hashicorp/consul-template/releases
https://codeload.github.com/hashicorp/consul-template/tar.gz/v0.16.0
```

* 平台下载

```
wget http://software.kgidc.cn/src/mha/consul-template-0.16.0.tar.gz
wget http://software.kgidc.cn/src/mha/consul-template_0.16.0_linux_amd64.zip
//使用后者安装，可以避免麻烦，解压直接用
```

### 安装

```
unzip consul-template_0.16.0_linux_amd64.zip
mv consul-template /usr/local/bin/
```

### 配置

> consul template使用的配置文件

//本次部署中未使用配置文件，正式环境请使用配置文件

```
mkdir -p /etc/consul-template.d
cd /etc/consul-template.d
vi demo.cnf 
# 这是consul的配置文件，而不是ctmpl文件
consul = "127.0.0.1:8500" //为了不在每个应用上面部署agent，将此IP改为域名，并且用域名轮询,测试中使用本地agent
template {
  source = "/path/on/disk/to/template.ctmpl"
  destination = "/path/on/disk/where/template/will/render.txt"
  command = "restart service foo"
  backup = true
}
```

> kingshard的ctmpl文件,即模板，若使用haproxy或者mysql router，atals，都按照格式编写即可

```
# server listen addr
addr : 0.0.0.0:9696

# server user and password
user :  kingshard
password : kingshard

# the web api server
web_addr : 0.0.0.0:9797
#HTTP Basic Auth
web_user : admin
web_password : admin

# if set log_path, the sql log will write into log_path/sql.log,the system log
# will write into log_path/sys.log
#log_path : /Users/flike/log

# log level[debug|info|warn|error],default error
log_level : debug

# if set log_sql(on|off) off,the sql log will not output
#log_sql: off

# only log the query that take more than slow_log_time ms
slow_log_time : 100

# blacklist sql file path
# all these sqls in this file will been forbidden by kingshard
#blacklist_sql_file: /Users/flike/blacklist

# only allow this ip list ip to connect kingshard
#allow_ips: 127.0.0.1

# the charset of kingshard, if you don't set this item
# the default charset of kingshard is utf8.
#proxy_charset: gbk

# node is an agenda for real remote mysql server.
nodes :
-
    name : node1

    # default max conns for mysql server
    max_conns_limit : 1000

    # all mysql in a node must have the same user and password
    user : kingshard
    password : kingshard

    # master represents a real mysql master server
    master : {{range service "master.dbdemo"}} {{.Address}}:{{.Port}}{{end}}




    # slave represents a real mysql salve server,and the number after '@' is
    # read load weight of this slave.
    slave : {{range service "slave.dbdemo"}} {{.Address}}:{{.Port}},{{end}}
    down_after_noalive : 32

# schema defines which db can be used by client and this db's sql will be executed in which nodes, 
# the db is also the default database
schema :
    db : mysql 
    nodes: [node1]
    default: node1
    shard:
    -
```


#### 启动

> 注意，为了让reload更为方便，利用了封装的/usr/bin/supervisorctl reload.

```
// 使用配置文件启动
setsid consul-template  -config=/etc/consul-template.d/demo.cnf &

// 使用命令行参数启动
setsid consul-template -template="/etc/consul-template.d/kingshard.ctmpl:/etc/kingshard.d/demo.yaml:/usr/bin/supervisorctl reload" &

// 使用-dry参数启动，这种情况下不会真实修改目标文件，只是打印到屏幕，用于观察
consul-template -template="/etc/consul-template.d/kingshard.ctmpl:/etc/kingshard.d/demo.yaml" -dry


```



### 观察

#### 第一步：假定配置文件被简化并以dry方式启动consul template

```
more /etc/consul-template.d/kingshard.ctmpl
{{range service "dbdemo"}}
{{.Address}}:{{.Port}}{{end}}

consul-template -template="/etc/consul-template.d/kingshard.ctmpl:/etc/kingshard.d/demo.yaml" -dry
```

#### 第二步：制造SLAVE节点不健康

> 观察slave节点的mysql不健康状态通知机制
 
```
将某slave节点关闭，随即在屏幕可观察到会出现consul的warning信息
2016/11/28 00:44:47 [WARN] agent: Check 'service:dbdemo' is now warning

```

> 观察consul template -dry反应

```
[root@Dev_10_16_4_31 tmp]# consul-template -template="/etc/consul-template.d/kingshard.ctmpl:/etc/kingshard.d/demo.yaml" -dry
> /tmp/kingshard.conf

10.16.4.31:3306
10.16.4.33:3306
10.16.4.109:3306


> /tmp/kingshard.conf

10.16.4.31:3306
10.16.4.109:3306



> /tmp/kingshard.conf

10.16.4.31:3306
10.16.4.33:3306
10.16.4.109:3306
```

## 信息补充

**本次consul-template 启动，只是用命令行参数，而未设置配置文件，正式情况最好使用配置文件**
**本次consul-template使用了本地consul agent来与集群通信，该agent未注册任何服务，仅仅为了用于通信,如果是中间件集中部署，这方法倒也可行，若本地化部署mysql proxy到应用，agent就不便部署到应用服务器了，所以最好使用DNS轮询的方式访问CONSUL**



## CONSUL TEMPLATE模板文件编写参考


```
datacenters
{{datacenters}} 数据中心

file
{{file "/path/to/local/file"}} 读取本地文件的内容。如果不可读的话，会报错

key
{{key "service/redis/maxconns@east-aws"}} 读取consul的键的值。如果key不能转为字符串，则报错。

上面的命令读取的是east-aws这个数据中心的 service/redis/maxconns键的值

{{key "service/redis/maxconns"}} 如果省略数据中心，默认查本地的数据中心

key_or_default
{{key_or_default "service/redis/maxconns@east-aws" "5"}} 如果指定的key不存在，则使用默认值

ls
{{range ls "service/redis@east-aws"}}

{{.Key}} {{.Value}}{{end}}

查询指定前缀的顶层key和value（同上文，key value转换失败，会报错） 结果

minconns 2

maxconns 12

node
{{node "node1"}} 查询单节点

{{node}} 没有参数 返回当前的agent的node

{{node "node1" "@east-aws"}} 指定数据中心的节点

{{with node}}{{.Node.Node}} ({{.Node.Address}}){{range .Services}}

{{.Service}} {{.Port}} ({{.Tags | join ","}}){{end}}

{{end}}

指定的节点存在返回节点的相应信息，如果节点不存在，返回nil

nodes
{{nodes}} 所有的节点

{{nodes "@east-aws"}} 指定数据中心的所有节点

service
{{service "release.web@east-aws"}} 指定数据中心的web服务的健康情况

{{range service "web@datacenter"}}

server {{.Name}} {{.Address}}:{{.Port}}{{end}}

返回结果

server nyc_web_01 123.456.789.10:8080

server nyc_web_02 456.789.101.213:8080

默认情况下 ，只有健康的服务会被返回。

如果想返回全部的服务 可以用这个

{{service "web" "any"}}

下面是查询指定服务状态的服务

{{service "web" "passing, warning"}}

注意条件是或 而不是和。 返回passing或者waring状态的服务。 注意 ，不能和any一起使用。因为any是返回所有的，不用过滤。一起用的话会报错。

如果想自定义过滤，可以这么搞：

{{range service "web" "any"}}

{{if eq .Status "critical"}}

// Critical state!{{end}}

{{if eq .Status "passing"}}

// Ok{{end}}

维护模式

!/bin/sh
set -e

consul maint -enable -service web -reason "Consul Template updated"

service nginx reload

consul maint -disable -service web

执行时，设为维护模式，然后再恢复

如果你没有装consul agent可以用api

!/bin/sh
set -e

curl -X PUT "http://$CONSUL_HTTP_ADDR/v1/agent/service/maintenance/web?enable=true&reason=Consul+Template+Updated"

service nginx reload

curl -X PUT "http://$CONSUL_HTTP_ADDR/v1/agent/service/maintenance/web?enable=false"

services
{{services}} 全部服务

{{services "@east-aws"}}指定中西的服务

{{range services}}

{{.Name}}

{{range .Tags}}

{{.}}{{end}}

{{end}}

取出 所有服务的名称，tags

tree
{{range tree "service/redis@east-aws"}}
{{.Key}} {{.Value}}{{end}}

取出所有指定中心的key和value 。报错的话，看看key和value是否不符合规则。


```


