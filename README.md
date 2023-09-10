# lotus扇区恢复工具

该工具用于Filecoin扇区恢复，当出现扇区错误、存储丢失等情况时可以用来批量重算恢复。

- [x] CC扇区恢复
- [x] DC新扇区恢复
- [x] snap-up扇区恢复
- [x] 批量恢复

> [!note]
> 工具可离线运行，无需链接lotus/lotus-miner，安全可靠

> [!IMPORTANT]
> 二进制与lotus调度并不兼容，若需批量进行恢复可以配合bash脚本完成基本调度功能

## 1. 扇区数据导出

使用命令`lotus-recovery sectors export --miner=f01000 --recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= 0-12`导出需要恢复的扇区数据。

- `f01000`替换为需要进行扇区恢复的节点号。
- `recovery-key`为扇区恢复授权码，可以参照 recovery-key 文件。
- `0-12`为需要进行恢复的扇区号。可以是具体的扇区编号，也可以是区间，例如`4 5 7-9 20`表示要导出`4、5、7、8、9、20`号共6个扇区。要导出一个节点全部的扇区，可以设置为0-最大的扇区编号。

命令执行成功后会在当前目录下面创建`sectors-t01000(Miner节点号).json`文件，如果其中有不存在的扇区，则会自动报出错误信息`precommit info does not exist`。

由于现在会自动本地导出`PieceInfo`信息，需要启动`lotus-miner`环境，同时需要具备miner元数据。

## 2. CC扇区恢复

以下命令使用扇区`6`为例

```bash
lotus-recovery sectors recover \
--recovery-metadata=/data/sectors-t01000.json \ 
--recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
--recovering-from=/data/from \
--recovering-to=/data/recover/recovering-to 
--is-deal=false --by-unsealed=false 6 
```

各个参数释义如下：

