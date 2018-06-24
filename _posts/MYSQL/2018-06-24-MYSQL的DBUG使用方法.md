---
published: true
author: David Wan
layout: post
title: MYSQL使用DBUG包TRACE源码方法
category: MYSQL
summary: MYSQL代码量比较大，掌握相应的DEBUG能力，对学习源码和故障排查都有价值。本文以问答的方式，介绍MYSQL的TRACE工具，DBUG包的基本使用方法。
tags:
  - MYSQL

---



MYSQL代码量比较大，掌握相应的DEBUG能力，对学习源码和故障排查都有价值。本文以问答的方式，介绍MYSQL的TRACE工具，DBUG包的基本使用方法。

***

## 问题一：MYSQL的TRACE使用什么包实现？它的功能是什么？

MYSQL使用DBUG包TRACE服务器端和客户端的代码，在源码中已写入TRACE位置，可通过编译使用.
DBUG包允许你得到程序运行的trace文件，也可以通过加入DBUG代码，增加自己要跟踪的内容.
> [MYSQL官方DBUG包介绍链接地址](https://dev.mysql.com/doc/refman/5.7/en/dbug-package.html)



## 问题二：如何启用DBUG？

#### 首先：源代码安装过程中，CMAKE编译时需要加上'-DWITH_DEBUG=1'



```
cmake \
-DBUILD_CONFIG=mysql_release \
-DWITH_EMBEDDED_SERVER=OFF \
-DCMAKE_INSTALL_PREFIX=/usr/local/mysql_debug \
...
-DWITH_DEBUG=1

```

#### 其次：在配置文件中加入debug选项

| 配置文件加入内容 | 效果 | 意义 |
| --- |--- |--- |
| debug	| 使用默认值'd:t:i:o,/tmp/mysqld.trace'| 输出所有debug macros，<br>跟踪函数调用和退出，<br>增加PID到文件<br>以及输出到/tmp/mysqld.trace|
| debug="debug_options" | 指定debug值 | 按照debug_options参数来执行 |


#### 或者：在线修改debug参数

```
mysql> SET GLOBAL debug = 'debug_options';
mysql> SET SESSION debug = 'debug_options';
```
>debug的量可能大，为了减少不必要的日志，可以在线打开或者关闭，或者通过参数减少日志内容

## 问题三：DBUG选项该如何设置呢?

> 以```debug='d,error,warning:F:i:L:n:N:o,/tmp/mysqld.trace:t'```为例，其中d,error,F分别代表了什么？

#### 基本格式说明

DBUG参数首先以':'作为分割,其中field_n代表了某类选项，也就是某类flag

 ```
 field_1:field_2:...:field_N
 ```

而field_n其再由','作为分割，指定该flag的参数

```
[+|-]flag[,modifier,modifier,...,modifier]
```

> '[+|-]'指定代表在现有基础上调整<br>
> '[+|-]'未指定代表随后list为明确指定



#### 相关flag及modifier列表


| Flag | Dscription | 
| ---	| --- |
|	d	|		Enable output from DBUG_XXX macros for the current state. May be followed by a list of keywords, which enables output only for the DBUG macros with that keyword. An empty list of keywords enables output for all macros.In MySQL, common debug macro keywords to enable are enter, exit, error, warning, info, and loop.|
|	D	|		Delay after each debugger output line. The argument is the delay, in tenths of seconds, subject to machine capabilities. For example, D,20 specifies a delay of two seconds.|
|	f	|		Limit debugging, tracing, and profiling to the list of named functions. An empty list enables all functions. The appropriate d or t flags must still be given; this flag only limits their actions if they are enabled.|
|	F	|		Identify the source file name for each line of debug or trace output.|
|	i	|		Identify the process with the PID or thread ID for each line of debug or trace output.|
|	L	|		Identify the source file line number for each line of debug or trace output.|
|	n	|		Print the current function nesting depth for each line of debug or trace output.|
|	N	|		Number each line of debug output.|
|	o	|		Redirect the debugger output stream to the specified file. The default output is stderr.|
|	O	|		Like o, but the file is really flushed between each write. When needed, the file is closed and reopened between each write.|
|	p	|		Limit debugger actions to specified processes. A process must be identified with the DBUG_PROCESS macro and match one in the list for debugger actions to occur.|
|	P	|		Print the current process name for each line of debug or trace output.|
|	r	|		When pushing a new state, do not inherit the previous state's function nesting level. Useful when the output is to start at the left margin.|
|	S	|		Do function _sanity(_file_,_line_) at each debugged function until _sanity() returns something that differs from 0.|
|	t	|		Enable function call/exit trace lines. May be followed by a list (containing only one modifier) giving a numeric maximum trace level, beyond which no output occurs for either debugging or tracing macros. The default is a compile time option.|

#### 例子的解释

| debug选项指定值 | 意义 |
| --- | --- |
|```debug='d,error,warning:F:i:L:n:N:o,/tmp/mysqld.trace:t'``` | flag'd',error,warning生效<br>flag'F',打印源文件名称<br>flag'L',打印源代码所在行号<br>flag'o',输出文件位置,...|


## 问题四：该如何查看trace日志

#### 观察源码的DBUG代码

以复制函数```process_io_rotate```为例

```

static int process_io_rotate(Master_info *mi, Rotate_log_event *rev)
{
  DBUG_ENTER("process_io_rotate");
  safe_mutex_assert_owner(&mi->data_lock);

  if (unlikely(!rev->is_valid()))
    DBUG_RETURN(1);

  /* Safe copy as 'rev' has been "sanitized" in Rotate_log_event's ctor */
  memcpy(mi->master_log_name, rev->new_log_ident, rev->ident_len+1);
  mi->master_log_pos= rev->pos;
  DBUG_PRINT("info", ("master_log_pos: '%s' %lu",
                      mi->master_log_name, (ulong) mi->master_log_pos));
#ifndef DBUG_OFF
  /*
    If we do not do this, we will be getting the first
    rotate event forever, so we need to not disconnect after one.
  */
  if (disconnect_slave_event_count)
    mi->events_till_disconnect++;
#endif

  /*
    If description_event_for_queue is format <4, there is conversion in the
    relay log to the slave's format (4). And Rotate can mean upgrade or
    nothing. If upgrade, it's to 5.0 or newer, so we will get a Format_desc, so
    no need to reset description_event_for_queue now. And if it's nothing (same
    master version as before), no need (still using the slave's format).
  */
  if (mi->rli.relay_log.description_event_for_queue->binlog_version >= 4)
  {
    delete mi->rli.relay_log.description_event_for_queue;
    /* start from format 3 (MySQL 4.0) again */
    mi->rli.relay_log.description_event_for_queue= new
      Format_description_log_event(3);
  }
  /*
    Rotate the relay log makes binlog format detection easier (at next slave
    start or mysqlbinlog)
  */
  DBUG_RETURN(rotate_relay_log(mi) /* will take the right mutexes */);
}

```


| DEBUG代码 | 含义 |
| --- | --- | 
| DBUG_ENTER	| 表示进入某个函数	|
| DBUG_RETURN |	在return的基础上，表示退出某个函数|
| DBUG_PRINT	|	和printf差不多，打印调试信息|


#### 查看对应的TRACE内容

>```debug="d:F:i:L:n:N:o,/tmp/mysqld.trace:t"```为例
>若指定位置没有mysqld.trace文件，请查看mysql的error文件



```
T@5    :  1064:       slave.cc:  3678:    3: | | >process_io_rotate
T@5    :  1065:       slave.cc:  3688:    3: | | | info: master_log_pos: 'binlog.000090' 350962597
T@5    :  1066:    my_malloc.c:   132:    4: | | | >my_free
T@5    :  1067:    my_malloc.c:   133:    4: | | | | my: ptr: 0x7f2820010a70
T@5    :  1068:    my_malloc.c:   135:    4: | | | <my_free 135
T@5    :  1069:    my_malloc.c:   132:    4: | | | >my_free
T@5    :  1070:    my_malloc.c:   133:    4: | | | | my: ptr: 0x7f28200109c0
T@5    :  1071:    my_malloc.c:   135:    4: | | | <my_free 135
T@5    :  1072:    my_malloc.c:    31:    4: | | | >my_malloc
T@5    :  1073:    my_malloc.c:    32:    4: | | | | my: size: 160  my_flags: 24
T@5    :  1074:    my_malloc.c:    65:    4: | | | | exit: ptr: 0x7f28200109c0
T@5    :  1075:    my_malloc.c:    66:    4: | | | <my_malloc 66
T@5    :  1076:    my_malloc.c:    31:    4: | | | >my_malloc
T@5    :  1077:    my_malloc.c:    32:    4: | | | | my: size: 14  my_flags: 0
T@5    :  1078:    my_malloc.c:    65:    4: | | | | exit: ptr: 0x7f2820010ac0
T@5    :  1079:    my_malloc.c:    66:    4: | | | <my_malloc 66
T@5    :  1080:       slave.cc:  4365:    3: | | | info: Format_description_log_event::server_version_split: '4.0' 4 0 0
T@5    :  1081:       slave.cc:  3716:    3: | | <process_io_rotate 3716
```

#### 对应关系

| DBUG代码/对应TRACE内容(上下行) |
| ---  |
|	```DBUG_ENTER("process_io_rotate")```|
|```T@5    :  1064:       slave.cc:  3678:    3: | | >process_io_rotate```|
|	```DBUG_PRINT("info", ("master_log_pos: '%s' %lu",mi->master_log_name,(ulong) mi->master_log_pos));```|
|	```T@5    :  1065:       slave.cc:  3688:    3: | | | info: master_log_pos: 'binlog.000090' 350962597```|
|	```DBUG_RETURN(rotate_relay_log(mi) /* will take the right mutexes */);```|
|```T@5    :  1081:       slave.cc:  3716:    3: | | <process_io_rotate 3716```|

