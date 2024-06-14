# Cake Release

**Cake Release** is a combination of [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7.4) scripts, [Cake Build](https://cakebuild.net/) script and [Semantic Release](https://github.com/semantic-release), automating build and deployment workflows of your .NET project.

It is based on [Michael Wolfenden](https://medium.com/@michael.wolfenden/)'s article "[Simplified versioning and publishing for .NET libraries](https://medium.com/@michael.wolfenden/simplified-versioning-and-publishing-for-net-libraries-a28e5e740fa6)".

## Tools Definitions

[Powershell](https://learn.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7.4)

**PowerShell** is a cross-platform task automation solution made up of a command-line shell, a scripting language, and a configuration management framework. PowerShell runs on Windows, Linux, and macOS

[Cake Build](https://cakebuild.net/)

Cake (C# Make) is a free and open source cross-platform build automation system with a C# DSL for tasks such as compiling code, copying files and folders, running unit tests, compressing files and building NuGet packages.

[Semantic Release](https://github.com/semantic-release)

**semantic-release** automates the whole package release workflow including: determining the next version number, generating the release notes, and publishing the package.

This removes the immediate connection between human emotions and version numbers, strictly following the [Semantic Versioning](http://semver.org) specification and communicating the **impact** of changes to consumers.

## Requirements

In order to use **Cake Release** you need:

- To have [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4) installed on Windows
- To host your code in a [Git repository](https://git-scm.com)
- Use a Continuous Integration service that allows you to [securely set up credentials](docs/usage/ci-configuration.md#authentication)
- A Git CLI version that meets [our version requirement](docs/support/git-version.md) installed in your Continuous Integration environment
- A [Node.js](https://nodejs.org) version that meets [our version requirement](docs/support/node-version.md) installed in your Continuous Integration environment
- To install the [Cake .NET Tool](https://cakebuild.net/docs/getting-started/setting-up-a-new-scripting-project)

## Installation

### GitHub

The [GitHub access token](https://github.com/settings/tokens) you need to create will have the following permissions:

```
[repo]
  - repo (for private repositories)
  - repo:status
  - repo_deployment
  - public_repo (for public repositories)
[admin:org]
  - read:org
[admin:repo_hook]
  - write:repo_hook
[user]
  - user:email
```

### SecretManagement and SecretStore

Install PowerShell [SecretManagement and SecretStore](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules)

> This step must be done only once. If you already installed these, you don't need to do it again

```powershell
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery
Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PSGallery
```

Configure the SecretStore vault

```powershell
PS> $credential = Get-Credential -UserName 'SecureStore'

PowerShell credential request
Enter your credentials.
Password for user SecureStore: **************
```

Once you have the password you can save it to an encrypted XML file.

```powershell
$securePasswordPath = 'C:\automation\passwd.xml'
$credential.Password |  Export-Clixml -Path $securePasswordPath
```

Configure your vault

```powershell
Register-SecretVault -Name YourVaultName -ModuleName Microsoft.PowerShell.SecretStore
$password = Import-CliXml -Path $securePasswordPath

$storeConfiguration = @{
    Authentication = 'Password'
    PasswordTimeout = 3600 # 1 hour
    Interaction = 'None'
    Password = $password
    Confirm = $false
}
Set-SecretStoreConfiguration @storeConfiguration
```

Set secrets
> At least one secret with the name **GH_TOKEN** containing your Github access token must be provided

```powershell
Set-Secret -Name GH_TOKEN -Secret "abcdefghijklmnopqrstuvwxyz" -Vault YourVaultName -Metadata @{Purpose="Github Token"}
```

Get secret info
```powershell
Get-SecretInfo -Name GH_TOKEN -Vault YourVaultName  | Select Name, Type, VaultName, Metadata
```
To remove your vault 
```powershell
Unregister-SecretVault -Name YourVaultName
```

### Semantic-release

Go to your root folder and install semantic-release and its plugins :

```powershell
npm install semantic-release -D
npm install @semantic-release/changelog -D
npm install @semantic-release/git -D
npm install @semantic-release/exec -D

```

You should have a folder structure similar to this :

```
├── /src
│   ├── <Project Name>
│   │   ├── .build
│   │   │   ├── /CakeRelease
│   │   │   │   ├── /Cake
│   │   │   │   ├── /Git
│   │   │   │   ├── /Powershell
│   │   │   │   ├── /Semantic
│   │   │   ├── build.ps1
│   │   ├── /node_modules
│   │   ├── Project.sln
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   ├── <Project Name>
│   │   ├── <Tests Project Name>
```

### Bash script

**Cake Release** is using Bash scripts with Semantic Release, so make sure you can run these witout issue (with [Git Bash](https://www.atlassian.com/git/tutorials/git-bash) for instance).

## Run Cake release

Run the build command located in the .build/CakeRelease folder:

```powershell
.\.build\CakeRelease\build.ps1 -securePasswordPath "C:\Automation\securestorepasswd.xml" -vault YourVaultName -createGithubRelease -publishPackageToNugetSource <NUGET_SOURCE   >
```

Required parameters:

| Name               | Value              | Description  |
| ------------------ | ------------------ | --------------------------------------------- |
| securePasswordPath | < path to your secure store password >  | your secure store password path   |                                                                                                               |
| vault              | < vault name > | Your vault name |


Optional parameters:

| Name                        | Value              | Description  |
| --------------------------- | ------------------ | ------------------------- |
| createGithubRelease         |                    | Creates a Github release  |                                                                                                               |
| publishPackageToNugetSource | < Nuget source>    | Publish package to your Nuget source |

## For Cake Release developers: Autobuild

You can use the --autobuild parameter so Cake Release can create its own release by itself. This parameter can also be used if you decide to move your .build and .config folders one level down at your project(.csproj) level.