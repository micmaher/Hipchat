function Get-RateLimit{

<#
	.SYNOPSIS
		Lookup the Current HipChat Rate Limit 

	.DESCRIPTION
		500 API requests per 5 minutes. Once you exceed the limit, calls will return HTTP status 429

	.EXAMPLE
        Get-RateLimit 
        Defaults to administrator@company.com

	.NOTES
		https://developer.atlassian.com/hipchat/guide/hipchat-rest-api/api-rate-limits
#>

	[CmdletBinding()]
	param()

        Write-Verbose "Decrypt the password"
        $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
        $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 

		# Set the Header Variable
		$headers = $(@{
			"Authorization" = "Bearer $($Token)"
			"Content-type" = "application/json"
		})


        # Check Rate Limit Remaining
        $UserID  = 'administrator@company.com'
        $uri = "https://hipchat.company.com/v2/user/" + $UserID
        $webResponse = Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing
        Return $($webResponse.Headers.'X-Ratelimit-Remaining')
        Write-Verbose "Status Code: $($webResponse.StatusCode)"
        Write-Verbose "Status Description: $($webResponse.Description)"
}

function Get-AllHipChatRooms {
<#
	.SYNOPSIS
		Lookup All HipChat Rooms

	.DESCRIPTION
		Returns Room name, Privacy, Room ID

	.EXAMPLE
        Get-AllHipchatRooms
        
	.NOTES
		https://www.hipchat.com/docs/apiv2/method/view_room
        To get the first 1000 rooms, set max-results = 1000 and start-index = 0
        To get the next 1000 rooms (from 1000 to 2000), set max-results = 1000 and start-index = 1000 

#>

	[CmdletBinding()]
	param()

	BEGIN {	
            $rl = Get-RateLimit
            Write-Verbose "Rate limit is $rl"

            If ($rl -lt 10){
                Write-Warning "Rate Limit reached, pausing for 5 minutes"
                Start-Sleep -Seconds 300
            }

            Write-Verbose "Decrypt the password"
            $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
            $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
            
            # Used in Body passed to Hipchat API to control flow of results
            $index = 0
            $maxResults = 500

		    # Set the Header Variable
		    $headers = $(@{
			    "Authorization"   = "Bearer $($Token)"
		    })

		    # Method to use for the Rest Call
		    $method = "GET"
            $uri = "https://hipchat.company.com/v2/room?"
            }

	PROCESS {

    Do{

        Write-Verbose "Retrieving set of results from $index"

        $body = $(@{
            "start-index"     = $index
            "max-results"     = $maxResults
            "include-private" = "true"
            "Content-type"    = "application/json"
        })

        $lookup = Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $headers #-ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
    
        #Start-Sleep -Milliseconds 10
        Write-Verbose "Adding $($lookup.items.Count) objects to `$props"
    
        foreach ($l in $lookup.items){
        $props = @{
            'id'      = $l.id;
            'name'    = $l.name;
            'privacy' = $l.privacy
            }
            $obj += @(New-Object pscustomobject -Property $props)  
        }

    
        Write-Verbose "Now $($obj.Count) objects in the collection"
    
        # Check if loop should finish
        $index = $index + $lookup.items.count  
        If ($lookup.items.count -lt $maxResults){
            Write-Verbose "$($lookup.items.count) results returned is less than $maxResults, finishing loop"
            Write-Verbose "Total room count was $index"
            $index = 0
            return $obj
        }
    } While ($index -ne 0)   
            
	    }

}

function Get-AllHipChatUsers {
<#
	.SYNOPSIS
		Lookup a HipChat Users 

	.DESCRIPTION
		Lists all HipChat Users

	.EXAMPLE
        Get-AllHipchatUsers

	.NOTES
		https://www.hipchat.com/docs/apiv2/method/get_all_users
#>

	[CmdletBinding()]
	param
	()

	BEGIN {
        $rl = Get-RateLimit
        Write-Verbose "Rate limit is $rl"
        
        If ($rl -lt 10){
            Write-Warning "Rate Limit reached, pausing for 5 minutes"
            Start-Sleep -Seconds 300
        }
        
        Write-Verbose "Decrypt the password"
        $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
        $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
        
        # Used in Body passed to Hipchat API to control flow of results
        $index = 0
        $maxResults = 500
    }

	PROCESS {
		# Set the Header Variable
		$headers = $(@{
			"Authorization" = "Bearer $($Token)"
			"Content-type" = "application/json"
		})

		# Set the URI Variable based on the Atlassian HipChat API V2 documentation
		$uri = "https://hipchat.company.com/v2/user"
        Write-Verbose "The URI is $uri"

		# Method to use for the Rest Call
		$method = "GET"



        Do{

            Write-Verbose "Retrieving set of results from $index"

            $body = $(@{
                "start-index"     = $index
                "max-results"     = $maxResults
                "include-private" = "true"
                "Content-type"    = "application/json"
            })

            $lookup = Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $headers -ErrorAction:Stop -WarningAction:Inquire
            #$lookup.items.mention_name
            Write-Verbose "Found $($lookup.items.mention_name.count)"
    
            #Start-Sleep -Milliseconds 10
            Write-Verbose "Adding $($lookup.items.Count) objects to `$props"
    
            foreach ($l in $lookup.items){
            $props = @{
                'mention_name'      = $l.mention_name;
                'name'    = $l.name;
                'id' = $l.id
                }
                $obj += @(New-Object pscustomobject -Property $props)  
            }

    
            Write-Verbose "Now $($obj.Count) objects in the collection"
    
            # Check if loop should finish
            $index = $index + $lookup.items.count  
            If ($lookup.items.count -lt $maxResults){
                Write-Verbose "$($lookup.items.count) results returned is less than $maxResults, finishing loop"
                Write-Verbose "Total room count was $index"
                $index = 0
                return $obj
            }
        } While ($index -ne 0)   

	}

	END {}
}

