# BEGIN Parameters
$ContainerName='compute_images';
$UserEmail='xxx@email.com'
$UserPass = 'password'
$IdentityDomain = 'youridentitydomainNAme'
$LocalFilePath='E:\Pictures'
$extension='*'
 
# END Parameters

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
 

$StorageAccountName='Storage-'+$IdentityDomain
$OracleApiUri='https://'+$IdentityDomain+'.eu.storage.oraclecloud.com/'
$AuthUri=$OracleApiUri+'auth/v1.0'
$StorageUri=$OracleApiUri+"v1/"+$StorageAccountName+'/'
$XStorageUser= $StorageAccountName+':'+$UserEmail
$AuthToken=''


function GetWebRequest($Uri, $get)
{
    $headers = @{}

    if($script:AuthToken -eq '')
    {
        (GetToken);
    }

    $headers["X-Auth-Token"] = $script:AuthToken;
    try
    {
        Write-Log -Level Info ("Invoke-WebRequest -Method "+ $get+" -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+ $Uri)
        $response = Invoke-WebRequest -Method $get -Headers $headers $Uri
        
        if($response.StatusCode -eq 200)
        {
            Write-Log -Level Info -Message ("Successfully executed.`t"+$response.StatusDescription +"`t"+$get+"`t"+$Uri)
            return $response
        }
        elseif($response.StatusCode -eq 401){
            Write-Log -Level Info -Message "Token has been expired"
            Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
            (GetToken);
            return (GetWebRequest $Uri $get)
        }
		elseif($response.StatusCode -eq 404){
            Write-Log -Level Error -Message "There is no object in there. Not Found"
			Write-Log -Level Info -Message $response.StatusDescription+$Uri+" "+$get
            return $null
        }
        else
        {
            Write-Log -Level Info -Message "For Status Codes: https://docs.oracle.com/en/cloud/iaas/storage-cloud/ssapi/Status%20Codes.html"
            Write-Log -Level Error -Message ($response.StatusDescription+$Uri+" "+$get)
            Write-Host "ERROR GetWebRequest else block";
        }
    }
    catch
    {
        Write-Host $_.Exception.Message
        Write-Log -Level Error -Message $get+"`t"+ $Uri+"`t"+ $_.Exception.Message
    }
}

function GetToken
{  
    $headers_ = @{}
    $headers_["X-Storage-User"] = $XStorageUser
    $headers_["X-Storage-Pass"] = $UserPass
    Write-Log -Level Info -Message "Getting new Token"
    $script:AuthToken = (Invoke-WebRequest -Method GET -Headers $headers_ $AuthUri).Headers["X-Auth-Token"].ToString();
    Write-Log -Level Info -Message $("New Token's value is "+ ($script:AuthToken))
}

function GetCloudFileMetaData($fileName,$cName=$ContainerName)
{
    Write-Log -Level Info -Message "Getting "+$fileName +"'s metadata from cloud"
    return   CheckGetData((GetWebRequest ($StorageUri+$cName+'/'+$fileName) Head))
}

function ListCloudFiles($cName=$ContainerName)
{
     Write-Log -Level Info -Message "Getting file list from cloud"
	 return   CheckGetData((GetWebRequest $StorageUri$cName  Get))
}

function CheckGetData($result){
 if($result -ne $null -and [bool]($result.PSobject.Properties.name -match "Content")){
		return  $result.Content.Split("`r`n")
	 }
}

function ListContainers()
{
    return  CheckGetData((GetWebRequest $OracleApiUri'v1/'$StorageAccountName"?limit=15"  Get))
}

function UploadFile($localfile, $cName=$ContainerName)
{
    $ssUri= ($StorageUri+$cName+'/'+($_.Name))

    Write-Log -Level Info -Message" Starting to upload "+$fileName +"'to cloud"
    Write-Log -Level Info -Message" Invoke-WebRequest -Method Put -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+  ($StorageUri+$cName+'/'+($_.Name))+" -Infile"+ $localfile
    $response = Invoke-WebRequest -Headers $headers -Method Put -uri $ssUri -Infile $localfile

    Write-Host ($response)
    Write-Host $response.Content
    if($response.StatusCode -eq 200)
    {
        Write-Log -Level Info -Message " File successfully uploaded.`t"+($response.StatusDescription)+"`tPUT`t"+($StorageUri+$cName+'/'+($_.Name))
        return $response
    }
    else
    {
        Write-Log -Level Error -Message "Error occured while file uploading"
    }
}

# DO NOT USE THIS METHOD
function DeleteFileFromFileSystem($fileName,$cName=$ContainerName)
{
    Write-Log -Level Info -Message" Deleting this file "+$fileName +"'from cloud"
    #Write-Host (GetWebRequest ($StorageUri+'/'+$fileName) Delete)
    #return (GetWebRequest ($StorageUri+'/'+$fileName) Delete).Content 

    Write-Host (GetWebRequest ($StorageUri+$cName+'/'+$fileName)  Delete).Content 
}

function UploadAll()
{
    $errorFlag=0;
    $i=1;
    $fileCount = ( Get-ChildItem $LocalFilePath -Filter $extension | Measure-Object ).Count;

    $files = Get-ChildItem $LocalFilePath -Filter $extension | sort LastWriteTimeUtc -Descending |

                                                                                                                                                            Foreach-Object {
    Write-Progress -Activity "Propce files" -status "Processing File(s) $i of $fileCount" -percentComplete ($i / ($fileCount)*100)
    $cloudFile= (GetCloudFileMetaData $_.Name)
 
    #there is a file with same name on the cloud
    if($cloudFile)
    {
        #these files length are same
        if($cloudFile.Headers["Content-Length"] -ne $_.Length)        
        {   
            Write-Log -Level Info -Message ("Content Lengths are not proper for "+($_.Name)+" "+$cloudFile.Headers["Content-Length"] +" <> "+$_.Length)
            $errorFlag=1
        }

        #as we expect the date of these files
        if([datetime]$cloudFile.Headers["Last-Modified"] -lt $_.LastWriteTimeUtc)
        {
            Write-Log -Level Info -Message ("Last-Modified/LastWriteTimeUtc are not proper for "+($_.Name)+" "+$cloudFile.Headers["Last-Modified"]+" <= "+ $_.LastWriteTimeUtc)
            $errorFlag=1
        }

        if($errorFlag -eq 0)
        {
            Write-Log -Level Info -Message ("By-passing file already has on the cloud "+($_.Name));
        }
    }
    else
    {
        if($errorFlag -eq 0)
        {
            Write-Log -Level Info -Message ("Uploading.... "+($_.Name))
            UploadFile $_.FullName 
        }
    }

    if($errorFlag -eq 1)
    {
        Write-Host "Houston we have a problem :)"
        break;
    }

    $i=$i+1;
  
    }

}
 
ListContainers





