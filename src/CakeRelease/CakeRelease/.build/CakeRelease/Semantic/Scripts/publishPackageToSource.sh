#!/bin/bash

echo "checking if release must be published to custom Nuget source..."

if [[ $1 != "" ]]; then
	result = $(dotnet nuget push .\\Artifacts\\*.nupkg -s $1)
	echo result
fi