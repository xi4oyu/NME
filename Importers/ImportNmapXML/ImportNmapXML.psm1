﻿<#

.SYNOPSIS
Tool to import data from nmap XML logs

.DESCRIPTION
This tool can be used to import data from nmap xml output. Based on the nmap xml data, the tool creates computer objects and feeds various types of data to the object properties, including IP address, ports and service information. The tool also has the ability to import data from nmap host- and port script output.

.PARAMETER FilePath
Specifies the path to the nmap xml log file to be parsed. The tool also accepts multiple files as FileInfo objects coming through the pipeline (see examples).

.PARAMETER DataType
Specifies one or multiple data types that should be imported. Options include: 
- Hosts: Parses all hosts in the log and creates computer objects. Host-level data in the nmap xml, such as IP address, trace and state information, will also be imported into the computer object.
- Ports: Parses the ports section of the nmap log and saves the data in the "Ports" property of the computer object
- Services: Enables parsing of host- and port scripts (see Scripts parameter)

By default, the tool imports Hosts, Ports and Services data.

.PARAMETER Scripts
Specifies the name of the host or port script (as named in nmap), whos data should be parsed. It also supports 'All' to include all supported scripts for parsing. This is the default.

.PARAMETER Replace
This switch parameter controls whether the tool should replace any existing data when parsing Ports data. By default, the tool will only import ports data if the port does not currently exists.

.EXAMPLE
NME-ImportNmapXML -FilePath c:\nmap-log.xml

.EXAMPLE
Get-Location c:\nmaplogs\*.xml| NME-ImportNmapXML -DataType PortData

.EXAMPLE
NME-ImportNmapXML -DataType ScriptData -Scripts ms-sql-info

.NOTES

Module dependencies
-------------------
- Environment: HelperFunctions, CreateObjects

Issues / Other
--------------

#>