function Get-HipChatUser {
<#
	.SYNOPSIS
		Lookup a HipChat User 

	.DESCRIPTION
		Find the email given the userid. Useful for tracking who uploaded a large attachment

	.PARAMETER UserID
		The UserID to lookup

	.EXAMPLE
        Get-HipchatUser 277

    .EXAMPLE
        Get-HipchatUser administrator@company.com

	.NOTES
		https://www.hipchat.com/docs/apiv2/method/view_user

        HipChat atatchments contain the User ID 
        /file_store/cumulus/posixdata/f/tmpoSF40Pfiles__1__277__MggVgcg2ZQ5ILVC__Endpoint Security Installer.app.zip
        This can be resolved with the Resolve-HipchatID function
        Then look it up
#>

	[CmdletBinding()]
	param
	(
		[Parameter(
            HelpMessage = 'HipChat User ID to look up',
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
		[Alias('User')]
		[string]
		$UserID
	)

	BEGIN {	

            Write-Verbose "Decrypt the password"
            $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
            $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
                  
            # Set the URI Variable based on the Atlassian HipChat API V2 documentation
            Write-Verbose "Looking up $UserID"

		    # Set the Header Variable
		    $headers = $(@{
			    "Authorization" = "Bearer $($Token)"
			    "Content-type" = "application/json"
		    })

		    # Method to use for the Rest Call
		    $method = "GET"
            }

	PROCESS {
            $uri = "https://hipchat.company.com/v2/user/" + $UserID
            Write-Verbose "The URI is $uri"

		    try {
			        $lookup = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
                    Write-Verbose "Response is $lookup"
                    $hcresults += $lookup.last_active + "," + $UserID
                    Write-Output $hcresults
                } 
            catch {
                    Write-Warning "$UserID not returned"			
                    Write-Verbose "Returned from server: $lookup"
                    $hcresults += "Not Found, Not Found," + $UserID
                    If ($lookup){Clear-Variable lookup}
                    If ($userID){Clear-Variable UserID}
		        }
	    }

}

function Get-HipChatGroup {
<#
	.SYNOPSIS
		Lookup HipChat Server Group

	.DESCRIPTION
		Find the email given the userid. Useful for tracking who uploaded a large attachment
        

	.EXAMPLE
        Get-HipchatGroup
        
	.NOTES
		Login to https://hipchat.company.com/account/api and create one
        Test with REST client at https://hipchat.company.com/v2/group/1?format=json&auth_token=$token
#>

	[CmdletBinding()]
	param()

	BEGIN {	

            
            Write-Verbose "Decrypt the password"
            $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
            $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
            

		    # Set the Header Variable
		    $headers = $(@{
			    "Authorization"   = "Bearer $($Token)"
			    "Content-type"    = "application/json"
		    })

		    # Method to use for the Rest Call
		    $method = "GET"
       
            }

	PROCESS {

            $uri = "https://hipchat.company.com/v2/group/1/statistics?"
            Write-Verbose "The URI is $uri"

		    try {
			        $lookup = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
                    Write-Verbose "Response is $lookup"
                    Write-Verbose "Found $($lookup.users) users"
                    Return $lookup.users
                   
                } 
            catch {
                    Write-Verbose "Returned from server: $lookup"
		        }
	    }

    }
    
function Resolve-HipChatID{

<#
	.SYNOPSIS
		Resolve the HipChat User ID from a listing and look it up

	.DESCRIPTION
		Find the email given the userid. Useful for tracking who uploaded a large attachment

	.PARAMETER Path
		Location of file to parse

	.EXAMPLE
        Resolve-HipChatID -Path 'c:\temp\1.txt'

	.NOTES
        HipChat atatchments contain the User ID: /file_store/cumulus/posixdata/f/tmpoSF40Pfiles__1__277__MggVgcg2ZQ5ILVC__Endpoint Security Installer.app.zip
        This user id can be Resolved with the Resolve-HipchatID function
        Then look it up with the Get-HipchatUser function
#>

	[CmdletBinding()]
	param
	(
		[Parameter(HelpMessage = 'Supply the path to an input file')]
		[string]
		$Path
	)

        $id= Get-Content $path

        # Looking for __1__ which preceeds UserID, removing it and leaving (d is digit and 1,4 is the length to expect)

        $pattern = '__1__\d{1,4}' 

        # For example takes /file_store/cumulus/posixdata/f/tmpoSF40Pfiles__1__277__MggVgcg2ZQ5ILVC__Endpoint.zip and turns it into 277        
        $bareID = foreach ($m in $id){
             if ($m -match $pattern) { $matches[0] -replace '__1__'}
        }

        # Work within rate limit of 500 API requests per 5 minutes. Stay just below 100 a batch to be safe
        $counter = @{ Value = 0 }
        $groupSize = 90

        # Group them into batches of $groupSize
        $groups = $bareID | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) } 
                
        foreach ($group in $groups)
        {
            Write-Verbose "Working on batch $($group.Name)"
            $batch = $group.Group
            
            # $Batch.Count will be somewhere between 1 and 100.  (The final group may have less than 100.)
            Write-Verbose "$($batch.count) UserIDs in this batch"

            # Generate your $converted string here and call Invoke-RestMethod.
            $batch| Get-HipChatUser

            # Sleep for 65 seconds
            Start-Sleep 65
        }    

}

