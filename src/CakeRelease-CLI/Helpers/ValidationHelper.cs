namespace CakeReleaseCLI
{
    internal static class ValidationHelper
    {
        public static bool ValidateFileParameter(string? path)
        {
              if(string.IsNullOrWhiteSpace(path))
                {
                    Console.WriteLine("usage: dotnet cakerelease --file <file.yaml>");
                    return false;
                }
                if(!File.Exists(path))
                {
                    Console.WriteLine($"error: file '{path}' does not exist");
                    return false;
                }
                return true;
        }

        public static bool ValidatePublishToNugetParameter(bool publishToNuget)
        {
            if(publishToNuget)
            {
                
            }

            return true;
        }
    }
}

