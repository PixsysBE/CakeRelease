using System.CommandLine;
using YamlDotNet.RepresentationModel;

namespace CakeReleaseCLI
{
    internal class Program
    {

        private static int GetValues(string? path)
        {
            if(string.IsNullOrWhiteSpace(path)){
                return 1;
            }
            using var reader = new StreamReader(path);

            var yaml = new YamlStream();
            yaml.Load(reader);

            var root = (YamlMappingNode)yaml.Documents[0].RootNode;

            foreach(var (yamlNode, value) in root.Children)
            {
                var key = ((YamlScalarNode)yamlNode).Value;
                Console.WriteLine($"{key}: {value}");
            }
            return 0;
        }

        private static async Task<int> Main(string[] args)
        {
            var fileOption = new Option<string?>("--file", "--f")
            {
                Description = "The file path"
            };

            var publishToNugetOption = new Option<bool>("--publishToNuget","--n")
            {
                Description = "Publish or not to Nuget"
            };

            var publishToSourceOption = new Option<bool>("--publishToSource","--s")
            {
                Description = "Publish or not to custom source"
            };

            var publishToSourceKeyOption = new Option<string>("--publishToSourceKey","--k")
            {
                Description = "The custom source publishing key"
            };

            var createGithubReleaseOption = new Option<bool>("--createGithubRelease","--g")
            {
                Description = "Creates a Github Release"
            };

            var rootCommand = new RootCommand("CakeRelease CLI is a dotnet tool that helps you automating build and deployment workflows of your .NET projects.");
            rootCommand.Options.Add(fileOption);
            rootCommand.Options.Add(publishToNugetOption);
            rootCommand.Options.Add(publishToSourceOption);
            rootCommand.Options.Add(publishToSourceKeyOption);
            rootCommand.Options.Add(createGithubReleaseOption);

            rootCommand.SetAction(parseResult =>
            {
                var path = parseResult.GetValue(fileOption);
                if(!ValidationHelper.ValidateFileParameter(path)){
                    return 1;
                }

                var publishToNuget = parseResult.GetValue<bool>(publishToNugetOption);
                if(!ValidationHelper.ValidateFileParameter(publishToNuget)){
                    return 1;
                }

                return GetValues(path);
            });

            var parseResult = rootCommand.Parse(args);
            return await parseResult.InvokeAsync();
        } 
    }
}