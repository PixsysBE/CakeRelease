#!/bin/bash

while [ $# -gt 0 ]; do
  case "$1" in
    --token*|-t*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      NUGET_TOKEN="${1#*=}"
      ;;
    --sourcekey|-sk)
      if [[ "$1" != *=* ]]; then shift; fi
      NUGET_SOURCE_KEY="${1#*=}"
      ;;      
    --source|-s)
      if [[ "$1" != *=* ]]; then shift; fi
      NUGET_SOURCE="${1#*=}"
      ;;
    *)
      >&2 printf "Error: Invalid argument\n"
      exit 1
      ;;
  esac
  shift
done

echo "checking if release must be published to Nuget..."

if [[ $NUGET_TOKEN != "" ]] && [[ $NUGET_TOKEN != "notoken" ]]; then
	result=$(dotnet nuget push .\\Artifacts\\*.nupkg -k $NUGET_TOKEN -s https://api.nuget.org/v3/index.json)
	echo $result
fi


echo "checking if release must be published to custom Nuget source..."

if [[ $NUGET_SOURCE != "" ]]; then
  echo "Nuget Source:" $NUGET_SOURCE
  if [[ $NUGET_SOURCE_KEY != "" ]]; then
  echo "Nuget Source key:" $NUGET_SOURCE_KEY
	result=$(dotnet nuget push .\\Artifacts\\*.nupkg -k $NUGET_SOURCE_KEY -s $NUGET_SOURCE)
  else
  result=$(dotnet nuget push .\\Artifacts\\*.nupkg -s $NUGET_SOURCE)
  fi
	echo $result
fi

#read -r -p "Enter to quit" input