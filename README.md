# Hipchat
Hipchat Management from PowerShell

Uses the SavedCredentials module to store the API toke. This was authored by https://github.com/mklement0


Functions
    
    Get-AllHipChatRooms
    	.SYNOPSIS
		  Lookup All HipChat Rooms
    
    Get-RateLimit
 	    .SYNOPSIS
		  Lookup the Current HipChat Rate Limit
      Used by the script internally but can be run interactively too
    
    Get-AllHipChatUsers
      .SYNOPSIS
      Lookup all HipChat Users in the group   
        
    Get-HipChatUser
    	.SYNOPSIS
      Lookup a HipChat User 
    
    Get-HipChatGroup
     .SYNOPSIS
		  Lookup HipChat Server Group
   
    Resolve-HipChatID
      .SYNOPSIS
      Resolve the HipChat User ID from a listing and look it up   
        
    Send-IM
    	.SYNOPSIS
		  Send a notification message to a HipChat room
