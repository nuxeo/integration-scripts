#!/bin/bash




# priv slave for QA
for i in 1 2; do
    slaveup=$(docker ps -f "status=running" -f "name=privovh02-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill privovh02-$i && docker rm -v privovh02-$i
    fi
done

# priv slave for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=priv2-02-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill priv2-02-$i && docker rm -v priv2-02-$i
    fi
done

# static priv slave 7.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-710-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill slavepriv2-710-$i && docker rm -v slavepriv2-710-$i
    fi
done

# static priv slave 8.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-810-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill slavepriv2-810-$i && docker rm -v slavepriv2-810-$i
    fi
done

# static priv slave 9.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-910-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill slavepriv2-910-$i && docker rm -v slavepriv2-910-$i
    fi
done
