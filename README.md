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
- `recovery-key`为扇区恢复授权码，可以参照[recovery-key](/recovery-key)文件。
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

可以看到`CarFiles`在初始导出完成后是为空的，需要我们根据自己Car文件存放的位置进行填写。这一过程可以使用[find_car.sh](./scripts/find_car.sh)脚本来自动完成，执行完成后即可看到`CarFiles`中填写了对应的Car文件路径。注意恢复程序运行时读取的Car文件路径要与此时填写的文件路径一致，即所有用来恢复的机器Car文件挂载目录保持统一。

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

> [!IMPORTANT]
> 批量恢复脚本目前仅可直接用于CC及DC新扇区通过Car文件恢复，snap-up的扇区恢复可在此基础上进行修改

在面临大规模的数据丢失时，需要进行批量恢复，单个进程的运行就无法满足我们的需求。由于每次升级将恢复程序合并到lotus调度比较占用精力，我们提供shell脚本来满足这一需求。脚本完成功能如下：

- 单个Worker机器并发跑多个恢复进程。
- 多个Worker机器任务分配调度。
- 恢复完成后自动落盘。
- 多个存储目录均匀落盘。

脚本各个主要部分介绍如下：

- [manage.sh](/scripts/manage.sh)-管理机运行脚本，负责恢复任务的分配调度。
  运行在管理机上，具体配置及要求见[管理机配置](#51-管理机配置)。
- [allowcores.list](/scripts/allowcores.list)-运行恢复程序Worker机器可用CPU核心组资源表。
  该文件需要存放在管理机能够读取的位置，主要标识每个P1任务分配的核心组，用于自动给每个恢复进程分配CPU核心，文本格式需要按照给出的示例文件来完成，根据Worker机器上的CPU进行填写。以7542CPU为例，我们跑7个P1任务各自分配的核心为`0,16 1,17 2,18 3,19 4,20 5,21 6,22`，那么`allowcores.list`中的内容就应该填写为`IP 192.168.X.X Cores 0,16 1,17 2,18 3,19 4,20 5,21 6,22`（以上仅为示例，P1过程消耗的计算机资源是不变的，具体每台Worker机器分配多少并发任务可以直接跟封装时保持一致即可）。
- [worker.list](/scripts/worker.list)-可运行恢复程序的Worker机器列表。
  该文件中需要存放在管理机、Worker机都能够读写的位置（可以直接放在落盘的存储中），初始时为所有执行恢复程序的Worker机器列表，管理机(manage.sh)根据此列表中每行的机器列表自动给每个机器分配恢复任务，文本格式需要按照给出的示例文件来完成。
- [run_recovery.sh](/scripts/run_recovery.sh)]-完成Worker机器执行恢复程序及自动落盘功能。
  运行在Worker机器上，每台Worker机器上都需要存放一份该脚本，用于设置恢复时的环境变量及恢复完成后自动落盘。

`manage.sh`和`run_recovery.sh`详细的参数可参考脚本中的注释。

### 5.1 管理机配置

管理机负责恢复任务调度分配，即运行[manage.sh](/scripts/manage.sh)。管理机需要满足及填写的环境要求如下：

- 可免密登录到其他进行恢复任务的Worker机器。
- 可读取到`allowcores.list`并且可读写`worker.list`

### 5.2 流程示例

通过以上介绍，我们可以总结批量恢复的流程如下：

1. 机器环境准备。
   - 存储及恢复源统一路径挂载。
   - 管理机免密登录到所有Worker机器。
2. 原始数据准备。
   - [生成json文件](#1-扇区数据导出)。若使用Car文件恢复，通过脚本完成json文件中Car文件路径补充。
   - 根据Wroker机器情况，填写`allowcores.list`和`worker.list`。
   - 完成`manage.sh`和`run_recovery.sh`脚本中**参数的填写**。
3. 文件拷贝。
   - 拷贝`lotus-recovery`二进制到所有Worker机器`/usr/local/bin`目录下。
   - 拷贝`manage.sh`和`allowcores.list`到管理机。
   - 拷贝`run_recovery.sh`和处理好的json到Worker机器。
   - 拷贝`worker.list`到管理机和Worker机器均可读写的路径（可以考虑放在持久化存储中）。
4. 运行脚本。
   管理机运行`manage.sh`即可完成调度其他Worker机器，无需其他操作。
