#Network Mapping and Enumeration Framework
The Network Mapping and Enumeration (NME) framework is a collection of Powershell scripts used to gather information about domains, networks, computers, services and applications from various sources, and then store the information in memory as custom Powershell objects. The object for a specific asset can be created in multiple ways, such as by importing output files from external tools (such as nmap), by running the enumeration scripts in the framework, or simply by creating them manually with built-in helper functions. Once created, the object acts as a structured placeholder for information gathered about that asset. Furthermore, and perhaps more importantly, the objects are supported as input to (most) other enumeration and testing scripts in the framework. This allows for easy access to all assets (no need to create separate target lists) and a flexible way to filter targets using the built-in capabilities of PowerShell.

The framework currently consists of the following scripts:
* Importers; scripts used for importing data from external sources and create framework-specific objects,
* Environment; scripts that contains helper functions and object definitions that make up the NME environment,
* MapEnum; scripts used for data collection, enumeration and testing of the assets,
* External; tools and scripts from external parties that add valuble functionality to the framework environment.

#Usage
The framework is loaded as a powershell module. So, place the NME folder in your Powershell module path and run "Import-Module NME". Run "Get-Command NME-*" to get a list of most commands.

All objects created by the framework are accessible through the $NMEObjects hashtable. Objects can be backed-up and restored with the NME-BackupObjects and NME-RestoreObjects scripts.

More in-depth help on the framework, its tools and uses will be coming soon.

# Notes
This framework is the result of me trying to learn how to write code. As such, the things in here will probably not be the prettiest, nor the fastest code you will ever see. Hopefully it will evolve over time though. I have a million ideas on what I want to do with it going forward so stay tuned.