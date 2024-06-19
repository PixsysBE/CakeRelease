﻿#addin "nuget:https://api.nuget.org/v3/index.json?package=Cake.Figlet&version=2.0.1"
#addin "nuget:https://api.nuget.org/v3/index.json?package=Cake.Npx&version=1.7.0"
#addin "nuget:?package=Cake.Git&version=4.0.0"
// #addin nuget:?package=Newtonsoft.Json&version=13.0.1

// using Newtonsoft.Json;
///////////////////////////////////////////////////////////////////////////////
// ARGUMENTS
///////////////////////////////////////////////////////////////////////////////

var target = Argument<string>("target", "Default");
var configuration = Argument<string>("configuration", "Release");
var projectName = Argument<string>("projectName", "Undefined");
var publishPackageToNugetSource = Argument<bool>("publishPackageToNugetSource", false);
var rootPath = Argument<string>("rootPath", "Undefined");
var projectPath = Argument<string>("projectPath", "Undefined");
// var packageId = Argument<string>("packageId", "");
// var packageTitle = Argument<string>("packageTitle", "");
// var packageDescription = Argument<string>("packageDescription", "");
// var packageAuthors = Argument<string>("packageAuthors", "");
var buildPath = Argument<string>("buildPath", "");
var nuspecFilePath = Argument<string>("nuspecFilePath", "");

///////////////////////////////////////////////////////////////////////////////
// GLOBAL VARIABLES
///////////////////////////////////////////////////////////////////////////////

//var projectDirectory = MakeAbsolute(Directory("../../../TestSemanticVersion")); //Make sure this path goes to .csproj location
//var projectDirectory = MakeAbsolute(Directory("../../../TestSemanticVersion")); //Make sure this path goes to root
Context.Environment.WorkingDirectory = Directory(projectPath);//projectDirectory;

// Get paths from working directory
var semanticDirectory = MakeAbsolute(Directory($"{buildPath}.build/CakeRelease/Semantic")); //"../.build/CakeRelease/Semantic"
var releaseVersion = "0.0.0";
var artifactsDir = MakeAbsolute(Directory($"{buildPath}.build/CakeRelease/Semantic/Artifacts")); //"../.build/CakeRelease/Semantic/Artifacts"
var binDir = MakeAbsolute(Directory("./bin"));
var objDir = MakeAbsolute(Directory("./obj"));
var solutions = GetFiles("../*.sln");
var projects = GetFiles("./*.csproj");
var testProjects = GetFiles("../**/*.Tests.csproj");
var isLocalBuild = BuildSystem.IsLocalBuild;
var repositoryDirectoryPath = MakeAbsolute(Directory("./../../.."));

var currentBranch = GitBranchCurrent(repositoryDirectoryPath);
var isRunningOnMasterBranch = StringComparer.OrdinalIgnoreCase.Equals("master",currentBranch.FriendlyName);
var isRunningOnBetaBranch = StringComparer.OrdinalIgnoreCase.Equals("beta",currentBranch.FriendlyName);

// Set working directory to root path
Context.Environment.WorkingDirectory = Directory(rootPath);

// var isRunningOnAppveyorMasterBranch = StringComparer.OrdinalIgnoreCase.Equals(
//     "master",
//     BuildSystem.AppVeyor.Environment.Repository.Branch
// );

// We only attempt to release during an appveyor build caused by new commits to the master branch.
var shouldRelease = isRunningOnMasterBranch || isRunningOnBetaBranch;  //isLocalBuild;
var changesDetectedSinceLastRelease = false;

Action<NpxSettings> requiredSemanticVersionPackages = settings => settings
    .AddPackage("semantic-release@24.0.0")
    .AddPackage("@semantic-release/changelog@6.0.3")
    .AddPackage("@semantic-release/git@10.0.1")
    .AddPackage("@semantic-release/exec@6.0.3");

// var packageId = "";
// var packageTitle = "";
// var packageDescription = "";
// var packageAuthors = "";
//////////////////////////////////////////////////////////////////////
// CLASSES
//////////////////////////////////////////////////////////////////////

// public class PackageData
// {
//     public string Id { get; set; }
//     public string Title { get; set; }
//     public string Description { get; set; }
//     public string Authors { get; set; }
// }

///////////////////////////////////////////////////////////////////////////////
// SETUP / TEARDOWN
///////////////////////////////////////////////////////////////////////////////

