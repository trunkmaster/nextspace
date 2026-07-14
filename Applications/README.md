# Applications directory
This directory holds the Gorm application and any other apps which might be written using the framework Gorm provides.
The future plans for this directory are to also contain a Plugins directory to facilitate editing Gorm files and other
model files in YCode (an upcoming GNUstep IDE) as the plugins would conform to a protocol usable by YCode.

An advantage of this approach is that there would be no direct dependencies between YCode and Gorm, but YCode could 
still utilize Gorm's features.
