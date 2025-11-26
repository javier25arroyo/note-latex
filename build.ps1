# This script is a convenient wrapper to build the default LaTeX project.
# It ensures the environment is set up and then invokes the build.

# Source the setup script to make sure directories and functions are available
. .\setup-latex-env.ps1

# Call the build function with the default main.tex file
Invoke-LatexBuild -Path '.\latex-env\src\main.tex'