Setup(context =>
{
    Information(Figlet(projectName));
    Information("Local build: {0}", isLocalBuild);
    Information("Current branch: {0}", currentBranch.FriendlyName);
    Information("Should release: {0}", shouldRelease);
    Information("Publish release to Github: {0}", EnvironmentVariable<bool>("PUBLISH_RELEASE_TO_GITHUB",false));

//Information("projectDirectory: {0}", projectDirectory);
// Information("semanticDirectory: {0}", semanticDirectory);
// Information("artifactsDir: {0}", artifactsDir);
// Information("binDir: {0}", binDir);
// Information("repositoryDirectoryPath: {0}", repositoryDirectoryPath);
});

Teardown(context =>
{
    Information("Finished running tasks √");
});

//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Default")
    .IsDependentOn("Build");

Task("Build")
    .IsDependentOn("Run dotnet --info")
    //.IsDependentOn("Parse-Json")
    .IsDependentOn("Clean")
    .IsDependentOn("Get next semantic version number")
    .IsDependentOn("Build solution")
    .IsDependentOn("Run tests")
    .IsDependentOn("Package")
    .IsDependentOn("Release")
    ;

Task("Run dotnet --info")
    .Does(() =>
{
    Information("dotnet --info");
    StartProcess("dotnet", new ProcessSettings { Arguments = "--info" });
});

Task("Clean")
    .Does(() =>
{
    Information("Cleaning {0} folder", artifactsDir);
    CleanDirectory(artifactsDir);
    Information("Cleaning {0} folder", binDir);
    CleanDirectory(binDir);
    Information("Cleaning {0} folder", objDir);
    CleanDirectory(objDir);
});

// Task("Parse-Json")
//     .Does(() =>
// {
//     Information ("Data Json: {0}", dataJson);
//     // Convert JSON string to VersionInfo object
//     var versionInfo = JsonConvert.DeserializeObject<PackageData>(dataJson);
//     if (versionInfo == null)
//     {
//         Error("Failed to parse JSON data.");
//         return;
//     }

//     var packageId = versionInfo.Id;
//     var packageTitle = versionInfo.Title;
//     var packageDescription = versionInfo.Description;
//     var packageAuthors = versionInfo.Authors;
// });
/*
Normally this task should only run based on the 'shouldRelease' condition,
however sometimes you want to run this locally to preview the next sematic version
number and changlelog.

To do this run the following locally:
> $env:NUGET_TOKEN="insert_token_here"
> $env:GITHUB_TOKEN="insert_token_here"
> .\build.ps1  -ScriptArgs '-target="Get next semantic version number"'

NOTE: The environment variable will need to be set to pass the semantic-release verify conditions

Explicitly setting the target will override the 'shouldRelease' condition
*/
Task("Get next semantic version number")
    .WithCriteria(shouldRelease || target == "Get next semantic version number" )
    .Does(() =>
{
        Context.Environment.WorkingDirectory = semanticDirectory;
        Information("Running semantic-release in dry run mode to extract next semantic version number");

        string[] semanticReleaseOutput;    

        Npx("semantic-release", "--dry-run", requiredSemanticVersionPackages, out semanticReleaseOutput);

        Information(string.Join(Environment.NewLine, semanticReleaseOutput));

        var nextSemanticVersionNumber = ExtractNextSemanticVersionNumber(semanticReleaseOutput);

        if (nextSemanticVersionNumber == null) {
            Warning("There are no relevant changes, skipping release");
        } else {
            Information("Next semantic version number is {0}", nextSemanticVersionNumber);
            releaseVersion = nextSemanticVersionNumber;
            changesDetectedSinceLastRelease = true;
        }
});

Task("Build solution")
    .Does(() =>
{    
    foreach(var solution in solutions)
    {
        Information("Building solution {0} v{1}", solution.GetFilenameWithoutExtension(), releaseVersion);

        var assemblyVersion = $"{releaseVersion}.0";

        DotNetBuild(solution.FullPath, new DotNetBuildSettings()
        {
            Configuration = configuration,
            MSBuildSettings = new DotNetMSBuildSettings()
                .WithProperty("Version", assemblyVersion)
                .WithProperty("AssemblyVersion", assemblyVersion)
                .WithProperty("FileVersion", assemblyVersion)
                // 0 = use as many processes as there are available CPUs to build the project
                // see: https://develop.cakebuild.net/api/Cake.Common.Tools.MSBuild/MSBuildSettings/60E763EA
                .SetMaxCpuCount(0)
        });
    }
});

 Task("Run tests")
     .Does(() =>
 {
     foreach(var testProject in testProjects)
     {
         Information("Testing project {0}", testProject.GetFilenameWithoutExtension());

        DotNetTest(testProject.FullPath, new DotNetTestSettings
        {
            Configuration = configuration,
            NoBuild = true,
            NoRestore = true
        });
     }
 });