function Send-IM {
<#
	.SYNOPSIS
		Send a notification message to a HipChat room
        This requires a Hipchat API token which is saved using the SavedCredentials module

	.DESCRIPTION
		Send a notification message to a HipChat room using a REST API Call to the HipChat API V2 of Atlassian

	.PARAMETER Room
		HipChat Room Name that get the notification. The Token must have erm

	.PARAMETER Notify
		Whether this message should trigger a user notification (change the tab color, play a sound, notify mobile phones, etc).
		Each recipient's notification preferences are taken into account.

	.PARAMETER color
		Background color for message. Valid is 'yellow', 'green', 'red', 'purple', 'gray', 'random'

	.PARAMETER Message
		The message body itself. Please see the HipChat API V2 documentation
		https://www.hipchat.com/docs/apiv2/method/send_room_notification

	.PARAMETER Format
		Determines how the message is treated by the server and rendered inside HipChat applications

	.PARAMETER From
		A label to be shown in addition to the sender's name

	.EXAMPLE
		PS C:\> Send-IM -Message "This is just a BuildServer Test" -color "gray" -Room "DevOps" -notify $true

		Sent a HipChat Room notification "This is just a BuildServer Test" to the Room "DevOps".
		It uses the Color "gray", and it sends a Notification to all users in the room.
		It uses a default Token to do so!

	.NOTES
		https://www.hipchat.com/docs/apiv2/method/send_room_notification
#>

	[CmdletBinding()]
	param
	(

		$Room = "Testing",
		[Parameter(HelpMessage = 'Whether this message should trigger a user notification.')]
		[boolean]
		$Notify = $false,
		[Parameter(HelpMessage = 'Background color for message.')]
		[ValidateSet('yellow', 'green', 'red', 'purple', 'gray', 'random', IgnoreCase = $true)]
		[string]
		$Color = 'gray',
		[Parameter(HelpMessage = 'The message body: 10000 character limit')]
		[ValidateNotNullOrEmpty()]
		[string]
		$Message,
		[Parameter(HelpMessage = 'Determines how the message is treated by our server and rendered inside HipChat applications')]
		[ValidateSet('html', 'text', IgnoreCase = $true)]
		[string]
		$Format = 'text'
	)

	BEGIN {	
        Write-Verbose "Decrypt the password"
        $kHipchatPassEncrypt = (Get-SavedCredential 'HipChatAdmin' -Context 'Hipchat') 
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kHipchatPassEncrypt.Password)
        $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
        }

	PROCESS {
		# Set the Header Variable
		$headers = $(@{
			"Authorization" = "Bearer $($Token)"
			"Content-type" = "application/json"
		})

		# Set the Body Variable, will be converted to JSON
		$body = $(@{
			"color" = "$color"
			"message_format" = "$Format"
			"message" = "$Message"
			"notify" = "$notify"
            "title" = "$title"
            "from" = "$from" 
		})

		# Convert the Body Variable to JSON
		$JSONbody = (ConvertTo-Json $body)

        $uri = "https://hipchat.company.com/v2/room/" + $Room + "/notification"


		# Method to use for the Rest Call
		$method = "POST"

		# Fire up the Rest Call
		try {
			$post = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $JSONbody -ErrorAction:Stop -WarningAction:Inquire
		} catch {
			Write-Warning -message "Could not send notification to your HipChat Room $Room"
		}
	}

	END {
	}
}
