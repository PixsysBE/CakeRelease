        // Exec plugin uses to call dotnet nuget push to push the packages from
        // the artifacts folder to NuGet
        [
            "@semantic-release/exec", {
                "publishCmd": "${process.env.PUBLISH_PACKAGE_TO_NUGET_SCRIPT} --token ${process.env.NUGET_TOKEN} --source ${process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE} --sourcekey ${process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE_KEY}"
            }
        ]