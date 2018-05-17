# BEGIN Parameters
$UserEmail = 'ondermurat85@gmail.com'
$UserPass = 'iBm1nd3r*'
$IdentityDomain = 'linkpluscloud'
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

$StorageAccountName = 'Storage-' + $IdentityDomain
$OracleApiUri = 'https://' + $IdentityDomain + '.eu.storage.oraclecloud.com/'
$AuthUri = $OracleApiUri + 'auth/v1.0'
$StorageUri = $OracleApiUri + "v1/" + $StorageAccountName + '/'
$XStorageUser = $StorageAccountName + ':' + $UserEmail
$AuthToken = ''

$internalheaders = @{} 

function GetToken {  
    $headers_ = @{}
    $headers_["X-Storage-User"] = $XStorageUser
    $headers_["X-Storage-Pass"] = $UserPass
    #$headers_["Content-Type"]= "text/plain;charset=UTF-8" 
    Write-Log -Level Info -Message "Getting new Token"
    $script:AuthToken = (Invoke-WebRequest -Method GET -Headers $headers_ $AuthUri).Headers["X-Auth-Token"].ToString();
    $script:internalheaders["X-Auth-Token"] = $script:AuthToken;	 
    Write-Log -Level Info -Message $("New Token's value is " + ($script:AuthToken))
}

function RefreshToken {
    (GetToken);
    Write-Log -Level Info -Message "Token has been expired"
    Write-Log -Level Warn -Message ("Old Token's value is "+$script:AuthToken)
}

function _GetCloudFilePrefix($cName, $prefix) {
    $response = "";
    try { 
        #compute_images?prefix=Pictures%2F2%2F&limit=1000&delimiter=%2F&format=xm
        $object = Invoke-WebRequest -Method GET -Headers $internalheaders ($StorageUri + $cName + '?prefix=' + $prefix + "&delimiter=%2F&format=xml") 
    } 
    catch {
        $response = $_.Exception.Response
    }
    #Write-Log -Level Info -Message ("Getting "+$fileName +"'s metadata from cloud")
    if ($object.StatusCode -eq 200) {
        return $object.Content;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        _GetCloudFilePrefix $cName $prefix
    }
}

function _SetMarker($cName , $LastFilePath, $prefix, $_RealFileName) {
    $response = "";
    try { 
        
        Write-Log -Level Info -Message ($StorageUri + $cName + "?marker=" + $LastFilePath + "&prefix=" + $_RealFileName + $prefix + "&delimiter=%2F&format=xml")
        $object = Invoke-WebRequest -Method GET -Headers $internalheaders ($StorageUri + $cName + "?marker=" + $LastFilePath + "&prefix=" + $_RealFileName + $prefix + "&delimiter=%2F&format=xml")
    } 
    catch {
        Write-Log -Level Warn -Message ("An error occured while setting marker " + $LastFilePath)
        $response = $_.Exception.Response
    }
    
    if ($object.StatusCode -eq 200) {
        Write-Log -Level Info -Message ("setting " + $LastFilePath + "'s marker to cloud")
        return $object;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        _SetMarker $cName $LastFilePath $prefix $_RealFileName
    }
}

