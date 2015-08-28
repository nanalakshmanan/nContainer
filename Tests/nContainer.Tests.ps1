$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"


#region Helper functions
function Init-Container
{
    $global:Containers = @{}
    $global:Containers += @{PresentRunning = @{Id = 1; Name = 'PresentRunning';ImageName = 'WindowsServerCore';State = 'Running';SwitchName = 'DemoSwitch'}}
    $global:Containers += @{PresentOff = @{Id = 2; Name = 'PresentOff';ImageName = 'WindowsServerCore';State = 'Off';SwitchName = 'DemoSwitch'}}
}
#endregion Helper function

Describe "nContainer UnitTests" {

# define the global variables
BeforeAll {
        # container images
        $global:ContainerImages = @{}
        $ServerCoreImage = @{Name = 'WindowsServerCore';Publisher = 'CN=Microsoft'; IsOSImage = $true}
        $global:ContainerImages += @{$ServerCoreImage.Name = $ServerCoreImage}

        # VM Switches
        $global:VMSwitches = @{}
        $DemoSwitch = @{Name = 'DemoSwitch'; SwitchType = 'External'}
        $global:VMSwitches += @{$DemoSwitch.Name = $DemoSwitch}

        # containers
        Init-Container
}

AfterAll {
    Remove-Variable -Name ContainerImages -Scope Global
    Remove-Variable -Name VMSwitches -Scope Global
    Remove-Variable -Name Containers -Scope Global
}

#region Mocks
        <#Mock -modulename nContainer -CommandName Get-ContainerImage -Verifiable -MockWith {
                        
            if ($global:ContainerImages.ContainsKey($Name))
            {
                $ContainerImage = $global:ContainerImages[$Name]
                $MockObject = New-Object psobject -Property $ContainerImage
                $MockObject.PSTypeNames[0] = 'Microsoft.Containers.PowerShell.Objects.ContainerImage'

                return $MockObject
            }           
        }#>

        Mock -ModuleName nContainer -CommandName Get-VMSwitch -MockWith {
            
            [CmdletBinding()]
            param([string]$Name)

            if ($global:VMSwitches.ContainsKey($Name))
            {
                return $global:VMSwitches[$Name]
            }
            else
            {
                Write-Error "Virtual switch $Name not found"
            }
        }

        Mock -ModuleName nContainer -CommandName New-Container -MockWith {

            $Container = @{Name = $Name;ImageName = $ImageName; State = 'Off'; SwitchName = $SwitchName; Id = (Get-Random -Minimum 2 -Maximum 100)}
            $global:Containers += @{$Name = $Container }
            $MockObject = New-Object psobject -Property $Value
            $MockObject.PSTypeNames[0] = 'Microsoft.Containers.PowerShell.Objects.Container'

            $MockObject
        }

        Mock -ModuleName nContainer -CommandName Start-Container -MockWith {
            $global:Containers[$Name] | % {
                $_.State = 'Running'
            }
        }

        Mock -ModuleName nContainer -CommandName Stop-Container -MockWith {
            $global:Containers[$Name] | % {
                $_.State = 'Off'
            }
        }

        Mock -ModuleName nContainer -CommandName Get-Container -MockWith {

            [CmdletBinding()]
            param([string[]]$Name)
            $RetValue = @()

            $Name | % {
                if ($global:Containers.ContainsKey($_))
                {
                    $Value = $global:Containers[$_]
                    $MockObject = New-Object psobject -Property $Value
                    $MockObject.PSTypeNames[0] = 'Microsoft.Containers.PowerShell.Objects.Container'
                    $RetValue += $MockObject
                }
                else
                {
                    Write-Error "Container $($_) not found"
                }
            }

            if ($RetValue.Count -gt 0)
            {
                return $RetValue
            }
        }

        Mock -ModuleName nContainer -CommandName Remove-Container -MockWith {
            $Name | % {
                if ($global:Containers.ContainsKey($_))
                {
                    $global:Containers.Remove($_)
                }
            }
        }

