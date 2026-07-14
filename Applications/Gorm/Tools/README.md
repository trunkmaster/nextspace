# gormtool
This tool allows the user to access certain features of Gorm from the command line.  It is a "hybrid" tool/headless application.

Usage: gormtool [options] inputfile

## Options include:
* ```--import-strings-file``` - this option imports a file in the .strings format and replaces the text in the model file with the mappings.   It takes a parameter which is the strings file to be imported.
* ```--export-strings-file``` - this option exports a string file from the model file to the file specified by the parameter.
* ```--export-xliff``` - this option exports an XLIFF1.2 file from the model file to the file specified by the parameter.
* ```--import-xliff``` - this option imports an XLIFF1.2 file into the model file to the file specified by the parameter. 
* ```--import-class``` - this option parses the header given by the parameter passed in, it will break any existing connections if the class is instantiated
* ```--export-class``` - this option exports the named class (passed in as a parameter) to a file by the same name in the current directory
* ```--read``` - specifies this file is to be the one read... optional.  If not used the last parameter is considered the input file.
* ```--write``` - specifies the output file the model is to be written to

NOTE: This tool is currently experimental please report any bugs.  Thank you. GC
