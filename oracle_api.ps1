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
	UploadFile -cName "compute_images" -localfilePath E:\Pictures\download.jpg -toUploadFileName "renameddownload.jpg"
    UploadFile "C:\Users\can.kaya\Downloads\abba.png" compute_images
.EXAMPLE
	UploadAll -cName 'PROD_BLDY_EXCH_AREA' -extension "*" -LocalFilePath 'J:\SQLBACKUP\PROD-BLDY-SQL1\'

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
 


$StorageAccountName='Storage-'+$IdentityDomain
$OracleApiUri='https://'+$IdentityDomain+'.eu.storage.oraclecloud.com/'
$AuthUri=$OracleApiUri+'auth/v1.0'
$StorageUri=$OracleApiUri+"v1/"+$StorageAccountName+'/'
$XStorageUser= $StorageAccountName+':'+$UserEmail
$AuthToken=''


function GetWebRequest($Uri, $get, $InFile, $OutFile)
{
    $headers = @{}

    if($script:AuthToken -eq '')
    {
        (GetToken);
    }

    $headers["X-Auth-Token"] = $script:AuthToken;
    try
    {
        if($InFile)
        {
			Write-Log -Level Info ("Invoke-WebRequest -Method "+ $get+" -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+ $Uri+"-InFile"+  $InFile)
            $response = Invoke-WebRequest -Method $get -Headers $headers $Uri -InFile  $InFile
        }
        else{
			Write-Log -Level Info ("Invoke-WebRequest -Method "+ $get+" -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+ $Uri)
            $response = Invoke-WebRequest -Method $get -Headers $headers $Uri
        }
        
        if($response.StatusCode -eq 200)
        {
            Write-Log -Level Info -Message ("Successfully executed.`t"+$response.StatusDescription +"`t"+$get+"`t"+$Uri)
        }
        elseif($response.StatusCode -eq 401){
            Write-Log -Level Info -Message "Token has been expired"
            Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
            (GetToken);
            return (GetWebRequest $Uri $get)
        }
		elseif($response.StatusCode -eq 404){
            Write-Log -Level Info -Message "No object found(s)"
        }
		elseif($response.StatusCode -eq 204){
			Write-Log -Level Info -Message "No object found(s)"
		}
        else
        {
            Write-Log -Level Info -Message "For Status Codes: https://docs.oracle.com/en/cloud/iaas/storage-cloud/ssapi/Status%20Codes.html"
            Write-Log -Level Info -Message ("Status Code: "+$response.StatusDescription+" "+$Uri+" "+$get)
            Write-Log -Level Info -Message "ERROR GetWebRequest else block";
        }
        return $response
    }
    catch
    {
        Write-Log -Level Warn -Message ($_.Exception.Message)
		Write-Output  $response
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
	$_result;
    if($result -ne $null -and [bool]($result.PSobject.Properties.name -match "RawContent")){
        if($result.Content.gettype().Name -eq 'String'){
            $_result=  $result.Content;
        }elseif($result.Content.gettype().Name -eq 'Byte[]')
        {
            $_result= $result.RawContent;
        }
	 }
	 return ConvertTextToObject($_result);
}

function ConvertTextToObject($_result){
	if(!$_result){return $null;}

	$_result=$_result.Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
	$properties = @{}
	$properties.Add("StatusCode", $_result[0].Replace("HTTP/1.1" ,"").Split(" ")[1])
	$properties.Add("StatusDescription",$_result[0].Replace("HTTP/1.1" ,"").Split(" ")[2])

	for($i=1; $i -lt $_result.Length; $i++){
		$properties.Add($_result[$i].Split(": ",[StringSplitOptions]"None")[0] , ([regex]::split($_result[$i],":\s"))[1])
	}

	$object = New-Object –TypeName PSObject –Prop $properties
	return $object;
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

function UploadFile($localfilePath, $toUploadFileName, $cName=$ContainerName)
{
    #TODO: We must consider replace the file which has already in there this method overrides now
    if(!$toUploadFileName)
    {
        $toUploadFileName = (Get-ChildItem $localfilePath).Name
    }
    $ssUri= ($StorageUri+$cName+'/'+$toUploadFileName)

	if((HasFileOnTheCloud -cName $cName -localFile $localfilePath) -eq $true)
	{
		Write-Log -Level Info -Message ("By-passed, file already has on the cloud "+$toUploadFileName);
		return $true;
	}

    Write-Log -Level Info -Message (" Starting to upload "+$localfilePath +"' as named "+$toUploadFileName+ " to cloud")

    $response = GetWebRequest -Uri  $ssUri -get PUT -InFile $localfilePath

    if($response.StatusCode -eq 201)
    {
        Write-Log -Level Info -Message (" File successfully uploaded.`t"+($response.StatusDescription)+"`tPUT`t"+($StorageUri+$cName+'/'+($toUploadFileName.Name)))
        return $true;
    }
    else
    {
        Write-Log -Level Warn -Message "Error occured while file uploading"
		return $false;
    }
}

function HasFileOnTheCloud($cName, $localFile)
{
	$errorFlag=0;	
	$cloudFile= (GetCloudFileMetaData -cName $cName -fileName $localFile.Name)
	if($cloudFile -ne $null)
	{
		#these files length are same
		if([long]$cloudFile."Content-Length" -ne $localFile.Length)        
		{   
			Write-Log -Level Info -Message ("Content Lengths are not matched! "+($_.Length)+" "+$cloudFile."Content-Length" +" <> "+$localFile.Length)
			$errorFlag=1
		}
		
		#as we expect the date of these files
		if([datetime]$cloudFile."Last-Modified" -lt $localFile.LastAccessTimeUtc)
		{
			Write-Log -Level Info -Message ("Last-Modified/LastWriteTimeUtc values are not expected  for "+($_.LastWriteTimeUtc)+" "+$cloudFile."Last-Modified"+" <= "+ $localFile.LastWriteTimeUtc)
			$errorFlag=1
		}

		if($errorFlag -eq 0)
		{
			Write-Log -Level Info -Message ("By-passing, file already has on the cloud "+($localFile.Name));
			return $true;
		}	
	}
    return $false;
}

function UploadAll($cName=$ContainerName, $LocalFilePath="E:\Pictures", $extension="*")
{
    $i=1;
    $fileCount = ( Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension | Measure-Object ).Count;

    $files = Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension | sort LastWriteTimeUtc  | Foreach-Object {
        Write-Progress -Activity "Uploading files" -status "Processing File(s) $i of $fileCount" -percentComplete ($i / ($fileCount)*100)
       
		if((HasFileOnTheCloud -cName $cName -localFile $_) -eq $false)
		{
			 UploadFile -cName $cName -localfile $_.FullName
		}
		
    $i=$i+1;
    }
}

 
UploadAll -cName 'compute_images' -extension "*" -LocalFilePath 'J:\BACKUP\'