#endregion Mocks

    Context "Exception Tests" {

        It  "Test image name validation"  {
            $Container = New-nContainer
            $Container.ImageName = 'NonExistent'

            {$Container.Test()} | Should throw
        }

        It "Test VM Switch validation" {
            $Container = New-nContainer
            $Container.VirtualSwitchName = 'NonExistent'
            $Container.ImageName = 'WindowsServerCore'

            {$Container.Test()} | should throw
        }

    }

    Context "Test methods tests" {

        $TestCases = @()

        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                foreach($State in @('Running', 'Off'))
                {
                    foreach($CurrentState in @('Running', 'Off'))
                    {
                        $ExpectedResult = $false

                        if ($Ensure -eq $Actual)
                        {
                            if (($Ensure -eq 'Present') -and ($State -eq $CurrentState))
                            {
                                $ExpectedResult = $true
                            }
                            elseif ($Ensure -eq 'Absent')
                            {
                                $ExpectedResult = $true
                            }
                        }
                        
                        $TestCases += @{Ensure = $Ensure;Actual = $Actual; State = $State; CurrentState = $CurrentState; ExpectedResult = $ExpectedResult}
                    }
                }
            }
        }

        It 'Test() : Ensure : <Ensure>, Actual : <Actual>, desired state : <State>, current state : <CurrentState>' -TestCases $TestCases {
            param( $Ensure, $Actual, $State, $CurrentState, $ExpectedResult)

            $Container = New-nContainer
            $Container.Name = ($Actual + $CurrentState).Trim()
            $Container.Ensure = $Ensure
            $Container.State = $State
            $Container.ImageName = 'WindowsServerCore'
            $Container.VirtualSwitchName = 'DemoSwitch'

            $Container.Test() | Should Be $ExpectedResult
        }
    }

    Context "Set method tests" {

        $TestCases = @()

        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                foreach($State in @('Running', 'Off'))
                {
                    foreach($CurrentState in @('Running', 'Off'))
                    {
                        $SetCalled = $true

                        if ($Ensure -eq $Actual)
                        {
                            if (($Ensure -eq 'Present') -and ($State -eq $CurrentState))
                            {
                                $SetCalled = $false
                            }
                            elseif ($Ensure -eq 'Absent')
                            {
                                $SetCalled = $false
                            }
                        }
                        
                        if ($SetCalled)
                        {
                            $TestCases += @{Ensure = $Ensure;Actual = $Actual; State = $State; CurrentState = $CurrentState;}
                        }
                    }
                }
            }
        }

        BeforeEach {Init-Container}
        It 'Set() : Ensure : <Ensure>, Actual : <Actual>, desired state : <State>, current state : <CurrentState>' -TestCases $TestCases {

            param( $Ensure, $Actual, $State, $CurrentState)

            $Container = New-nContainer
            $Container.Name = ($Actual + $CurrentState).Trim()
            $Container.Ensure = $Ensure
            $Container.State = $State
            $Container.ImageName = 'WindowsServerCore'
            $Container.VirtualSwitchName = 'DemoSwitch'

            $Container.Set()

            if ($Ensure -eq 'Absent')
            {
                if ($Actual -eq 'Present')
                {
                    Assert-MockCalled -CommandName Remove-Container -Exactly 1 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName Start-Container  -Exactly 0 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName New-Container    -Exactly 0 -Scope It -ModuleName nContainer

                    if ($CurrentState -eq 'Running')
                    {
                        Assert-MockCalled -CommandName Stop-Container -Exactly 1 -Scope It -ModuleName nContainer
                    }
                    else
                    {
                        Assert-MockCalled -CommandName Stop-Container -Exactly 0 -Scope It -ModuleName nContainer
                    }
                }
                else
                {
                    Assert-MockCalled -CommandName Remove-Container -Exactly 0 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName New-Container    -Exactly 0 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName Start-Container  -Exactly 0 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName Stop-Container   -Exactly 0 -Scope It -ModuleName nContainer
                }
            } 

        }
        
    }

    Context "Get method tests" {
        
        $Testcases = @()
        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                foreach($State in @('Running', 'Off'))
                {
                    foreach($CurrentState in @('Running', 'Off'))
                    {
                        $Testcases += @{Ensure = $Ensure; Actual = $Actual; State = $State; CurrentState = $CurrentState}
                    }
                }
            }
        }

        BeforeEach {Init-Container}

        It 'Get(): Ensure : <Ensure>, Actual : <Actual>, desired state : <State>, current state : <CurrentState>' -TestCases $Testcases {

                    param( $Ensure, $Actual, $State, $CurrentState)

            if ($Actual -eq 'Absent')
            {
                $Global:Containers = @{}
            }

            $Container = New-nContainer
            $Name = ($Actual + $CurrentState).Trim()
            $Container.Name = $Name
            $Container.Ensure = $Ensure
            $Container.State = $State
            $Container.ImageName = 'WindowsServerCore'
            $Container.VirtualSwitchName = 'DemoSwitch'

            $ReturnValue = $Container.Get()

            $ReturnValue.Name | Should be $Name
            $ReturnValue.ImageName | Should be 'WindowsServerCore'
            $ReturnValue.VirtualSwitchName | Should be 'DemoSwitch'

            if ($Actual -eq 'Absent')
            {
                $ReturnValue.Id | Should be 0
                $ReturnValue.State | Should be $State
            }
            else
            {
                $ReturnValue.Id | should not be 0
                $ReturnValue.State | Should be $CurrentState
            }
        }
    }
}

