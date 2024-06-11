#!/bin/bash

echo "checking if release must be published to Nuget..."

if [[ $1 != "" ]]; then
	result = $(dotnet nuget push .\\Artifacts\\*.nupkg -s $1)
	echo result
fi