#!/bin/bash




static710up=$(docker ps -f "status=running" -f "name=static710" | grep -v CONTAINER)
if [ -n "$static710up" ]; then
    docker kill static710 && docker rm -v static710
fi

static810up=$(docker ps -f "status=running" -f "name=static810" | grep -v CONTAINER)
if [ -n "$static810up" ]; then
    docker kill static810 && docker rm -v static810
fi

static910up=$(docker ps -f "status=running" -f "name=static910" | grep -v CONTAINER)
if [ -n "$static910up" ]; then
    docker kill static910 && docker rm -v static910
fi

itstatic810up=$(docker ps -f "status=running" -f "name=itslave710" | grep -v CONTAINER)
if [ -n "$itstatic810up" ]; then
    docker kill itslave710 && docker rm -v itslave710
fi

itslave810up=$(docker ps -f "status=running" -f "name=itslave810" | grep -v CONTAINER)
if [ -n "$itslave810up" ]; then
    docker kill itslave810 && docker rm -v itslave810
fi

itslave910up=$(docker ps -f "status=running" -f "name=itslave910" | grep -v CONTAINER)
if [ -n "$itslave910up" ]; then
    docker kill itslave910 && docker rm -v itslave910
fi

matrixup=$(docker ps -f "status=running" -f "name=matrix" | grep -v CONTAINER)
if [ -n "$matrixup" ]; then
    docker kill matrix && docker rm -v matrix
fi
