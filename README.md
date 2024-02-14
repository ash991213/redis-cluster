# Redis Cluster 구축 및 테스트 가이드

## 개요

Redis Cluster는 데이터를 자동으로 여러 노드에 분할하고, 높은 가용성을 제공하는 Redis의 고급 설정입니다.
이 가이드에서는 로컬 환경에서 Redis Cluster를 구축하고 기본적인 테스트를 수행하는 방법을 설명합니다.

## Redis 지속성 옵션

- RDB (Redis Database) : 지정된 간격으로 데이터 세트의 스냅샷을 생성하여 지속성을 제공합니다.

> 기본적으로 Redis는 하나 이상의 키가 변경된 경우 900초(15분)마다, 1000개 이상의 키가 변경된 경우 300초(5분)마다 스냅샷을 저장합니다. 이는 Redis의 성능에 큰 영향을 미치지는 않지만, 마지막 스냅샷 저장 후 발생한 데이터 변경 사항이 지속되지 않기 때문에 두 저장 작업 사이에 오류가 발생하면 일부 데이터가 손실될 수 있습니다.
이 위험을 완화하기 위해 디스크 I/O가 증가하고 잠재적으로 Redis 성능이 느려지는 대가로 더 자주 저장하도록 구성할 수 있습니다.

- AOF (Append Only File): 서버가 수신한 모든 쓰기 작업을 로그에 기록합니다. 서버 재시작 시 로그를 재생하여 데이터 세트를 복구합니다.

> 쓰기 속도가 높은 경우 AOF 파일의 용량이 커질 수 있고 지속적인 디스크 I/O가 Redis 성능에 영향을 미칠 수 있습니다.

## Redis Cluster 설치

1. redis.conf 파일 생성

각 Redis 노드에 대한 별도의 설정 파일을 생성합니다.

```bash
# 포트 설정
port 6300
# 클러스터 모드 허용 설정
cluster-enabled yes
# 클러스터 노드의 메타데이터를 저장하는데 사용되는 파일의 경로
cluster-config-file nodes.conf
# 클러스터 노드 타임아웃 시간 설정
cluster-node-timeout 5000
# 클러스터의 모든 슬롯이 커버되지 않은 경우 클라이언트 요청 거부 설정
cluster-require-full-coverage yes
# Master에서 Slave로 마이그레이션을 시작하기 전에 필요한 최소 Slave의 수 설정
cluster-migration-barrier 1
# Slave가 데이터 손실 없이 마스터 역할을 수행할 수 있는지 결정하는 데 사용되는 시간 계수 설정 (cluster-node-timeout과 곱하여 노드의 유효성을 평가하는 데 사용)
cluster-replica-validity-factor 10
# 데이터파일을 저장할 디렉토리 설정
dir ./
# Redis의 모든 쓰기 연산을 AOF 파일에 기록 설정 (Redis 서버가 다운되어 재시작할 때 이 파일을 사용하여 데이터를 복원하는 데 사용)
appendonly yes
# Redis 서버 백그라운드 실행 설정
daemonize no
# 최대 메모리 설정
maxmemory 10mb
# 메모리가 가득 찼을 경우 가장 최근에 사용된 키들을 남기고 나머지를 삭제
maxmemory-policy allkeys-lru
```

2. redis-server 실행

각 디렉토리(master1~3, replica1~3)에서 Redis 인스턴스를 실행합니다.

```bash
$ redis-server redis_master_6300.conf
$ redis-server redis_master_6301.conf
$ redis-server redis_master_6302.conf
$ redis-server redis_replica_6400.conf
$ redis-server redis_replica_6401.conf
$ redis-server redis_replica_6402.conf
```

3. redis-cluster 생성

Redis 클러스터를 생성합니다.

```bash
$ redis-cli --cluster create 127.0.0.1:6300 127.0.0.1:6301 127.0.0.1:6302 127.0.0.1:6400 127.0.0.1:6401 127.0.0.1:6402 --cluster-replicas 1
```

