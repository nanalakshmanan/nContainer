$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"


#region Helper functions
function Init-ContainerImage
{
    $global:ContainerImages = @{}
    $global:ContainerImages += @{PresentPresent = @{Name = 'PresentPresent';ContainerName = 'TestContainer';Publisher = "CN=Microsoft" ; Version = '1.0.0.0'; FullName = 'CN=Microsoft_PresentPresent'}}
    $global:ContainerImages += @{AbsentPresent = @{Name = 'AbsentPresent';ContainerName = 'TestContainer';Publisher = "CN=Microsoft" ; Version = '1.0.0.0'; FullName = 'CN=Microsoft_AbsentPresent'}}    
}
#endregion Helper function

Describe "nContainerImage UnitTests" {

# define the global variables
BeforeAll {
        # container images
        #$global:ContainerImages = @{}
        $ServerCoreImage = @{Name = 'WindowsServerCore';Publisher = 'CN=Microsoft'; IsOSImage = $true}
        $global:ContainerImages += @{$ServerCoreImage.Name = $ServerCoreImage}

        # container Image
        Init-ContainerImage
}

AfterAll {
    Remove-Variable -Name ContainerImages -Scope Global    
}

#region Mocks
        Mock -ModuleName nContainer -CommandName New-ContainerImage -MockWith {

            $ContainerImage = @{Name = $Name;ContainerName = $ContainerName;Publisher = $Publisher;Version=$Version}
            $global:ContainerImages += @{$Name = $ContainerImage }
            $MockObject = New-Object psobject -Property $Value
            $MockObject.PSTypeNames[0] = 'Microsoft.Containers.PowerShell.Objects.ContainerImage'

            $MockObject
        }

        Mock -ModuleName nContainer -CommandName Get-ContainerImage -MockWith {

            [CmdletBinding()]
            param([string[]]$Name)
            $RetValue = @()

            $Name | % {
                if ($global:ContainerImages.ContainsKey($_))
                {
                    $Value = $global:ContainerImages[$_]
                    $MockObject = New-Object psobject -Property $Value
                    $MockObject.PSTypeNames[0] = 'Microsoft.Containers.PowerShell.Objects.ContainerImage'
                    $RetValue += $MockObject
                }
                else
                {
                    Write-Error "Container Image $($_) not found"
                }
            }

            if ($RetValue.Count -gt 0)
            {
                return $RetValue
            }
        }

        Mock -ModuleName nContainer -CommandName Remove-ContainerImage -MockWith {
            $Name | % {
                if ($global:ContainerImages.ContainsKey($_))
                {
                    $global:ContainerImages.Remove($_)
                }
            }
        }

        Mock -ModuleName nContainer -CommandName Test-ContainerImage -MockWith {
            $Name | % {
                if ($global:ContainerImages.ContainsKey($_))
                {
                    return $true
                }
            }
        }

#endregion Mocks

    Context "Test methods tests" {

        $TestCases = @()

        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                $ExpectedResult = $false

                if ($Ensure -eq $Actual)
                {
                    $ExpectedResult = $true                    
                }
                        
                $TestCases += @{Ensure = $Ensure;Actual = $Actual; ExpectedResult = $ExpectedResult}                
            }
        }
        

        It 'Test() : Ensure : <Ensure>, Actual : <Actual>' -TestCases $TestCases {
            param( $Ensure, $Actual, $ExpectedResult)

            $ContainerImage = New-nContainerImage
            $ContainerImage.Name = ($Actual + $Actual).Trim()
            $ContainerImage.Ensure = $Ensure
            $ContainerImage.ContainerName = 'TestContainer'
            $ContainerImage.Publisher = 'CN=Microsoft'
            $ContainerImage.Version = '1.0.0.0'

            $ContainerImage.Test() | Should Be $ExpectedResult
        }
    }  

    Context "Get method tests" {
        
        $Testcases = @()
        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                $Testcases += @{Ensure = $Ensure; Actual = $Actual}
            }
        }

        BeforeEach {Init-ContainerImage}

        It 'Get(): Ensure : <Ensure>, Actual : <Actual>' -TestCases $Testcases {

                    param( $Ensure, $Actual)

            if ($Actual -eq 'Absent')
            {
                $Global:ContainerImages = @{}
            }

            $ContainerImage = New-nContainerImage
            $Name = ($Ensure+$Actual).Trim()
            $ContainerImage.Name = $Name            
            $ContainerImage.Ensure = $Ensure
            $ContainerImage.Publisher = 'CN=Microsoft'
            $ContainerImage.Version = '1.0.0.0'

            $ReturnValue = $ContainerImage.Get()
            
            $ReturnValue.Name | Should be $Name
            $ReturnValue.Publisher | Should be 'CN=Microsoft'
            $ReturnValue.Version | Should be '1.0.0.0'

            if ($Actual -eq 'Absent')
            {
                $ReturnValue.IsOSImage | Should be 'false'
                $ReturnValue.IsDeleted | Should be 'false'                
            }            
        }
    }

    Context "Set method tests" {

        $TestCases = @()

        foreach($Ensure in @('Present', 'Absent'))
        {
            foreach($Actual in @('Present', 'Absent'))
            {
                $SetCalled = $true

                if ($Ensure -eq $Actual)
                {
                    $SetCalled = $false
                }                                          
                if ($SetCalled)
                {
                    $TestCases += @{Ensure = $Ensure;Actual = $Actual}
                }                                    
            }
        }

        BeforeEach {Init-ContainerImage}
        It 'Set() : Ensure : <Ensure>, Actual : <Actual>' -TestCases $TestCases {

            param( $Ensure, $Actual)

            if ($Actual -eq 'Absent')
            {
                $Global:ContainerImages = @{}
            }

            $ContainerImage = New-nContainerImage
            $ContainerImage.Name = ($Ensure + $Actual).Trim()
            $ContainerImage.Ensure = $Ensure
            $ContainerImage.Publisher = 'CN=Microsoft'
            $ContainerImage.Version = '1.0.0.0'
            $ContainerImage.ContainerName = 'TestContainer'

            $ContainerImage.Set()

            if ($Ensure -eq 'Absent')
            {
                if ($Actual -eq 'Present')
                {
                    Assert-MockCalled -CommandName Remove-ContainerImage -Exactly 1 -Scope It -ModuleName nContainer
                    Assert-MockCalled -CommandName New-ContainerImage    -Exactly 0 -Scope It -ModuleName nContainer                    
                }
            }
            else
            {
                Assert-MockCalled -CommandName Remove-ContainerImage -Exactly 0 -Scope It -ModuleName nContainer
                Assert-MockCalled -CommandName New-ContainerImage    -Exactly 1 -Scope It -ModuleName nContainer                    
            }

        }
        
    }
}