- `recovery-metadata`为`lotus-recovery sectors export`导出的json文件。
- `recovery-key`同上文。
- `recovering-from`是通过unsealed文件恢复需要引用的源文件，CC扇区无该文件可以填写任意路径。
- `recovering-to`为恢复完成以后的文件夹，恢复成功后，系统不会自动落盘，需要手工自行从此文件目录拷贝到相关文件到存储目录，若需要批量恢复自动落盘见[批量恢复](#5-批量恢复)。
- 最后一个参数是要恢复的扇区编号，多个时以空格分开，建议每次命令行只恢复一个扇区，可以启动多个恢复进程。

在机器上执行该命令后就将进入恢复工作，程序会陆续完成AP、P1和P2。恢复成功后在`recovering-to`目录下会有如下的文件：

```tree
    ├── cache
    │   └── s-t01000-6
    │       ├── p_aux
    │       ├── sc-06-data-tree-r-last-*.dat
    │       └── t_aux
    ├── sealed
    │   └── s-t01000-6
    ├── unsealed
    │   └── s-t01000-6
    ├── update
    └── update-cache
```

## 3. DC新封装扇区恢复

DC新封装扇区支持通过`unsealed`或者`Car`文件两种恢复模式。以下命令使用扇区`4`为例，分别对两种恢复模式进行演示。

### 3.1 使用unsealed文件恢复

```bash
lotus-recovery sectors recover \
--recovery-metadata=/data/recover/sectors-t01000.json \ 
--recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
--recovering-from=/data/from \
--recovering-to=/data/recover/recovering-to 
--is-deal=true --by-unsealed=true 4 
```

DC扇区为Deal，设置`--is-deal=true`，而`--by-unsealed`可以有两种方式，`--by-unsealed=true`表示通过unsealed文件进行恢复，`--by-unsealed=false`则采用Car文件进行恢复，unsealed恢复时程序默认从`recovering-from`路径读取的源文件，即将使用的unsealed文件存放到该目录下，其目录结构如下：

```tree
├── unsealed
│   ├── s-t01000-2
│   ├── s-t01000-3
│   ├── s-t01000-4
│   ├── s-t01000-5
│   ├── s-t01000-6
│   ├── s-t01000-7
│   ├── s-t01000-8
│   └── s-t01000-9
```

其余参数释义可参考[CC扇区恢复](#2-cc扇区恢复)。

在机器上执行该命令后就将进入恢复工作，程序会陆续完成AP、P1和P2，`recovering-to`路径为恢复完成后生成的最终文件存放路径。

### 3.2 使用Car文件恢复

#### 3.2.1 Car文件路径填写

打开[扇区数据导出](#1-扇区数据导出)的`sectors-t01000.json`文件，可以看到4号扇区对应的内容如下：

```json
{
 "SectorNumber": 4,
 "Ticket": "SCxkda/HnMyNZEy1MfSbkl+wrm5OVKD1d2dApCfxtz8=",
 ...
 "PieceInfo": [
  {
   "Size": 1024,
   "PieceCID": {
    "/": "baga6ea4seaqnyfhmjjqy5w2h3mgrsyuw625pi3ehgkm26nlrvcwzrf5utyetshy"
   }
  },
  {
   "Size": 1024,
   "PieceCID": {
    "/": "baga6ea4seaql2q5qkb43z5cc3kvvabmrp6b3c3a5l5hqik7q2lgdkp74j4yiepi"
   }
  }
 ],
 "SectorType": "Deal",
 "CarFiles": [
  "",
  ""
 ]
}
```

可以看到`CarFiles`在初始导出完成后是为空的，需要我们根据自己Car文件存放的位置进行填写。这一过程可以使用[find_car.sh](./scripts/find_car.sh)脚本来自动完成，执行完成后即可看到`CarFiles`中填写了对应的Car文件路径。

#### 3.2.2 恢复命令

```bash
lotus-recovery sectors recover \
--recovery-metadata=/data/recover/sectors-t01000.json \ 
--recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
--recovering-from=/data/from \
--recovering-to=/data/recover/recovering-to 
--is-deal=true --by-unsealed=false 4 
```

在机器上执行该命令后就将进入恢复工作，程序会陆续完成AP、P1和P2。`recovering-from`所填写的路径此时可以为任意路径，程序读取的是`sectors-t01000.json`中的Car文件路径。`recovering-to`为恢复完成后生成的最终文件存放路径。其余参数释义可参考[CC扇区恢复](#2-cc扇区恢复)。

## 4. snap-up扇区恢复

snap-up扇区恢复过程有点复杂，需要分成两个阶段：

- 恢复原来的CC扇区。工作AP、P1、P2完成恢复，这个过程和纯[CC扇区恢复](#2-cc扇区恢复)类似。
- 将恢复工作`ReplicaUpdate`。这个过程和纯Deal的恢复类似，可以通过unsealed文件和Car文件两种方式进行恢复。

### 4.1 恢复原来的CC扇区

以下命令使用扇区`2`为例:

```bash
lotus-recovery sectors recover \
--recovery-metadata=/data/recover/sectors-t01000.json \ 
--recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
--recovering-from=/data/lotus-test/miner \
--recovering-to=/data/recover/recovering-to 
--is-deal=false --by-unsealed=false 2 
```

具体操作及流程可以直接参考[CC扇区恢复](#2-cc扇区恢复)，第一阶段恢复成功后，在 `recovering-to`目录会有如下的文件：

```tree
    ├── cache
    │   └── s-t01000-2
    │       ├── p_aux
    │       ├── sc-02-data-tree-r-last-*.dat
    │       └── t_aux
    ├── sealed
    │   └── s-t01000-2
    ├── unsealed
    │   └── 【空】
    ├── update
    └── update-cache
```

### 4.2 使用unsealed文件恢复

```bash
lotus-recovery sectors recover \
--recovery-metadata=/data/recover/sectors-t01000.json \ 
--recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
--recovering-from=/data/from \
--recovering-to=/data/recover/recovering-to 
--is-deal=true --by-unsealed=true 2
```

命令执行完成后，程序从`recovering-from`路径读取恢复所需要的unsealed文件进行`ReplicaUpdate`过程。详细参数释义及流程可以直接参考[3.1 使用unsealed文件恢复](#31-使用unsealed文件恢复)

### 4.3 使用car文件恢复

- Car文件路径填写。参看[3.2.1 Car文件路径填写](#321-car文件路径填写)
- 执行恢复命令。
  
    ```bash
        lotus-recovery sectors recover \
        --recovery-metadata=/data/recover/sectors-t01000.json \ 
        --recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= \
        --recovering-from=/data/from \
        --recovering-to=/data/recover/recovering-to 
        --is-deal=true --by-unsealed=false 2
    ```

    命令执行完成后，程序从json文件`CarFiles`路径读取恢复所需要的Car文件进行`ReplicaUpdate`过程。详细参数释义及流程可以直接参考[3.2 使用Car文件恢复](#32-使用car文件恢复)

## 5. 批量恢复

TODO:功能已具备，文档待完成。
