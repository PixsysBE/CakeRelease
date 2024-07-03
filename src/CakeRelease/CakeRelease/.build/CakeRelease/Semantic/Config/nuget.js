        // Exec plugin uses to call dotnet nuget push to push the packages from
        // the artifacts folder to NuGet
        [
            "@semantic-release/exec", {
                //"verifyConditionsCmd": "./verify.sh",
                //"publishCmd": "Scripts/publishReleaseToGitHub.sh" //"dotnet nuget push .\\Artifacts\\*.nupkg -s ${process.env.NUGETSOURCE}"
                "publishCmd": "{%NUGETPUBLISHCMD%}"
            }
        ]