function _GetUploadName($localFilePath) {
    #TODO: We must consider replace the file which has already in there this method overrides now
    #return $localFilePath.Name
    return $localFilePath.FullName.Substring(3, $localFilePath.FullName.Length - 3).Replace("\", "/")
      
}

function _CreatevirtualFile($cName , $prefix, $LastLocalFileModifiedDate, $_RealFileName) {
    $response = "";
    try { 
        $_RealFileName = $_RealFileName.Replace("/","%2F")
        #compute_images/Pictures%2F2%2FSSRS_ReportCount.pbix!CB_EB7A645290604987A8593CF7224B6A3D_
        $createHeader = $internalheaders;
        $createHeader.Add("X-Object-Meta-Cb-Modifiedtime", $LastLocalFileModifiedDate)
        $createHeader.Add("X-Object-Manifest", ($cName + "/" + $_RealFileName + $prefix))
        $createHeader.Add("Content-Length", "0")
        Write-Log -Level Info -Message ("Manifest-> "+($cName + "/" + $_RealFileName + $prefix))
        Write-Log -Level Info -Message ($StorageUri + $cName + "/" + $_RealFileName)
        $object = Invoke-WebRequest -Method PUT -Headers $createHeader ($StorageUri + $cName + "/" + $_RealFileName)
    } 
    catch {
        Write-Log -Level Warn -Message ("An error occured while creating virtualfile" + $_RealFileName)
        Write-Log -Level Error -Message $_.Exception.Response
        $response = $_.Exception.Response
    }
    
    if ($object.StatusCode -eq 201) {
        Write-Log -Level Info -Message ("created " + $_RealFileName + "'s virtual file")
        return $object;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        _CreatevirtualFile $cName $prefix $LastLocalFileModifiedDate $_RealFileName
    }
}



#this code block copied from https://github.com/zincarla/FileSplitter.ps1
function _splitFile($LoadFile, [Int32] $bufSize) {
    [System.Collections.ArrayList]$fileList = @() 
    $ReadBuffer = 4096
    #Convert from MB to KB to B
    $SegmentSize = $bufSize
    #Initialize read buffer
    $Buffer = New-Object Byte[] $ReadBuffer
    #Amount read in a pass.
    $AmtRead = $null
    #Current file segment
    $I = 1;

    #DateTime for update
    $LastUpdate = [DateTime]::Now
    $localFile = (get-item $LoadFile) 
    #$_guid = ([guid]::NewGuid()).ToString().Replace("-", "")
    $_guid = "EB7A645290604987A8593CF7224B6A3D" #forcloudberry
    $guidName = ("!CB_" + $_guid + "_") #forcloudberry
    $SaveFile = $localFile.FullName + $guidName.ToUpper()

    Write-Progress -Activity "Splitting" -Status "Starting" -PercentComplete 0
    $StreamReader = New-Object System.IO.FileStream -ArgumentList @($LoadFile, [System.IO.FileMode]::Open)
    $StreamWriter = New-Object System.IO.FileStream -ArgumentList @(($SaveFile + $I.ToString().PadLeft(6, '0')), [System.IO.FileMode]::Create)
    $fileList.Add(($SaveFile + $I.ToString().PadLeft(6, '0'))) | Out-Null
    #CurrentSize of the file segment we are working on.
    $TotalSize = $StreamReader.Length
    $CurrentTotal = 0
    $CurrentSize = 0
    while ($AmtRead -ne 0 -or $AmtRead -eq $null) {
        #Read the file to memory
        $AmtRead = $StreamReader.Read($Buffer, 0, $ReadBuffer)
        if ($AmtRead -gt 0) {
            #Write the file to the file segment
            $StreamWriter.Write($Buffer, 0, $AmtRead);
            $CurrentSize += $AmtRead;
            $CurrentTotal += $AmtRead;
            if ([DateTime]::Now - $LastUpdate -gt [TimeSpan]::FromSeconds(5)) {
                Write-Progress -Activity "Splitting" -Status "Writing" -PercentComplete (($CurrentTotal * 100) / $TotalSize)
                $LastUpdate = [DateTime]::Now
            }
        }
        if ($CurrentSize -ge $SegmentSize) {
            #Once the current segment is larger or equal to the specified size, finish the file and start a new segment.
            $CurrentSize = 0;
            $StreamWriter.Close();
            $I++;
            $fileList.Add(($SaveFile + $I.ToString().PadLeft(6, '0'))) | Out-Null
            $StreamWriter = New-Object System.IO.FileStream -ArgumentList @(($SaveFile + $I.ToString().PadLeft(6, '0')), [System.IO.FileMode]::Create)
            Write-Progress -Activity "Splitting" -Status "New-File" -PercentComplete (($CurrentTotal * 100) / $TotalSize)
        }
    }
    #CleanUp
    $StreamWriter.Close();
    $StreamReader.Close();
    $returnOject = "" 
    $returnOject = $returnOject| Add-Member @{FileFullName = $localFile.FullName}  -PassThru
    $returnOject = $returnOject| Add-Member @{GuidName = $guidName}  -PassThru
    $returnOject = $returnOject|Add-Member @{FileList = $fileList} -PassThru
   
    return $returnOject;
    Write-Progress -Activity "Splitting" -Status "Completed" -PercentComplete 100 -Completed
}

function __UploadFile($localfilePath, $toUploadFileName, $cName ) {
    $response = "";
    $ssUri = ($StorageUri + $cName + '/' + $toUploadFileName)
    Write-Log -Level Info -Message $ssUri
    try { 
         
        Write-Log -Level Info -Message (" Starting to upload " + $localfilePath + "' as named " + $toUploadFileName + " to cloud")
        $object = Invoke-WebRequest -Method PUT -Headers $internalheaders $ssUri -InFile $localfilePath 
    } 
    catch {
        $response = $_.Exception.Response
    }
    #Write-Log -Level Info -Message ("Getting "+$fileName +"'s metadata from cloud")
    if ($object.StatusCode -eq 201) {
        Write-Log -Level Info -Message (" File successfully uploaded.`t" + ($object.StatusDescription) + "`tPUT`t" + ($StorageUri + $cName + '/' + ($toUploadFileName)))
        return $true;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        __UploadFile $localfilePath $toUploadFileName $cName
    }
    else {
        Write-Log -Level Warn -Message ("Error occured while file uploading" + $response.StatusDescription)
        Write-Output $object
        return $false;
    }
}

function _DeleteFileFromCloud($fileName, $cName ) {
    $result = Invoke-WebRequest -Method DELETE -Headers $internalheaders ($StorageUri + $cName + '/' + $fileName)
    if ($result.StatusCode -eq 204) {
        Write-Log -Level Info -Message "File deletion succeeded"
        return $true;
    }
    elseif ($continers.StatusCode -eq 401) {
        (GetToken);
        _DeleteFileFromCloud $fileName $cName
    }
    else {
        Write-Log -Level Info -Message "Error! File couldnt delete"
        return $false;
    }
}

function ListContainers() {
    $response = "";
    $internalheaders["Content-Type"] = "application/xml;charset=utf8"
    try { 
        $continers = Invoke-WebRequest -Method GET -Headers $internalheaders $OracleApiUri'v1/'$StorageAccountName"?limit=15&delimiter=%2F&format=xml"
    } 
    catch {
        $response = $_.Exception.Response
    }

    if ($continers.StatusCode -eq 200) {
        $([xml]$continers.Content).SelectNodes('//account/container') | ForEach-Object {
            Write-Host $_.name
        }
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        ListContainers
    }
   
}

function ListCloudFiles($cName) {
    $response = "";

    try { 
        $files = Invoke-WebRequest -Method GET -Headers $internalheaders $StorageUri$cName"?limit=1000&delimiter=%2F&format=xml" 
    } 
    catch {
        $response = $_.Exception.Response
    }
     
    [System.Collections.ArrayList]$FileListToBeShown = @()  
    $tempManifestFile = "";
        
    if ($files.StatusCode -eq 200) {

        $([xml]$files.Content).SelectNodes('//container/object') | ForEach-Object {
            #Write-Host $_.name $_.hash $_.bytes $_.last_modified
            $FileListToBeShown.Add($_.name+"`t`t"+($_.bytes/1024/1024)+"MB")| Out-Null
            if ($_.bytes -eq 0) {
                $object = GetCloudFileMetaData $_.name $cName
                $tempManifestFile = $object.Headers["X-Object-Manifest"].Replace($cName + "/", "").Replace("%21", "!") #TODO ASCII Replace
            }
             
            if ($_.name.Contains($tempManifestFile)) {
                $FileListToBeShown.Remove($_.name) | Out-Null
            }
            
        }
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        ListCloudFiles $cName
    }

    $FileListToBeShown
}

function GetCloudFileMetaData($fileName, $cName) {
    $response = "";
    try { 
        $object = Invoke-WebRequest -Method HEAD -Headers $internalheaders ($StorageUri + $cName + '/' + $fileName)
    } 
    catch {
        Write-Log -Level Warn -Message ("An error occured while getting " + $fileName + "'s metadata from cloud")
        $response = $_.Exception.Response
    }
    
    if ($object.StatusCode -eq 200) {
        Write-Log -Level Info -Message ("Getting " + $fileName + "'s metadata from cloud")
        return $object;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        RefreshToken
        GetCloudFileMetaData $fileName $cName
    }
}
function GetCloudFileDetail($fileName, $cName) {
    $objectMetaData = GetCloudFileMetaData $fileName $cName;

    if ($objectMetaData) {
        if ($objectMetaData.Headers.GetEnumerator() | Where-Object {$_.Key -eq "X-Object-Manifest"}) {
            $prefix = $objectMetaData.Headers["X-Object-Manifest"].Replace($cName + "/", "").Replace("%21", "!")
            $result = _GetCloudFilePrefix $cName $prefix


            $totalBytes = 0
            $([xml]$result).SelectNodes('//container/object') | ForEach-Object {
                #Write-Host $_.name $_.hash $_.bytes $_.last_modified
                $totalBytes += $_.bytes       
            }
            $objectMetaData.Headers["Content-Length"] = $totalBytes
        }
    }
    return $objectMetaData
}

#TODO need some assintance
function DeciceBufferSizeForMultipart($fileLength) {
    # A large object can have a maximum of 2048 segments. Each segment can be up to 5 GB. 
    # So the maximum size of a file that you can upload to Oracle Cloud Infrastructure 
    # Object Storage Classic as a large object is 10 TB.
    if ($fileLength -gt (10 * 1024 * 1024 * 1024 * 1024) ) {
        Write-Log -Level Error -Message ("File is too Huge for object Storaga up to 10 TB")
        return 0;
    }

    if ($fileLength / 2048 -lt 10 * 1024 * 1024) {
        return 10 * 1024 * 1024
    }
    elseif ($fileLength / 2048 -lt 30 * 1024 * 1024) {
        return 30 * 1024 * 1024
    }
    elseif ($fileLength / 2048 -lt 50 * 1024 * 1024) {
        return 50 * 1024 * 1024
    }
    elseif ($fileLength / 2048 -lt 100 * 1024 * 1024) {
        return 100 * 1024 * 1024
    }
    else {
        return [Int32] $fileLength / 2048
    }
    
     
}

function _UploadFile($localfilePath, $toUploadFileName, $cName) {
    $_file = (Get-ChildItem $localfilePath)
    
    if (!$toUploadFileName) {
        $toUploadFileName = _GetUploadName($_file)
    }
    
    if ((HasSpecificFileOnTheCloud -cName $cName -localFile $localfilePath -toUploadFileName $toUploadFileName ) -eq $true) {
        Write-Log -Level Info -Message ("you already have this File")
        return $true;
    }

    if ($_file.Length -gt 10000000) {
        try {
            $bufSize = DeciceBufferSizeForMultipart -fileLength $_file.Length
            if ($bufSize -eq 0) {
                return false;
                write-host too big file
            }
            $prefix = _splitFile -LoadFile $localfilePath -bufSize  $bufSize

            foreach ($chunkfile in $prefix.FileList) {
                __UploadFile -cName $cName -localfilePath $chunkfile -toUploadFileName $(_GetUploadName((Get-ChildItem $chunkfile)))
            }

            
            $lastObjectName = _GetUploadName (Get-ChildItem ($prefix.FileList[-1]))
            _SetMarker -cName compute_images -LastFilePath $lastObjectName -prefix $prefix.GuidName -_RealFileName $_RealFileName
            _CreatevirtualFile -cName compute_images -prefix $prefix.GuidName -LastLocalFileModifiedDate $_file.LastWriteTime.ToUniversalTime() -_RealFileName $toUploadFileName
    
        }
        catch {
            Write-Log -Level Warn -Message ("error occured while uploading file")
        }
        finally {
            foreach ($chunkfile in $prefix.FileList) {
                Remove-Item -Path $chunkfile
            }
        }
    }
    else {
        __UploadFile -cName $cName -localfilePath $localfilePath -toUploadFileName $toUploadFileName
    }
}

function UploadAll($cName , $LocalFilePath = "E:\Pictures", $extension = "*") {
    
    $i = 1;
    $fileCount = ( Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension  | Measure-Object ).Count;

    Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension | Sort-Object LastWriteTimeUtc -Descending  | Foreach-Object {
        Write-Progress -Activity "Uploading files" -status "Processing File(s) $i of $fileCount" -percentComplete ($i / ($fileCount) * 100)
        _UploadFile -cName $cName -localfilePath $_.FullName
        
		
        $i = $i + 1;
    }
}
 
function HasSpecificFileOnTheCloud($cName, $localFile, $toUploadFileName) {
    $_file = (Get-ChildItem $localFile)
    if (!$toUploadFileName) {
        $toUploadFileName = _GetUploadName($_file)
    }
    $errorFlag = 0;	
    $cloudFile = (GetCloudFileDetail -cName $cName -fileName $toUploadFileName)

    if ($cloudFile -ne $null) {
        #these files length are same
        if ([long]$cloudFile.Headers["Content-Length"] -ne $_file.Length) {   
            Write-Log -Level Info -Message ("Content Lengths are not matched! " + $cloudFile.Headers["Content-Length"] + " <> " + $_file.Length)
            $errorFlag = 1
        }
		
        #as we expect the date of these files
        if ([datetime]$cloudFile.Headers["Last-Modified"] -lt $_file.LastAccessTimeUtc -and $errorFlag -ne -1) {
            Write-Log -Level Info -Message ("Last-Modified/LastWriteTimeUtc values are not expected  for " + ($_.LastWriteTimeUtc) + " " + $cloudFile.Headers["Last-Modified"] + " <= " + $_file.LastWriteTimeUtc)
            $errorFlag = 1
        }

        if ($errorFlag -eq 0) {
            Write-Log -Level Info -Message ("By-passing, file already has on the cloud " + ($_file.Name));
            return $true;
        }	
    }

    return $false;
}

# DO NOT USE THIS METHOD
function DeleteFileFromCloud($fileName, $cName, $overrideAllYes = $false) {
    Write-Log -Level Warn -Message ("Script will delete this file " + $fileName + " from cloud")
    if ($overrideAllYes) {
        $confirmation = "y";
    }
    else {
        $confirmation = Read-Host "Are you sure to delete this file? [y/n]"
    }
    
    if ($confirmation -eq "y") {
        $files = GetCloudFileDetail $fileName $cName
        if ($files.GetType() | Where-Object Name -eq "String") {
            #multipart
            $([xml]$files).SelectNodes('//container/object') | ForEach-Object {
                _DeleteFileFromCloud $_.name $cName
            }
        }
        else {
            _DeleteFileFromCloud $fileName $cName
        }
    }
    else {
        Write-Log -Level Info -Message ("Canceled")
        return $null;
    }
}

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
function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [Alias('LogPath')]
        [string]$Path = $PSScriptRoot + '\PowerShellLog.log',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoClobber
    )

    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process {
        
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
    End {
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
        ,
        [Parameter(Mandatory = $true, HelpMessage = "Please enter a bucket name.")]
        [string] $cName
    )

    function Get-ContentLength {
        [CmdletBinding()]
        param (
            [string] $Url
        )
        
        if(!$script:AuthToken){
            RefreshToken
        }


        $Req = [System.Net.HttpWebRequest]::CreateHttp($Url);
        $Req.Headers.Add("X-Auth-Token", $script:AuthToken)
        $Req.Method = 'HEAD';
        $Req.Proxy = $null;
        $Response = $Req.GetResponse();
        #Write-Output -InputObject $Response.ContentLength;
        Write-Output -InputObject $Response;
    }
    $Url = $StorageUri + $cName + $Url
    Write-Host $Url
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
    $wc.Headers.Add("X-Auth-Token", $script:AuthToken)

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

        Write-Host -Object ("Download speed is: {0:N2}MB/sec NewSize:{1}TotalSize{2}" -f ($UpdatedSize / 1MB), $NewSize, $FileSize);

    }
}

GetToken
#ListCloudFiles "PROD_BLDY_EXCH_AREA"
#GetCloudFileDetail -cName "compute_images" -fileName "SSRS_ReportCount.pbix "
UploadAll -cName "compute_images" -extension "*" -LocalFilePath "E:\Pictures"


#Measure-DownloadSpeed -cName "compute_images" -Url "/bootimagetestdcv2.tar.gz" -Path C:\Users\can.kaya\Desktop\bootimagetestdcv2.tar.gz
 

#_splitFile "E:\Pictures\2\SSRS_ReportCount.pbix" 10485760