Function Import-NmapXML
{
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$Filepath,

        [Parameter()]
        [ValidateSet('Hosts','Ports','Services')]
        [string[]]$Items = ('Hosts','Ports','Services'),

        [Parameter()]
        [ValidateSet('ms-sql-info','broadcast-ms-sql-discover','smb-enum-shares','All')]
        [string[]]$Scripts = ('All'),

        [Parameter()]
        [switch]$Replace
    )

    BEGIN
    {
        $CmdName = 'Import-NmapXML'
        $CmdAlias = 'NME-ImportNmapXML'

        $scriptName = $PSCmdlet.MyInvocation.MyCommand.Name

        $message = 'Starting Nmap data import'
        LogEvent -command $CmdName -severity Info -Event $message -ToConsole
    }

    PROCESS
    {
        [xml]$nmapxml = Get-Content $Filepath

        Write-Verbose "Importing data from $Filepath"

        foreach ($host in $nmapxml.nmaprun.host) #Iterates through each host
        {
            $ip = ($host.address|?{$_.addrtype -match 'ip'}).addr
            $compObj = Get-ComputerObject -IP $ip

            if($Items -contains 'Hosts')
            {
                Write-Verbose "Parsing host data ($ip)"

                $StateObj = New-Object psobject -Property @{
                    State         = $host.status.state
                    QueryProtocol = 'nmap import'
                    QueryPort     = 'nmap import'
                    QueryTime     = (New-Object datetime(1970,1,1,0,0,0,0,[System.DateTimeKind]::Utc)).AddSeconds($host.starttime).ToString()
                } |Select-Object State,QueryProtocol,QueryPort,QueryTime #Creates results object

                $compObj.State = $StateObj

                #$compObj.MACAddress = ($host.address|?{$_.addrtype -eq 'mac'}).addr

                if($host.trace)
                {
                    foreach($hop in $host.trace.hop)
                    {
                        $traceObj = New-Object psobject -Property @{
                            Hop      = $hop.ttl
                            IP       = $hop.ipaddr
                            HostName = $hop.host
                            RTT      = $hop.rtt
                        } |Select Hop,IP,HostName,RTT

                        $compObj.NetTrace += @($traceObj)
                    }
                }
            }

            if($Items -contains 'Ports')
            {
                Write-Verbose "Parsing host data ($ip)"

                foreach($port in ($host.ports.port)) #Iterates through port node data
                {
                    if( !( $portObj = $compObj.Ports|?{($_.Protocol -eq $port.protocol) -and ($_.PortNumber -eq $Port.portid)} )) #Binds to existent port object, or creates and binds to new port object if none exist.
                    {
                        $portObj = New-Object psobject -Property @{
                            Protocol    = $null
                            PortNumber  = $null
                            Socket      = $null
                            Service     = $null
                            State       = $null
                        }

                        $compObj.Ports += $portObj
                    }

                    if($Replace -or ($portObj.Protocol -eq $null)) #Inserts new data if object is new or $replace is enabled
                    {
                        $portObj.Protocol       = $port.protocol
                        $portObj.PortNumber     = $port.portid
                        $portObj.Socket         = "$($port.protocol)/$($port.portid)"
                    }
                    else
                    {
                        Write-Verbose 'Port object data exists (skipping)'
                    }


                    
                    if( !($serviceObj = $portObj.Service)) #Binds to existent service object, or creates and binds to new port object if none exist.
                    {
                        $serviceObj = New-Object psobject -Property @{
                            Name        = $null
                            Product     = $null
                            Version     = $null
                            ExtraInfo   = $null
                            Tunnel      = $null
                            Method      = $null
                            Conf        = $null
                            Cpe         = @()
                            Certificate = $null
                        }

                        $portObj.Service = $serviceObj
                    }

                    if($Replace -or ($serviceObj.Name -eq $null)) #Inserts new data if object is new or $replace is enabled
                    {
                        $serviceObj.Name      = $port.service.name
                        $serviceObj.Product   = $port.service.product
                        $serviceObj.Version   = $port.service.version
                        $serviceObj.ExtraInfo = $port.service.extrainfo
                        $serviceObj.Tunnel    = $port.service.tunnel
                        $serviceObj.Method    = $port.service.method
                        $serviceObj.Conf      = $port.service.conf
                        $serviceObj.Cpe       = $port.service.cpe
                    }
                    else
                    {
                        Write-Verbose 'Port service object exists (skipping)'
                    }

                    if( !($stateObj = $portObj.State)) #Binds to existent service object, or creates and binds to new port object if none exist.
                    {
                        $stateObj = New-Object psobject -Property @{
                            State      = $null
                            Reason     = $null
                            Reason_ttl = $null
                        }

                        $portObj.State = $stateObj
                    }

                    if($Replace -or ($stateObj.State -eq $null)) #Inserts new data if object is new or $replace is enabled
                    {
                        $stateObj.State      = $port.state.state 
                        $stateObj.Reason     = $port.state.reason
                        $stateObj.Reason_ttl = $port.state.reason_ttl
                    }
                    else
                    {
                        Write-Verbose 'Port state object exists (skipping)'
                    }
                }
            }

            if($Items -contains 'Services')
            {
                Write-Verbose "Parsing script data ($ip)"

                $scriptCol = @{}

                foreach ($script in ($host.hostscript.script)) #Extracts host script data
                {
                    $scriptCol += @{$script.id = $script.OuterXml}
                }

                foreach($port in ($host.ports.port)) #Extracts port script data
                {
                    foreach ($script in $port.script)
                    {
                        $scriptCol += @{$script.id = $script.OuterXml}
                    }
                }

                #################################
                # Script-specific parsers below #
                #################################

                if($Scripts -contains 'ms-sql-info' -or $Scripts -contains 'All')
                {
                    if($scriptCol.ContainsKey('ms-sql-info'))
                    {
                        $data = $scriptCol["ms-sql-info"]
                        $array = $data -split '\[.*?\]' |Select-Object -Skip 1

                        foreach($i in $array)
                        {
                            $sqlport = ([regex]'(?<=TCP port: ).*?(?=&#)').Match($i).Value
                            $sqlpipe = ([regex]'(?<=Named pipe: ).*?(?=&#)').Match($i).Value

                            if($sqlport)
                            {
                                $mssqlObj = Get-MSSQLObject -HostIP $ip -TCPPort $sqlport
                            }
                            else
                            {
                                $mssqlObj = Get-MSSQLObject -HostIP $ip -NamedPipe $sqlpipe
                            }

                            $mssqlObj.TCPPort      = $sqlport
                            $mssqlObj.NamedPipe    = $sqlpipe
                            $mssqlObj.InstanceName = ([regex]'(?<=Instance name: ).*?(?=&#)').Match($i).Value
                            $mssqlObj.IsClustered  = ([regex]'(?<=Clustered: ).*?(?=&#)').Match($i).Value
                            $mssqlObj.Version      = ([regex]'(?<=Version number: ).*?(?=&#)').Match($i).Value
                            $mssqlObj.Product      = ([regex]'(?<=Version: ).*?(?=&#)').Match($i).Value
                        }
                    }
                    else
                    {
                        Write-Verbose "No script for $key found"
                    }
                }

                if($Scripts -contains 'broadcast-ms-sql-discover' -or $Scripts -contains 'All')
                {
                    if($scriptCol.ContainsKey('broadcast-ms-sql-discover'))
                    {
                        $data = $scriptCol['broadcast-ms-sql-discover']
                        $array = $data -split '\[.*?\]' |Select-Object -Skip 1

                        foreach($i in $array)
                        {
                            $sqlport = ([regex]'(?<=TCP port: ).*?(?=&#)').Match($i).Value
                            $sqlpipe = ([regex]'(?<=Named pipe: ).*?(?=&#)').Match($i).Value

                            if($sqlport)
                            {
                                $mssqlObj = Get-MSSQLObject -HostIP $ip -TCPPort $sqlport
                            }
                            else
                            {
                                $mssqlObj = Get-MSSQLObject -HostIP $ip -NamedPipe $sqlpipe
                            }

                            $mssqlObj.TCPPort      = $sqlport
                            $mssqlObj.NamedPipe    = $sqlpipe
                            $mssqlObj.InstanceName = ([regex]'(?<=Name: ).*?(?=&#)').Match($i).Value
                            $mssqlObj.IsClustered  = $null
                            $mssqlObj.Version      = $null
                            $mssqlObj.Product      = ([regex]'(?<=Product: ).*?(?=&#)').Match($i).Value
                        }
                    }
                    else
                    {
                        Write-Verbose "No script for $key found"
                    }
                }

                if($Scripts -contains 'smb-enum-shares' -or $Scripts -contains 'All')
                {
                    if($scriptCol.ContainsKey('smb-enum-shares'))
                    {
                        $data = $scriptCol['smb-enum-shares']
                        $array = $data -replace '    ' -split '&#xA;  ' |?{$_ -notmatch '<script id=' -and $_ -notmatch 'ERROR: Enumerating shares failed'}

                        foreach($i in $array)
                        {
                            $sharename = ([regex]'.*(?=&#xA;)').Match($i).Value

                            $shareObj = Get-SMBShareObject -HostIP $ip -ShareName $sharename

                            $shareObj.Type       = ([regex]'(?<=&#xA;Type: ).*?(?=&#xA;').Matches($i).Value
                            $shareObj.Remark     = ([regex]'(?<=&#xA;Comment: ).*?(?=&#xA;').Matches($i).Value
                            $shareObj.Permissions.AllowRead = $null #To be fixed when I can test
                            $shareObj.Permissions.AllowWrite = $null #To be fixed when I can test
                        }
                    }
                    else
                    {
                        Write-Verbose "No script for $key found"
                    }
                }
            }
        }

        Write-Verbose "Data import from $Filepath completed"
    }

    END
    {
        $message = 'Nmap data import completed'
        LogEvent -command $scriptName -severity Info -Event $message -ToConsole
    }
}