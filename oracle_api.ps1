# BEGIN Parameters
$ContainerName='compute_images';
$UserEmail='xxx@email.com'
$UserPass = 'password'
$IdentityDomain = 'youridentitydomainNAme'
$LocalFilePath='E:\Pictures'
$extension='*'
# END Parameters

<#

.EXAMPLE
    ListContainers
    List of Containers
.EXAMPLE
    ListCloudFiles {Container Name}
    ListCloudFiles  _apaas
    Listing objects under the _apaas container
.EXAMPLE
    GetCloudFileMetaData {filename} {Container Name}
    GetCloudFileMetaData bootdisk.tar.gz compute_images
    Getting metadata for specific file under the specified container
.EXAMPLE
    ManifestFile {filename} {Container Name}
    ManifestFile Win2016x64.ISO compute_images
    Getting manifest info for specific file
.EXAMPLE
    DeleteFileFromCloud {filename} {Container Name} [optional {override y/n prompt }]
    DeleteFileFromCloud little_mix_wrong.jpg compute_images
    DeleteFileFromCloud little_mix_wrong.jpg compute_images $true --override prompt
.EXAMPLE 
    $fileList=ListCloudFiles compute_images
    foreach($file in $fileList)
    {
        DeleteFileFromCloud $file compute_images $true
    }
    Delete All files under the specific container 
.EXAMPLE
    UploadFile {your file path} {container}
    UploadFile "C:\Users\can.kaya\Downloads\abba.png" compute_images
#>

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
            Write-Log -Level Info -Message "No object found(s)"
			#Write-Log -Level Info -Message $response.StatusDescription $Uri " "$get
            return $null
        }
		elseif($response.StatusCode -eq 204){
			Write-Log -Level Info -Message "No object found(s)"
			return $response
		}
		
        else
        {
            Write-Log -Level Info -Message "For Status Codes: https://docs.oracle.com/en/cloud/iaas/storage-cloud/ssapi/Status%20Codes.html"
            Write-Log -Level Info -Message ("Status Code: "+$response.StatusDescription+" "+$Uri+" "+$get)
            Write-Log -Level Info -Message "ERROR GetWebRequest else block";
            return $null
        }
    }
    catch
    {
        Write-Log -Level Warn -Message ($_.Exception.Message)
        return $null;
    }
}


function GetToken
{  
    $headers_ = @{}
    $headers_["X-Storage-User"] = $XStorageUser
    $headers_["X-Storage-Pass"] = $UserPass
    $headers_["Content-Type"]= "text/plain;charset=UTF-8" 
    Write-Log -Level Info -Message "Getting new Token"
    $script:AuthToken = (Invoke-WebRequest -Method GET -Headers $headers_ $AuthUri).Headers["X-Auth-Token"].ToString();
    Write-Log -Level Info -Message $("New Token's value is "+ ($script:AuthToken))
}

function GetCloudFileMetaData($fileName,$cName=$ContainerName)
{
    Write-Log -Level Info -Message ("Getting "+$fileName +"'s metadata from cloud")
    return   CheckGetData((GetWebRequest ($StorageUri+$cName+'/'+$fileName) Head))
}

function ListCloudFiles($cName=$ContainerName)
{
     Write-Log -Level Info -Message "Getting file list from cloud"
	 return   CheckGetData((GetWebRequest $StorageUri$cName  Get))
}

function CheckGetData($result){
    if($result -ne $null -and [bool]($result.PSobject.Properties.name -match "RawContent")){
        if($result.Content.gettype().Name -eq 'String'){
            return  $result.Content.Split("`r`n");
        }elseif($result.Content.gettype().Name -eq 'Byte[]')
        {
            return $result.RawContent;
        }
	 }
}

function ListContainers()
{
    return  CheckGetData((GetWebRequest $OracleApiUri'v1/'$StorageAccountName"?limit=15"  Get))
}

function ManifestFile($remoteFile, $cName=$ContainerName)
{
    #You can't download objects that are larger than 10 MB using the web console. To download such objects, use the CLI or REST API.
    $ssUri= ($StorageUri+$cName+'/'+$remoteFile+"?multipart-manifest=get")
    Write-Host $ssUri
    Write-Log -Level Info -Message ("Starting to download "+$remoteFile +" from the cloud")
    $file = GetCloudFileMetaData $remoteFile $cName
    if($file.Contains("application/x-www-form-urlencoded;charset=UTF-8"))
    {
        #has manifestfile
        return CheckGetData((GetWebRequest $ssUri  Get))
    }
    else
    {
        Write-Log -Level Warn -Message (" "+$remoteFile +" doesn't have manifest file")
        return $null
    }
}

# DO NOT USE THIS METHOD
function DeleteFileFromCloud($fileName,$cName=$ContainerName, $overrideAllYes=$false)
{
    Write-Log -Level Warn -Message ("Script will delete this file "+$fileName+ " from cloud")
    if($overrideAllYes){
        $confirmation = "y";
    }else{
        $confirmation = Read-Host "Are you sure to delete this file? [y/n]"
    }
    
    if($confirmation -eq "y")
    {
        $result= (GetWebRequest ($StorageUri+$cName+'/'+$fileName)  Delete) 
        Write-Host $result 
        if($result.StatusCode -eq 204){
			Write-Log -Level Info -Message "File deletion succeeded"
			return $true;
		}else{
			Write-Log -Level Info -Message "Error! File couldnt delete"
			return $false;
		}
    }
    else
    {
        Write-Log -Level Info -Message ("Canceled")
        return $null;
    }
}

function UploadFile($localfile, $cName=$ContainerName)
{
    #TODO: We must consider replace the file which has already in there this method overrides now
    $toUploadFile = Get-ChildItem $localfile
    $ssUri= ($StorageUri+$cName+'/'+$toUploadFile.Name)
    GetToken
    $_headers = @{}
    $_headers["X-Auth-Token"] = $script:AuthToken;
    

    Write-Log -Level Info -Message (" Starting to upload "+$localfile +"'to cloud")
    #Write-Log -Level Info -Message (" Invoke-WebRequest -Method Put -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+  $ssUri+" -Infile"+ $localfile)
    $response = Invoke-WebRequest -Headers $_headers -Method Put -uri $ssUri -Infile $localfile

    $response 
    if($response.StatusCode -eq 201)
    {
        Write-Log -Level Info -Message (" File successfully uploaded.`t"+($response.StatusDescription)+"`tPUT`t"+($StorageUri+$cName+'/'+($toUploadFile.Name)))
        return $true;
    }
    else
    {
        Write-Log -Level Warn -Message "Error occured while file uploading"
		return $false;
    }
}

 



function UploadAll($cName=$ContainerName)
{
    $errorFlag=0;
    $i=1;
    $fileCount = ( Get-ChildItem $LocalFilePath -Filter $extension | Measure-Object ).Count;

    $files = Get-ChildItem $LocalFilePath -Filter $extension | sort LastWriteTimeUtc -Descending |

                                                                                                                                                            Foreach-Object {
    Write-Progress -Activity "Propce files" -status "Processing File(s) $i of $fileCount" -percentComplete ($i / ($fileCount)*100)
    $cloudFile= (GetCloudFileMetaData $_.Name,$cName)
 
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
            UploadFile ($_.FullName ,$cName)
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

