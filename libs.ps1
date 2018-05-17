
<#
.Synopsis
   Write-Log writes a message to a specified log file with the current time stamp.
.DESCRIPTION
   The Write-Log function is designed to add logging capability to other scripts.
   In addition to writing output and/or verbose you can write to a log file for
   later debugging.
.NOTES
   Created by: Jason Wasser @wasserja
   Modified: 11/24/2015 09:30:19 AM  

   Changelog:
    * Code simplification and clarification - thanks to @juneb_get_help
    * Added documentation.
    * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
    * Revised the Force switch to work as it should - thanks to @JeffHicks

   To Do:
    * Add error handling if trying to create a log file in a inaccessible location.
    * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
      duplicates.
.PARAMETER Message
   Message is the content that you wish to add to the log file. 
.PARAMETER Path
   The path to the log file to which you would like to write. By default the function will 
   create the path and file if it does not exist. 
.PARAMETER Level
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
.PARAMETER NoClobber
   Use NoClobber if you do not wish to overwrite an existing file.
.EXAMPLE
   Write-Log -Message 'Log message' 
   Writes the message to c:\Logs\PowerShellLog.log.
.EXAMPLE
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
   Writes the content to the specified log file and creates the path and file specified. 
.EXAMPLE
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
.LINK
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
#>
function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path=$PSScriptRoot+'\PowerShellLog.log',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}
 
# we can use this function for better download speed
function Measure-DownloadSpeed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Please enter a URL to download.")]
        [string] $Url
        ,
        [Parameter(Mandatory = $true, HelpMessage = "Please enter a target path to download to.")]
        [string] $Path
    )

    function Get-ContentLength {
        [CmdletBinding()]
        param (
            [string] $Url
        )

        $Req = [System.Net.HttpWebRequest]::CreateHttp($Url);
        $Req.Headers.Add("X-Auth-Token",$script:AuthToken)
        $Req.Method = 'HEAD';
        $Req.Proxy = $null;
        $Response = $Req.GetResponse();
        #Write-Output -InputObject $Response.ContentLength;
        Write-Output -InputObject $Response;
    }

    $FileSize = (Get-ContentLength -Url $Url).ContentLength;

    if (!$FileSize) {
    throw 'Download URL is invalid!';
    }

    # Resolve the fully qualified path to the target file on the filesystem
    # $Path = Resolve-Path -Path $Path;

    if (Test-Path -Path $Path) {
    # throw ('File already exists: {0}' -f $Path);
    }

    # Instantiate a System.Net.WebClient object
    $wc = New-Object System.Net.WebClient;
    $wc.Headers.Add("X-Auth-Token",$script:AuthToken)

    # Invoke asynchronous download of the URL specified in the -Url parameter
    $wc.DownloadFileAsync($Url, $Path);

    # While the WebClient object is busy, continue calculating the download rate.
    # This could potentially be broken off into its own function, but hey there's procrastination for that.
    while ($wc.IsBusy) {
    # Get the current time & file size
    #$OldSize = (Get-Item -Path $TargetPath).Length;
    $OldSize = (New-Object -TypeName System.IO.FileInfo -ArgumentList $Path).Length;
    $OldTime = Get-Date;

    # Wait a second
    Start-Sleep -Seconds 1;

    # Get the new time & file size
    $NewSize = (New-Object -TypeName System.IO.FileInfo -ArgumentList $Path).Length;
    $NewTime = Get-Date;

    # Calculate time difference and file size.
    $SizeDiff = $NewSize - $OldSize;
    $TimeDiff = $NewTime - $OldTime;

    # Recalculate download rate based off of actual time difference since
    # we can't assume precisely 1 second time difference due to file IO.
    $UpdatedSize = $SizeDiff / $TimeDiff.TotalSeconds;

    # Write-Host -Object $TimeDiff.TotalSeconds, $SizeDiff, $UpdatedSize;

    Write-Host -Object ("Download speed is: {0:N2}MB/sec" -f ($UpdatedSize/1MB));

    }
}