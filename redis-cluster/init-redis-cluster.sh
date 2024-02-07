#!/bin/bash
# Redis 클러스터 생성을 위한 스크립트

# 클러스터 생성을 시도하기 전에 Redis가 준비될 때까지 기다립니다.
sleep 10

# 클러스터 생성
echo "Creating Redis Cluster..."
redis-cli --cluster create redis_master1:6300 redis_master2:6301 redis_master3:6302 redis_replica1:6400 redis_replica2:6401 redis_replica3:6402 --cluster-yes --cluster-replicas 1

tail -f /dev/null