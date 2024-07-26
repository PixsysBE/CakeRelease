# Cake Release

**Cake Release** is a combination of [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7.4) scripts, [Cake Build](https://cakebuild.net/) script and [Semantic Release](https://github.com/semantic-release), automating build and deployment workflows of your .NET project.

The goal is to :

- Enforce conventional commits using Git hooks
- Automatically calculate the next version number, and update your changelog
- Create a release on GitHub with a full history of changes since the last release (if needed)
- Publish your package to NuGet or any NuGet source (if needed)

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

Install PowerShell [SecretManagement and SecretStore](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules) modules. This example assumes that your automation host is running Windows. These commands must be run in the user context of the automation account on the host.

> This step must be done only once. If you already installed these, you don't need to do it again

```powershell
Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PSGallery -Force
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Force
Import-Module Microsoft.PowerShell.SecretStore
Import-Module Microsoft.PowerShell.SecretManagement
```
 Get the identification information of the username 'SecureStore':

```powershell
PS> $credential = Get-Credential -UserName 'SecureStore'

PowerShell credential request
Enter your credentials.
Password for user SecureStore: **************
```

Once you set the password you can export it to an XML file, encrypted by Windows Data Protection (DPAPI).

```powershell
$securePasswordPath = 'C:\automation\passwd.xml'
$credential.Password |  Export-Clixml -Path $securePasswordPath
```

### Configure your vault

Next you must configure the SecretStore vault. The configuration sets user interaction to None, so that SecretStore never prompts the user. The configuration requires a password, and the password is passed in as a SecureString object. The -Confirm:false parameter is used so that PowerShell does not prompt for confirmation.

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

Set your secrets
> At least one secret with the name **GH_TOKEN** containing your Github access token must be provided

```powershell
Set-Secret -Name GH_TOKEN -Secret "abcdefghijklmnopqrstuvwxyz" -Vault YourVaultName -Metadata @{Purpose="Github Token"}
```

To get the list of all of your secrets, you can run:
```powershell
Get-SecretInfo -Name GH_TOKEN -Vault YourVaultName  | Select Name, Type, VaultName, Metadata
```
To remove your vault, run:
```powershell
Unregister-SecretVault -Name YourVaultName
```

### Semantic-release

Go to your root folder and install semantic-release and its plugins :

```powershell
npm install
```

You should have a folder structure similar to this :

```
├── /src
│   ├── <Project Name>
│   │   ├── /.build
│   │   │   ├── /CakeRelease
│   │   │   │   ├── /Cake
│   │   │   │   ├── /Git
│   │   │   │   ├── /Package
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

**Cake Release** is using Bash scripts with Semantic Release, so make sure you can run these without issue (with [Git Bash](https://www.atlassian.com/git/tutorials/git-bash) for instance).

## Set up your nuspec file

Set up your XML manifest to provide information and include files in your package. Rename the .config\nuspec.sample into .config\.nuspec and start customizing it :

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
  <metadata>
    <id></id>
    <title></title>
    <description></description>
    <authors></authors>
    <version>0.0.0.0</version>
    <readme>README.md</readme>
    <projectUrl></projectUrl>
  </metadata>
  <files>
    <!-- 
    Some examples, please set files and folders you want to be included in your package
    <file src="Controllers\" target="Controllers\" />
    <file src="nuspec" target=".nuspec" /> 
    -->
  </files>
</package>
```

## Run Cake release

Run the build command located in the .build/CakeRelease folder:

```powershell
.\.build\CakeRelease\build.ps1 -securePasswordPath "C:\Automation\securestorepasswd.xml" -vault YourVaultName -createGithubRelease -publishToSource <NUGET_SOURCE>
```

Required parameters:

| Name               | Value              | Description  |
| ------------------ | ------------------ | --------------------------------------------- |
| securePasswordPath | &lt;path to your secure store password&gt;  | your secure store password path   |                                                                                                               |
| vault              | &lt;vault name&gt; | Your vault name |


Optional parameters:

| Name                        | Value              | Description  |
| --------------------------- | ------------------ | ------------------------- |
| createGithubRelease         |                    | Creates a Github release  |                                                                                                               |
| publishToNuget | | Publish package to Nuget |
| publishToSource | &lt;Nuget source&gt;    | Publish package to your Nuget source |
| autoBuild | | See [Autobuild section](#for-cake-release-developers-autobuild) |
| csprojPath | &lt;csproj path&gt; | Path to your .csproj |
| nuspecFilePath | &lt;nuspec path&gt; | Path to your .nuspec |
| verbose | | Adds verbosity |

## For Cake Release developers: Autobuild

You can use the --autobuild parameter so Cake Release can create its own release by itself. This parameter can also be used if you decide to move your .build and .config folders one level down at your project(.csproj) level.