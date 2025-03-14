标定寄存器地址分配
==============================
| 寄存器地址   | 说明                |
| 300        | 标定位置索引          |
| 301        | 标定位置变量x(低16bit) |
| 302        | 标定位置变量x(高16bit) |
| 303        | 标定位置变量y(低16bit) |
| 304        | 标定位置变量y(高16bit) |
| 305        | 标定位置变量z(低16bit) |
| 306        | 标定位置变量z(高16bit) |
| 307        | 标定位置变量a(低16bit) |
| 308        | 标定位置变量a(高16bit) |
| 309        | 标定位置变量b(低16bit) |
| 310        | 标定位置变量b(高16bit) |
| 311        | 标定位置变量c(低16bit) |
| 312        | 标定位置变量c(高16bit) |

焊缝坐标寄存器地址分配
==============================
| 寄存器地址 | 说明                   |
| 350        | 写入位置变量x(低16bit) |
| 351        | 写入位置变量x(高16bit) |
| 352        | 写入位置变量y(低16bit) |
| 353        | 写入位置变量y(高16bit) |
| 354        | 写入位置变量z(低16bit) |
| 355        | 写入位置变量z(高16bit) |
| 356        | 写入位置变量a(低16bit) |
| 357        | 写入位置变量a(高16bit) |
| 358        | 写入位置变量b(低16bit) |
| 359        | 写入位置变量b(高16bit) |
| 360        | 写入位置变量c(低16bit) |
| 361        | 写入位置变量c(高16bit) |
|            |                     |
| 400        | 焊缝坐标是否有效       |
| 401        | 焊缝坐标变量x(低16bit) |
| 402        | 焊缝坐标变量x(高16bit) |
| 403        | 焊缝坐标变量y(低16bit) |
| 404        | 焊缝坐标变量y(高16bit) |
| 405        | 焊缝坐标变量z(低16bit) |
| 406        | 焊缝坐标变量z(高16bit) |
| 407        | 焊缝坐标变量a(低16bit) |
| 408        | 焊缝坐标变量a(高16bit) |
| 409        | 焊缝坐标变量b(低16bit) |
| 410        | 焊缝坐标变量b(高16bit) |
| 411        | 焊缝坐标变量c(低16bit) |
| 412        | 焊缝坐标变量c(高16bit) |

说明
==============================
* 坐标值倍率0.001
* 发给激光器x1000
* 解析激光器返回值x0.001

标定
==============================
> 那就参考别的5点标定步骤：
>> 1. 焊枪对准标记点
>> 2. 平移前进焊枪，激光线对准标记点
>> 3. 左平移焊枪，激光线对准标记点
>> 4. 右平移焊枪，激光线对准标记点
>> 5. 抬高焊枪，激光线对准标记点

1. 枪尖对准标记点
   SET 300~312 <1><当前机器人坐标>

2. 激光线对准标记点
   SET 300~312 <2><当前机器人坐标>

3. 激光线对准标记点
   SET 300~312 <3><当前机器人坐标>

4. 激光线对准标记点
   SET 300~312 <4><当前机器人坐标>

5. 激光线对准标记点
   SET 300~312 <5><当前机器人坐标>

实时获取焊缝坐标
==============================
1. 发送当前机器人坐标
   SET 350~361 <当前机器人坐标>

2. 读取焊缝坐标(机器人工具坐标系下的值)
   GET 400~412
   *400中存放的是处理状态 0表示焊缝坐标无效 255表示有效*
   *401~412中存放的是焊缝坐标*

3. 重复步骤 1. 2.
