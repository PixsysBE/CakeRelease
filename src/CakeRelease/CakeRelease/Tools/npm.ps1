[CmdletBinding()]
param(
  [string]$projectDirectory
)

function Compare-Version{
  param(
    [string]$version1,
    [string]$version2
  )

  $ver1 = [version]$version1
  $ver2 = [version]$version2
  return $ver1.CompareTo($ver2)
}

function Get-Versions{
  param(
    [string]$npmOutput
  )
  $versions=@{}

  foreach($line in $npmOutput -split "`n"){
    if($line -match "([\w|\-|\@|\/]+)@([^\s]+)"){ #"^(.+?)@([^\s]+)"){
      $pkgName= $matches[1]
      $pkgVersion= $matches[2]
      $versions[$pkgName] = $pkgVersion
    }
  }
  return $versions
}

function Get-NpmPackage-Version{
param(
  $PackagesToInstall,
  [string]$Directory = (Get-Location),
  [string]$ProjectName
)

Push-Location -Path $Directory

$initPackageJson = $false
$packageJsonPath = Join-Path $Directory ".\package.json"
if(-not (Test-Path -Path $packageJsonPath)){
  Write-Verbose "File package.json does not exist. Creating file..."
  npm init -y
  $initPackageJson = $true
}

$packageJsonContent = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json
if($initPackageJson -eq $true)
{
  $packageJsonContent.name = $ProjectName
  $packageJsonContent.description = "$ProjectName dependencies"
  $packageJsonContent.psobject.properties.remove("keywords")
  $packageJsonContent.psobject.properties.remove("main")
  $packageJsonContent.psobject.properties.remove("scripts")
  $packageJsonContent.psobject.properties.remove("author")
  $packageJsonContent.psobject.properties.remove("license")
  if( $null -eq (Get-Member -InputObject $packageJsonContent -MemberType NoteProperty -Name 'private')){
    Add-Member -InputObject $packageJsonContent -MemberType NoteProperty -Name 'private' -Value $true
  }

  $packageJsonContent | ConvertTo-Json | Set-Content $packageJsonPath
}

$localVersions=@{}
$propertiesToCheck = @($packageJsonContent.dependencies, $packageJsonContent.devDependencies)

foreach($propertyToCheck in $propertiesToCheck){
  if($propertyToCheck){
    $propertyToCheck.PSObject.Properties | ForEach-Object {
      $value = $_.Value
      if($value -match "^\^([^\s]+)"){
        $value = $matches[1]
      }
      $localVersions[$_.Name] = $value
    }
  }
}

$globalPackageVersionOutput = npm list -g --silent 2>&1
$globalVersions = Get-Versions -npmOutput $globalPackageVersionOutput

foreach($packageToInstall in $PackagesToInstall)
{
  $localPackageVersion = $null
  $globalPackageVersion = $null
  Write-Verbose "Looking for package $($packageToInstall.name) with version $($packageToInstall.version)"

  if($localVersions.ContainsKey($packageToInstall.name)){
    $localPackageVersion = $localVersions[$packageToInstall.name]
  }
  if($globalVersions.ContainsKey($packageToInstall.name)){
    $globalPackageVersion = $globalVersions[$packageToInstall.name]
  }

  $installPackage=$false

  if($localPackageVersion -or $globalPackageVersion){
    $updateNeeded=$false
    $checkIfGlobalPackageMustBeUpdated=$true
    if($localPackageVersion){
      $version = $localPackageVersion
      Write-Verbose "Package $($packageToInstall.name) is installed locally with version $version"
      if((Compare-Version -version1 $version -version2 $packageToInstall.version) -lt 0){
        $updateNeeded=$true
      } else {
        $checkIfGlobalPackageMustBeUpdated=$false
      }
    }
    if($globalPackageVersion){
      $version = $globalPackageVersion
      Write-Verbose "Package $($packageToInstall.name) is installed globally with version $version"
      if($checkIfGlobalPackageMustBeUpdated -eq $true -and (Compare-Version -version1 $version -version2 $packageToInstall.version) -lt 0){
        $updateNeeded=$true
      }
    }

    if($updateNeeded){
      Write-Verbose "Package version of $($packageToInstall.name) is inferior to $($packageToInstall.version). Updating package..."
      $installPackage=$true
    }

  } else{
    Write-Verbose "Package $($packageToInstall.name) is not installed. Installing..."
    $installPackage=$true
  }

  if($installPackage -eq $true){
    npm install "$($packageToInstall.name)@$($packageToInstall.version)" --save
    Write-Verbose "Package $($packageToInstall.name) has been successfully installed with version $($packageToInstall.version)."
  }
}

Pop-Location
}

$semanticDirectory =  (Join-Path -Path $projectDirectory -ChildPath "../.build/CakeRelease/Semantic/") 
if(-not (test-path $semanticDirectory)){
  New-Item -Path $semanticDirectory -ItemType Directory
}

Write-Verbose "semanticDirectory: $semanticDirectory"

$projectName = "cakerelease"
$packagesToInstall = @(
  @{
    "name" = "semantic-release"
    "version" = "24.0.0"
  },
  @{
    "name" = "@semantic-release/changelog"
    "version" = "6.0.3"
  },
  @{
    "name" = "@semantic-release/exec"
    "version" = "6.0.3"
  },
  @{
    "name" = "@semantic-release/git"
    "version" = "10.0.1"
  }
)

Get-NpmPackage-Version -PackagesToInstall $packagesToInstall -Directory ($semanticDirectory | Resolve-Path) -ProjectName $projectName