```bash
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 127.0.0.1:6401 to 127.0.0.1:6300
Adding replica 127.0.0.1:6402 to 127.0.0.1:6301
Adding replica 127.0.0.1:6400 to 127.0.0.1:6302
>>> Trying to optimize slaves allocation for anti-affinity
[WARNING] Some slaves are in the same host as their master
M: b81fb6f862f26401c816e0e87a20e819070fb9c5 127.0.0.1:6300
   slots:[0-5460] (5461 slots) master
M: 53964578d91e2588813e14757b3f1d197c93d02d 127.0.0.1:6301
   slots:[5461-10922] (5462 slots) master
M: 8af45736e297071a0f869a52c5872ba8873dcaa8 127.0.0.1:6302
   slots:[10923-16383] (5461 slots) master
S: 8f5d8281562af6fdf9599b5963c6761f00a41f94 127.0.0.1:6400
   replicates b81fb6f862f26401c816e0e87a20e819070fb9c5
S: 3d2ea0fa5e14c6280ca525765b0a44628d0baf35 127.0.0.1:6401
   replicates 53964578d91e2588813e14757b3f1d197c93d02d
S: 677a16183eded9919fd62e694d8ad732028fd5dd 127.0.0.1:6402
   replicates 8af45736e297071a0f869a52c5872ba8873dcaa8
Can I set the above configuration? (type 'yes' to accept): yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
.
>>> Performing Cluster Check (using node 127.0.0.1:6300)
M: b81fb6f862f26401c816e0e87a20e819070fb9c5 127.0.0.1:6300
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: 3d2ea0fa5e14c6280ca525765b0a44628d0baf35 127.0.0.1:6401
   slots: (0 slots) slave
   replicates 53964578d91e2588813e14757b3f1d197c93d02d
M: 53964578d91e2588813e14757b3f1d197c93d02d 127.0.0.1:6301
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
M: 8af45736e297071a0f869a52c5872ba8873dcaa8 127.0.0.1:6302
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: 677a16183eded9919fd62e694d8ad732028fd5dd 127.0.0.1:6402
   slots: (0 slots) slave
   replicates 8af45736e297071a0f869a52c5872ba8873dcaa8
S: 8f5d8281562af6fdf9599b5963c6761f00a41f94 127.0.0.1:6400
   slots: (0 slots) slave
   replicates b81fb6f862f26401c816e0e87a20e819070fb9c5
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

4. 새로운 마스터 노드 추가

```bash
# 새로운 마스터 노드 실행
$ redis-server redis_master_6303.conf

# 새로운 마스터 노드를 클러스터에 추가
# redis-cli --cluster add-node <new master ip:port> <master ip:port>
$ redis-cli --cluster add-node localhost:6303 localhost:6300
```

5. 새로운 복제 노드 추가

```bash
# 새로운 복제 노드 실행
$ redis-server redis_replica_6403.conf

# 새로운 복제 노드를 클러스터에 추가
# redis-cli --cluster add-node <replica ip:port> <master ip:port> --cluster-slave
$ redis-cli --cluster add-node localhost:6403 localhost:6303 --cluster-slave
```

6. 노드 정보 확인

```bash
$ redis-cli -h localhost -p 6300 -c cluster nodes
```

```bash
9de7abce4c6acc399f9fb420f04f9ce7614e835b ::1:6303@16303 master - 0 1707873180576 0 connected
3d2ea0fa5e14c6280ca525765b0a44628d0baf35 127.0.0.1:6401@16401 slave 53964578d91e2588813e14757b3f1d197c93d02d 0 1707873180000 2 connected
53964578d91e2588813e14757b3f1d197c93d02d 127.0.0.1:6301@16301 master - 0 1707873180000 2 connected 5461-10922
8af45736e297071a0f869a52c5872ba8873dcaa8 127.0.0.1:6302@16302 master - 0 1707873180576 3 connected 10923-16383
677a16183eded9919fd62e694d8ad732028fd5dd 127.0.0.1:6402@16402 slave 8af45736e297071a0f869a52c5872ba8873dcaa8 0 1707873180879 3 connected
b81fb6f862f26401c816e0e87a20e819070fb9c5 ::1:6300@16300 myself,master - 0 1707873179000 1 connected 0-5460
f7184adf5fc1a1e8bb15ed8945a740e9b8658ac5 ::1:6403@16403 slave 9de7abce4c6acc399f9fb420f04f9ce7614e835b 0 1707873180000 0 connected
8f5d8281562af6fdf9599b5963c6761f00a41f94 127.0.0.1:6400@16400 slave b81fb6f862f26401c816e0e87a20e819070fb9c5 0 1707873180576 1 connected
```

7. 신규 노드가 추가 되었지만 적용이 안 된 상태이니 전체 서버로 resharding 작업 수행

```bash
$ redis-cli --cluster reshard localhost:6300

