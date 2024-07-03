﻿
module.exports = {
    "plugins": [
        "@semantic-release/commit-analyzer",
        "@semantic-release/release-notes-generator",
        // Set of semantic-release plugins for creating or updating a changelog file.
        [
            "@semantic-release/changelog",
            {
                "changelogFile": "docs/CHANGELOG.md"
            }
        ],
        //"@semantic-release/npm",

        // Git plugin is need so the changelog file will be committed to the Git repository and available on subsequent builds in order to be updated.
        [
            "@semantic-release/git",
            {
              "assets": ["docs/CHANGELOG.md"]
            }
        ],
        
                // Exec plugin uses to call dotnet nuget push to push the packages from
        // the artifacts folder to NuGet
        [
            "@semantic-release/exec", {
                //"verifyConditionsCmd": "./verify.sh",
                //"publishCmd": "Scripts/publishReleaseToGitHub.sh" //"dotnet nuget push .\\Artifacts\\*.nupkg -s ${process.env.NUGETSOURCE}"
                "publishCmd": "dotnet nuget push .\\Artifacts\\*.nupkg -s ${process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE}; dotnet nuget push .\\Artifacts\\*.nupkg -k ${process.env.NUGET_TOKEN} -s https://api.nuget.org/v3/index.json;"
            }
        ]
    ],
    "branches": ["master", "next", { name: 'beta', prerelease: true }, { name: 'alpha', prerelease: true }]
};
