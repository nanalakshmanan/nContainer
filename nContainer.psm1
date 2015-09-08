enum Ensure
{
    Present
    Absent
}

enum State
{
    Running
    Off
}

[DscResource()]
class nContainer
{

#region Hidden Members

    hidden [object] $Container

#endregion

#region DSC properties

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [string]$ImageName

    [DscProperty(Mandatory)]
    [string]$VirtualSwitchName

    [DscProperty(NotConfigurable)]
    [int]$Id

    [DscProperty()]
    [State]$State = 'Running'

    [DscProperty()]
    [Ensure]$Ensure = 'Present'

#endregion

#region DSC Methods
    [bool] Test()
    {
        $this.AssertImageAvailable()
        $this.AssertSwitchAvailable()

        [Collections.ArrayList]$ev = $null

        $this.Container = Get-Container -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        # should be present, but not present
        if (($this.Ensure -eq 'Present') -and ($ev -ne $null))
        {
            return $false
        }

        # should be absent
        if ($this.Ensure -eq 'Absent') 
        {
            # but present
            if ($ev.Count -eq 0)
            {
                return $false
            }
            # and absent
            else
            {
                return $true
            }
        }

        # at this point, Ensure is present and container is present
        # compare state
        if (($this.State -eq 'Running') -and ($this.Container.State -ne 'Running') )
        {
            # should be Running, but state isn't running
            return $false
        }
        elseif (($this.State -eq 'Off') -and ($this.Container.State -ne 'Off'))
        {
            # should be off, but state isn't of
            return $false
        }

        return $true
    }

    [void] Set()
    {
        [Collections.ArrayList]$ev = $null

        $this.Container = Get-Container -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        # if container should be absent, remove if it already exists
        if ($this.Ensure -eq 'Absent')
        {
            if ($this.Container -eq $null)
            {
                return
            }

            # For absent case the control has reached this point since
            # the container exists, so object cannot be null
            if ($this.Container.State -eq 'Running')
            {
                Write-Verbose "Stopping container $($this.Name)"
                Stop-Container -Name $this.Name
            }

            Write-Verbose "Removing container $($this.Name)"
            Remove-Container -Name $this.Name

            return
        }


        # Container object being null implies that it does not exist
        if ($this.Container -eq $null)
        {
            $ContainerImage = Get-ContainerImage -Name $this.ImageName

            Write-Verbose "Creating new container $($this.Name) using container image $($this.ImageName)"
            $this.Container = New-Container -Name $this.Name -ContainerImage $ContainerImage -SwitchName $this.VirtualSwitchName
        }

        # If container is not in the desired state, make it so
        if (($this.Container.State -eq 'Off') -and ($this.State -eq 'Running'))
        {
            Write-Verbose "Starting container $($this.Name)"
            Start-Container -Name $this.Name
        }
        elseif (($this.Container.State -eq 'Running') -and ($this.State -eq 'Off'))
        {
            Write-Verbose "Stopping container $($this.Name)"
            Stop-Container -Name $this.Name 
        }
    }

    [nContainer] Get()
    {
        $ev = $null
       
        $this.Container = Get-Container -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        if ($ev -ne $null)
        {
            return @{
                Name              = $this.Name;
                State             = $this.State;
                ImageName         = $this.ImageName;
                Id                = 0;
                VirtualSwitchName = $this.VirtualSwitchName;
            }
        }

        return @{
                Name              = $this.Name;
                State             = $this.Container.State;
                ImageName         = $this.ImageName;
                Id                = $this.Container.ContainerId;
                VirtualSwitchName = $this.VirtualSwitchName;
        }
        
    }

#endregion

#region Helper Methods

[void] AssertImageAvailable()
{
    [Collections.ArrayList]$ev = $Null

    [array]$ContainerImage = Get-ContainerImage -Name $this.ImageName -ErrorAction SilentlyContinue -ErrorVariable ev 

    if ($ContainerImage.Count -eq 0)
    {
        throw "Specified Image $($this.ImageName) is not available"
    }
}

[void] AssertSwitchAvailable()
{
    [Collections.ArrayList]$ev = $null

    Get-VMSwitch -Name $this.VirtualSwitchName -ErrorAction SilentlyContinue -ErrorVariable ev

    if ($ev.Count -ne 0)
    {
        throw "Specified switch $($this.VirtualSwitchName) is not available"
    }
}

#endregion

}

function New-nContainer
{
    [nContainer]::new()
}


[DscResource()]
class nContainerImage
{

#region Hidden Members

    hidden [object] $ContainerImage

#endregion

#region DSC properties

    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [string]$ContainerName

    [DscProperty(Mandatory)]
    [string]$Publisher

    [DscProperty(Mandatory)]
    [string]$Version

    [DscProperty(NotConfigurable)]
    [bool]$IsDeleted

    [DscProperty(NotConfigurable)]
    [bool]$IsOSImage

    [DscProperty(NotConfigurable)]
    [Microsoft.Containers.PowerShell.Objects.ContainerImage]$ParentImage

    [DscProperty(NotConfigurable)]
    [string]$FullName

    [DscProperty()]
    [Ensure]$Ensure = 'Present'

#endregion

#region DSC Methods
    [bool] Test()
    {
        [Collections.ArrayList]$ev = $null

        $this.ContainerImage = Test-ContainerImage -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        # should be present, but not present
        if (($this.Ensure -eq 'Present') -and ($this.ContainerImage -eq $null))
        {
            return $false
        }

        # should be absent
        if ($this.Ensure -eq 'Absent') 
        {
            # but present
            if ($this.ContainerImage -ne $null)
            {
                return $false
            }
            # and absent
            else
            {
                return $true
            }
        }
        
        return $true
    }

    [void] Set()
    {
        [Collections.ArrayList]$ev = $null

        $this.ContainerImage = Get-ContainerImage -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        # if container should be absent, remove if it already exists
        if ($this.Ensure -eq 'Absent')
        {
            if ($this.ContainerImage -eq $null)
            {
                return
            }

            Write-Verbose "Removing container image $($this.Name)"
            Remove-ContainerImage -Name $this.Name

            return
        }


        # Container object being null implies that it does not exist
        if ($this.ContainerImage -eq $null)
        {
            Write-Verbose "Creating new container image $($this.Name)"
            $this.ContainerImage = New-ContainerImage -Name $this.Name -ContainerName $this.ContainerName -Publisher $this.Publisher -Version $this.Version
        }
        
    }

    [nContainerImage] Get()
    {
        $ev = $null
       
        $this.ContainerImage = Get-ContainerImage -Name $this.Name -ErrorAction SilentlyContinue -ErrorVariable ev

        $result = @{
            Name             = $this.Name;
        }


        if ($ev -ne $null)
        {
            $result.Add("Publisher",$this.Publisher);
            $result.Add("Version",$this.Version);            
        }
        else
        {   
            $result.Add("Publisher", $this.ContainerImage.Publisher);
            $result.Add("Version", $this.ContainerImage.Version);
            $result.Add("ParentImage", $this.ContainerImage.ParentImage);
            $result.Add("IsDeleted", $this.ContainerImage.IsDeleted);
            $result.Add("IsOSImage", $this.ContainerImage.IsOSImage);
            $result.Add("FullName", $this.ContainerImage.FullName);
            
        }

        return $result
        
    }

#endregion

}

function New-nContainerImage
{
    [nContainerImage]::new()
}