# 마스터 노드로 이동 시킬 슬롯 수 설정
$ How many slots do you want to move (from 1 to 16384)? 100

# 슬롯을 받을 노드 id
$ What is the receiving node ID ? <신규 마스터 노드 id>

# 슬롯을 빼올 node id
$ Source node #1: <기존 마스터 노드 중 슬롯을 빼올 노드 id>
$ Source node #2: done

# resharding 진행 시킬지 여부
$ Do you want to proceed with the proposed reshard plan (yes/no)? yes

# 슬롯 수 재분배
$ redis-cli --cluster rebalance localhost:6300
```

8. 노드 정보 확인

```bash
$ redis-cli -h localhost -p 6300 -c cluster nodes
```

```bash
9de7abce4c6acc399f9fb420f04f9ce7614e835b ::1:6303@16303 master - 0 1707873303574 7 connected 0-1364 5461-6826 10923-12287
3d2ea0fa5e14c6280ca525765b0a44628d0baf35 127.0.0.1:6401@16401 slave 53964578d91e2588813e14757b3f1d197c93d02d 0 1707873304000 2 connected
53964578d91e2588813e14757b3f1d197c93d02d 127.0.0.1:6301@16301 master - 0 1707873303000 2 connected 6827-10922
8af45736e297071a0f869a52c5872ba8873dcaa8 127.0.0.1:6302@16302 master - 0 1707873303574 3 connected 12288-16383
677a16183eded9919fd62e694d8ad732028fd5dd 127.0.0.1:6402@16402 slave 8af45736e297071a0f869a52c5872ba8873dcaa8 0 1707873304579 3 connected
b81fb6f862f26401c816e0e87a20e819070fb9c5 ::1:6300@16300 myself,master - 0 1707873302000 1 connected 1365-5460
f7184adf5fc1a1e8bb15ed8945a740e9b8658ac5 ::1:6403@16403 slave 9de7abce4c6acc399f9fb420f04f9ce7614e835b 0 1707873303574 7 connected
8f5d8281562af6fdf9599b5963c6761f00a41f94 127.0.0.1:6400@16400 slave b81fb6f862f26401c816e0e87a20e819070fb9c5 0 1707873304000 1 connected
```

## 데이터 삽입/조회

1. 노드 접속

```bash
$ redis-cli -h localhost -p 6300 -c
```

2. 데이터 삽입/조회 테스트

```bash
localhost:6300> set hello world
-> Redirected to slot [866] located at ::1:6303
OK

127.0.0.1:6303> get hello
"world"
```

3. 만료 시간을 설정하여 키가 자동으로 지워지도록 데이터 삽입

```bash
localhost:6300> setex mykey 10 hello
-> Redirected to slot [14687] located at 127.0.0.1:6302
OK

127.0.0.1:6302> get mykey
"hello"

# After 10 seconds
127.0.0.1:6302> get mykey
(nil)
```

4. 해시태그를 사용한 데이터 삽입/조회 테스트

```bash
localhost:6300> set user:{asher}:session "abcde"
-> Redirected to slot [13028] located at 127.0.0.1:6302
OK

