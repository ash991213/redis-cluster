## 정리중

- Docker-compose로 Local에서 테스트할 경우 network host로 작성
- Docker-compose Redis Cluster 환경 구축 후 데이터 쓰기/읽기 테스트

- RDB: RDB 지속성은 지정된 간격으로 데이터 세트의 특정 시점 스냅샷을 수행합니다.
- AOF (Append Only File): AOF 지속성은 서버에서 수신한 모든 쓰기 작업을 기록합니다. 그런 다음 서버 시작 시 이러한 작업을 다시 재생하여 원래 데이터세트를 재구성할 수 있습니다. 명령은 Redis 프로토콜 자체와 동일한 형식을 사용하여 기록됩니다.
- nodes.info 클러스터의 노드 정보와 상태를 저장합니다.

## Redis Cluster 설치 및 테스트 가이드 / localhost

1. redis.conf 파일 생성 ( 아래와 같은 방식으로 port만 다르게 하여 생성 )

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
   ```

2. redis-server 실행 (여기까지는 일반적인 redis-server)

   ```bash
   $ redis-server redis_master_6300.conf
   $ redis-server redis_master_6301.conf
   $ redis-server redis_master_6302.conf
   $ redis-server redis_replica_6400.conf
   $ redis-server redis_replica_6401.conf
   $ redis-server redis_replica_6402.conf
   ```

3. redis-cluster 생성

   ```bash
   $ redis-cli --cluster create 127.0.0.1:6300 127.0.0.1:6301 127.0.0.1:6302 127.0.0.1:6400 127.0.0.1:6401 127.0.0.1:6402 --cluster-replicas 1
   ```

4. 새로운 master node 추가

   ```bash
   ## 새로운 master node 실행
   $ redis-server redis_master_6303.conf

   $ redis-cli --cluster add-node <new master ip:port> <master ip:port>
   $ redis-cli --cluster add-node localhost:6303 localhost:6300
   ```

5. 새로운 slave node 추가

   ```bash
   ## 새로운 slave node 실행
   $ redis-server redis_replica_6403.conf

   $ redis-cli --cluster add-node <replica ip:port> <master ip:port> --cluster-slave
   $ redis-cli --cluster add-node localhost:6403 localhost:6303 --cluster-slave
   ```

6. redis-cluster 접속

   ```bash
   $ redis-cli -h localhost -p 6300 -c
   ```

7. node 정보 확인

   ```bash
   $ cluster nodes
   ```

8. 신규 node가 추가 되었지만 적용이 안 된 상태이니 전체 서버로 resharding 작업 수행

   ```bash
   $ redis-cli --cluster reshard localhost:6300

   # master node로 이동 시킬 슬롯 수 설정
   $ How many slots do you want to move (from 1 to 16384)? 100

   # 슬롯을 받을 node id
   $ What is the receiving node ID ? <신규 master node id>

   # 슬롯을 빼올 node id
   $ Source node #1: <기존 master node 중 슬롯을 빼올 node id>
   $ Source node #2: done

   # resharding 진행 시킬지 여부
   $ Do you want to proceed with the proposed reshard plan (yes/no)? yes

   # 슬롯 수 재분배
   $ redis-cli --cluster rebalance localhost:6300
   ```

9. redis-cluster 접속

   ```bash
   $ redis-cli -h localhost -p 6300 -c
   ```

10. node 정보 확인

    ```bash
    $ cluster nodes
    ```

---

## 클러스터 테스트

1. shutdown 명령어를 통해 master node를 다운시키고서의 동작 확인 ( 고가용성 테스트 )

   ```bash
   $ shutdown
   ```

---

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