Task("Package")
    .Does(() =>
{    
    foreach(var project in projects)
    {
        var projectDirectory = project.GetDirectory().FullPath;
        if(projectDirectory.EndsWith("Tests")) continue;

        Information("Packaging project {0} v{1}", project.GetFilenameWithoutExtension(), releaseVersion);
        Context.Environment.WorkingDirectory = Directory(projectDirectory);
        var assemblyVersion = $"{releaseVersion}.0";

        // // Transform nuspec file
         var nuspecFile = File(nuspecFilePath);
         Information("Updating version in nuspec file to {0}", assemblyVersion);

        // Define the namespace
        var xmlPokeSettings = new XmlPokeSettings {
            Namespaces = new Dictionary<string, string> {
                { "ns", "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd" }
            }
        };
        // // Use XmlPoke to update the version element
        // XmlPoke(nuspecFile, "//ns:package/ns:metadata/ns:id", packageId, xmlPokeSettings);
        // XmlPoke(nuspecFile, "//ns:package/ns:metadata/ns:title", packageTitle, xmlPokeSettings);
        // XmlPoke(nuspecFile, "//ns:package/ns:metadata/ns:description", packageDescription, xmlPokeSettings);
        // XmlPoke(nuspecFile, "//ns:package/ns:metadata/ns:authors", packageAuthors, xmlPokeSettings);
        XmlPoke(nuspecFile, "//ns:package/ns:metadata/ns:version", assemblyVersion, xmlPokeSettings);

        Information("NuspecFile: {0}", nuspecFilePath);
        Information("NuspecBasePath: {0}", projectDirectory);

        DotNetPack(project.FullPath, new DotNetPackSettings {
            Configuration = configuration,
            OutputDirectory = artifactsDir,
            // https://learn.microsoft.com/en-us/nuget/reference/msbuild-targets#packing-using-a-nuspec
            ArgumentCustomization = pag =>
            {
                pag.Append($"-p:NuspecFile={nuspecFilePath}");
                pag.Append($"-p:NuspecBasePath={projectDirectory}");
                return pag;
            },
            NoBuild = true,
            MSBuildSettings = new DotNetMSBuildSettings()
                .WithProperty("Version", assemblyVersion)
                .WithProperty("AssemblyVersion", assemblyVersion)
                .WithProperty("FileVersion", assemblyVersion)
        });
    }
});

Task("Release")
    .WithCriteria(shouldRelease)
    // we need to lazily evaluate changesDetectedSinceLastRelease, // as it's value can change during the build
    .WithCriteria(() => changesDetectedSinceLastRelease)
    .Does(() =>
{
    Context.Environment.WorkingDirectory = semanticDirectory;
    Information("Releasing v{0}", releaseVersion);
    Information("Updating CHANGELOG.md");
    Information("Creating github release");
    Information("Pushing to NuGet");
    if(isLocalBuild){
        Npx("semantic-release", "--no-ci", requiredSemanticVersionPackages);
    }
    else{
        Npx("semantic-release", requiredSemanticVersionPackages);
    }
});

///////////////////////////////////////////////////////////////////////////////
// EXECUTION
///////////////////////////////////////////////////////////////////////////////

RunTarget(target);

///////////////////////////////////////////////////////////////////////////////
// Helpers
///////////////////////////////////////////////////////////////////////////////

string ExtractNextSemanticVersionNumber(string[] semanticReleaseOutput)
{
    var extractRegEx = new System.Text.RegularExpressions.Regex("^.+next release version is (?<SemanticVersionNumber>.*)$");

    return semanticReleaseOutput
        .Select(line => extractRegEx.Match(line).Groups["SemanticVersionNumber"].Value)
        .Where(line => !string.IsNullOrWhiteSpace(line))
        .SingleOrDefault();
}