127.0.0.1:6302> get user:{asher}:session
"abcde"

127.0.0.1:6300> set user:{asher}:last_access "2024-01-01"
-> Redirected to slot [13028] located at 127.0.0.1:6302
OK

127.0.0.1:6302> get user:{asher}:last_access
"2024-01-01"
```

## 성능 테스트

```bash
$ redis-benchmark -h localhost -p 6300 -t set,get -c 100 -n 1000 --cluster
```

## 클러스터 장애 복구 시뮬레이션

1. shutdown 명령어를 통해 마스터 노드를 종료하고 동작 확인

마스터 노드가 종료될 시 복제 노드에서 연결을 시도하다 cluster-node-timeout 시간동안 마스터 노드에 연결이 안될 경우 새로운 마스터 노드가 된다

```
$ redis-cli -h localhost -p 6300 -c shutdown
```

```
* MASTER <-> REPLICA sync started
# Error condition on socket for SYNC: Connection refused
* Connecting to MASTER 127.0.0.1:6300
* MASTER <-> REPLICA sync started
# Error condition on socket for SYNC: Connection refused
* Marking node b81fb6f862f26401c816e0e87a20e819070fb9c5 as failing (quorum reached).
# Cluster state changed: fail
* Connecting to MASTER 127.0.0.1:6300
* MASTER <-> REPLICA sync started
# Start of election delayed for 993 milliseconds (rank #0, offset 209684).
# Error condition on socket for SYNC: Connection refused
* Connecting to MASTER 127.0.0.1:6300
* MASTER <-> REPLICA sync started
# Starting a failover election for epoch 8.
# Error condition on socket for SYNC: Connection refused
# Failover election won: I'm the new master.
```

2. 노드 정보 확인

```bash
$ redis-cli -h localhost -p 6301 -c cluster nodes
```

```bash
8af45736e297071a0f869a52c5872ba8873dcaa8 127.0.0.1:6302@16302 master - 0 1707885222539 3 connected 12288-16383
9de7abce4c6acc399f9fb420f04f9ce7614e835b 127.0.0.1:6303@16303 master - 0 1707885222034 7 connected 0-1364 5461-6826 10923-12287
f7184adf5fc1a1e8bb15ed8945a740e9b8658ac5 ::1:6403@16403 slave 9de7abce4c6acc399f9fb420f04f9ce7614e835b 0 1707885223042 7 connected
53964578d91e2588813e14757b3f1d197c93d02d 127.0.0.1:6301@16301 myself,master - 0 1707885221000 2 connected 6827-10922
677a16183eded9919fd62e694d8ad732028fd5dd 127.0.0.1:6402@16402 slave 8af45736e297071a0f869a52c5872ba8873dcaa8 0 1707885223042 3 connected
3d2ea0fa5e14c6280ca525765b0a44628d0baf35 127.0.0.1:6401@16401 slave 53964578d91e2588813e14757b3f1d197c93d02d 0 1707885223000 2 connected
b81fb6f862f26401c816e0e87a20e819070fb9c5 127.0.0.1:6300@16300 master,fail - 1707885195040 1707885192527 1 disconnected
8f5d8281562af6fdf9599b5963c6761f00a41f94 127.0.0.1:6400@16400 master - 0 1707885224048 8 connected 1365-5460
```

## 에러

Failed to configure LOCALE for invalid locale name.

Redis가 인식할 수 없는 로케일을 사용하려고 할 때 발생합니다

```bash
LANG="en_KR.UTF-8"
LC_COLLATE="C"
LC_CTYPE="C"
LC_MESSAGES="C"
LC_MONETARY="C"
LC_NUMERIC="C"
LC_TIME="C"
LC_ALL=
```

```bash
$ export LC_ALL=en_US.UTF-8
$ export LANG=en_US.UTF-8
```

```bash
LANG="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_CTYPE="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
```
