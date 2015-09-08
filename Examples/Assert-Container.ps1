configuration ContainerSetup
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name WindowsFeature
    Import-DscResource -ModuleName nContainer

    <#WindowsFeature ContainersFeature
    {
        Name =   'Containers'
        Ensure = 'Present'
    }#>

    nContainer Container
    {
        Name      = 'TestContainer'
        ImageName = 'WindowsServerCore'
        Ensure    = 'Present'
        State     = 'Off'
        VirtualSwitchName = 'DemoSwitch'
    }

    nContainerImage ContainerImage
    {
        Name = 'TestContainerImage'
        ContainerName = 'TestContainer'
        Publisher = 'CN=Microsoft'
        Version = '1.0.0.0'
        Ensure = 'Present'
        DependsOn = '[nContainer]Container'
    }
}

$ScriptPath = Split-Path $MyInvocation.MyCommand.Path

ContainerSetup -OutputPath "$ScriptPath\..\CompiledConfigurations\ContainerSetup" -Verbose

Start-DscConfiguration -Wait -Force -Path "$ScriptPath\..\CompiledConfigurations\ContainerSetup" -ComputerName localhost -Verbose 

