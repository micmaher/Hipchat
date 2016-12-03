<#

Functions for saving (caching) credentials (passwords)
in a folder in the current user's home folder, encrypted in a 
user- and machine-specific way.

Files are stored in subfolders of ~\.credentials.
To remove all saved credentials at once, use Remove-SavedCredential -All
or manually delete said folder.       

#>

#region HELPER FUNCTIONS

function get-SavedCredentialRootFolder {
  Join-Path $HOME '.credentials'
}

function get-SavedCredentialContextFolder {
  param([string] $Context, [switch] $EnsureExistence)
  $path = Join-Path (get-SavedCredentialRootFolder) $Context
  if ($EnsureExistence) { $null = New-Item -Force -Type Directory $path }
  return $path
}

function get-SavedCredentialFile {
  param([string] $Context, [string] $UserName)
  return Join-Path (get-SavedCredentialContextFolder $Context) $UserName
}

#endregion

function Set-SavedCredential {
<#
.SYNOPSIS
    Saves credentials for later reuse, encrypted in a user- and machine-specific
    manner.

.DESCRIPTION
    The password is invariably prompted for using Get-Credential.

    Returns the saved credentials (a [pscredential] instance), unless
    the user canceled the password-entry dialog, in which case $null is retured.

.EXAMPLE
    Save credentials for admin-pstasks use. 

    1. First remote in as administrator

        PS C:> New-PSSession -ComputerName files01 -Credential 'domain\administrator'

         Id Name            ComputerName    State         ConfigurationName     Availability
         -- ----            ------------    -----         -----------------     ------------
          3 Session3        computer-01      Opened        Microsoft.PowerShell     Available

    
    2. Next install the module

        PS C:> Install-Package savedcredentials -source corpit

        Name                           Version          Source                         Summary
        ----                           -------          ------                         -------
        SavedCredentials               1.0.0            IT                             Save encrypted password


    3. Import the module
        
        PS C:\> Import-Module savedCredentials

    
    4. Saving the credentials for a Windows server using the domain account admin-pstasks and establish a (temporary) drive mapping with the credentials.

        PS C:\> Set-SavedCredential -UserName admininsitrator -VerificationCommand { new-psdrive T filesystem '\\files01\c$' -Credential $args[0] } -Verbose

        Verifying...
        VERBOSE: Credentials for user 'administrator' in context 'Windows' saved to: C:\Users\administrator\.credentials\Windows\admin

        UserName                          Password
        --------                          --------
        admin         System.Security.SecureString

.EXAMPLE
    Saving a login for a non-Windows machine. 
    The Context parameter is important because there will be multiple machines using the credentials file for 'root' or 'admin'

        C:\> Set-SavedCredential -UserName 'admin' -Context 'HipChat' -Verbose

        VERBOSE: Verification was not performed, because no verification command was passed.
        VERBOSE: Credentials for HipChat user 'admin' in context 'HipChat' saved to: C:\Users\administrator\.credentials\HipChat\admin

        UserName                     Password
        --------                     --------
        admin    System.Security.SecureString



#>
  [CmdletBinding(PositionalBinding=$false)]
  param(
    [Parameter(Position=0)]
    [String] $UserName = "$env:USERDOMAIN\$env:USERNAME"
    ,
    [Parameter(Position=1)]
    [String] $Context = 'Windows'
    ,
    [ScriptBlock] $VerificationCommand
    ,
    [string] $Prompt = "Enter the credentials to cache in context '${Context}':"
  )

  $ErrorActionPreference = 'Stop'

  $pass = 0
  do {
    if ($pass++) { Write-Warning "Credential verification failed. Please try again." }
    $cred = Get-Credential -UserName $UserName -Message $Prompt
    # If no password was entered, abort.
    if (-not $cred -or '' -eq $cred.GetNetworkCredential().Password) { return $null }
    if (-not $VerificationCommand) { 
      Write-Verbose "Verification was not performed, because no verification command was passed."
      break # No verification - we're done.
    }
  } while (-not $(Write-Host "Verifying..."; & $VerificationCommand $cred)) # Prompt until the verification command succeeds.

  # Make sure the target folder exists.
  $baseFolder = get-SavedCredentialContextFolder -EnsureExistence $Context

  # If the username contains a domain-name part - e.g., us\jdoe, we must also
  # create a domain-specific subfolder.
  if ($UserName -match '^(.+)\\.') {
    $null = mkdir -Force (Join-Path $baseFolder $matches[1])
  }

  # Encrypt the secure string in a user- and machine-specific manner and save to a file.
  $file = get-SavedCredentialFile $Context $UserName
  ConvertFrom-SecureString $cred.Password | Out-File $file

  Write-Verbose "Credentials for user '$UserName' in context '$Context' saved to: $file"

  return $cred
}

function Get-SavedCredential {
<#
.SYNOPSIS
Retrieves credentials previously saved with Set-SavedCredential

.DESCRIPTION
Defaults to context 'Windows' and the current user's username prefixed
by the logon domain.

#>
  [CmdletBinding(PositionalBinding=$false)]
  param(
    [Parameter(Position=0)]
    [String] $UserName = "$env:USERDOMAIN\$env:USERNAME",
    [Parameter(Position=1)]
    [String] $Context = 'Windows'
  )

  $file = get-SavedCredentialFile -Context $Context -UserName $UserName
  if (-not (Test-Path $file)) {
    Throw "No saved credentials found for user '$UserName' in context '$Context'. Use Set-SavedCredential to create them."
  }

  return New-Object PSCredential $UserName, (Get-Content $file | ConvertTo-SecureString)

}

function Remove-SavedCredential {
<#
.SYNOPSIS
Deletes the specified saved credentials, or all saved credentials, if -All
is specified.

.DESCRIPTION
Defaults to context 'Windows' and the current user's username prefixed
by the logon domain.

#>
  [CmdletBinding(DefaultParameterSetName='Individual', PositionalBinding=$false, ConfirmImpact='High', SupportsShouldProcess)]
  param(
    [Parameter(ParameterSetName='Individual', Position=0)]
    [String] $UserName = "$env:USERDOMAIN\$env:USERNAME"
    ,
    [Parameter(ParameterSetName='Individual', Position=1)]
    [String] $Context = 'Windows'
    ,
    [Parameter(ParameterSetName='RemoveAll')]
    [Switch] $All
  )

  switch ($PSCmdlet.ParameterSetName) {
    'RemoveAll' { 
      if (-not $All) { Write-Warning "Nothing to do; it only makes sense to use -All with (implied) $true."; return }
      $target = "ALL saved credentials - ENTIRE FOLDER $(get-SavedCredentialRootFolder) will be REMOVED"
    }
    Default {
      $target = "$UserName (context: $Context)"
    }
  }

  # Prompt for confirmation
  if (-not $PSCmdlet.ShouldProcess($target)) { return }

  if ($All) {
    # Simply remove the entire folder.
    Remove-Item -Recurse (get-SavedCredentialRootFolder)    
  } else {
    # Remove the specific files. 
    $file = get-SavedCredentialFile -Context $Context -Username $UserName
    if (-not (Test-Path $file)) {
      Write-Warning "Nothing to do: Credentials '$UserName', context '$Context', not found (file '$file' doesn't exist)."      
    } else {
      Remove-Item $file
    }
  }

}

#region EXPORTS
Export-ModuleMember Set-SavedCredential,
                    Get-SavedCredential,
                    Remove-SavedCredential
#endregion