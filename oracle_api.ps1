Import-Module -Name ($PSScriptRoot + "\libs.ps1")
# BEGIN Parameters
$UserEmail='xxx@email.com'
$UserPass = 'password'
$IdentityDomain = 'youridentitydomainNAme'
# END Parameters


$ContainerName='testContainer';
$LocalFilePath='E:\Pictures'
$extension='*'


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
    $internalheaders["X-Auth-Token"] = $script:AuthToken;	 
    Write-Log -Level Info -Message $("New Token's value is " + ($script:AuthToken))
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
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        ListContainers
    }
   
}

function ListCloudFiles($cName = $ContainerName) {
    $response = "";
    Write-Log -Level Info -Message "Getting file list from cloud"
    $internalheaders["Content-Type"] = "application/xml;charset=utf8"

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
            $FileListToBeShown.Add($_.name)| Out-Null
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
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        ListCloudFiles $cName
    }

    $FileListToBeShown
}

function GetCloudFileMetaData($fileName, $cName = $ContainerName) {
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
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        GetCloudFileMetaData $fileName $cName
    }
}

function _GetCloudFilePrefix($cName = $ContainerName, $prefix) {
    $response = "";
    try { 
         
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
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        _GetCloudFilePrefix $cName $prefix
    }
}

function GetCloudFileDetail($fileName, $cName = $ContainerName) {
    $objectMetaData = GetCloudFileMetaData $fileName $cName;
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
    return $objectMetaData
}


function _UploadFile($localfilePath, $toUploadFileName, $cName = $ContainerName) {
    #TODO: We must consider replace the file which has already in there this method overrides now
    if (!$toUploadFileName) {
        $toUploadFileName = (Get-ChildItem $localfilePath).Name
    }
    $ssUri = ($StorageUri + $cName + '/' + $toUploadFileName)



    if ((HasSpecificFileOnTheCloud -cName $cName -localFile $localfilePath -toUploadFileName $toUploadFileName ) -eq $true) {
        Write-Log -Level Info -Message ("you already have this File")
        return $true;
    }





    Write-Log -Level Info -Message (" Starting to upload " + $localfilePath + "' as named " + $toUploadFileName + " to cloud")
    $response = Invoke-WebRequest -Method PUT -Headers $internalheaders $ssUri -InFile $localfilePath 

    if ($response.StatusCode -eq 201) {
        Write-Log -Level Info -Message (" File successfully uploaded.`t" + ($response.StatusDescription) + "`tPUT`t" + ($StorageUri + $cName + '/' + ($toUploadFileName.Name)))
        return $true;
    }
    elseif ($continers.StatusCode -eq 401) {
        (GetToken);
        _UploadFile $localfilePath $toUploadFileName $cName
    }
    else {
        Write-Log -Level Warn -Message ("Error occured while file uploading" + $response.StatusDescription)
        Write-Output $response
        return $false;
    }
}

function UploadAll($cName = $ContainerName, $LocalFilePath = "E:\Pictures", $extension = "*") {
    
    $i = 1;
    $fileCount = ( Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension | where length -lt 5000000000 | Measure-Object ).Count;

    $files = Get-ChildItem $LocalFilePath -Recurse -File -Filter $extension |where length -lt 5000000000 | Sort-Object LastWriteTimeUtc -Descending  | Foreach-Object {
        Write-Progress -Activity "Uploading files" -status "Processing File(s) $i of $fileCount" -percentComplete ($i / ($fileCount) * 100)
        _UploadFile -cName $cName -localfilePath $_.FullName
		
        $i = $i + 1;
    }
}

function HasSpecificFileOnTheCloud($cName, $localFile, $toUploadFileName) {
    $_file = (Get-ChildItem $localFile)
    #TODO: We must consider replace the file which has already in there this method overrides now
    if (!$toUploadFileName) {
        $toUploadFileName = $_file.Name
    }
    $errorFlag = 0;	
    $cloudFile = (GetCloudFileMetaData -cName $cName -fileName $toUploadFileName)
    
    
     

    if ($cloudFile -ne $null) {
        #these files length are same
        if ([long]$cloudFile.Headers["Content-Length"] -ne $_file.Length) {   
            Write-Log -Level Info -Message ("Content Lengths are not matched! " + ($_.Length) + " " + $cloudFile.Headers["Content-Length"] + " <> " + $_file.Length)
            $errorFlag = 1
        }
		
        #as we expect the date of these files
        if ([datetime]$cloudFile.Headers["Last-Modified"] -lt $_file.LastAccessTimeUtc) {
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




function _DeleteFileFromCloud($fileName, $cName = $ContainerName) {
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
# DO NOT USE THIS METHOD
function DeleteFileFromCloud($fileName, $cName = $ContainerName, $overrideAllYes = $false) {
    Write-Log -Level Warn -Message ("Script will delete this file " + $fileName + " from cloud")
    if ($overrideAllYes) {
        $confirmation = "y";
    }
    else {
        $confirmation = Read-Host "Are you sure to delete this file? [y/n]"
    }
    
    if ($confirmation -eq "y") {
        $files = GetCloudFileDetail $fileName $cName
        if ($files.GetType() | where Name -eq "String") {
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

function _SetMarker($cName = $ContainerName, $filename, $prefix, $_RealFileName) {
    $response = "";
    try { 
        $object = Invoke-WebRequest -Method GET -Headers $internalheaders ($StorageUri + $cName + "?marker=" + $filename + "&prefix=" + $_RealFileName + $prefix + "&delimiter=%2F&format=xml")
    } 
    catch {
        Write-Log -Level Warn -Message ("An error occured while setting marker " + $fileName)
        $response = $_.Exception.Response
    }
    
    if ($object.StatusCode -eq 200) {
        Write-Log -Level Info -Message ("setting " + $fileName + "'s marker to cloud")
        return $object;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        _SetMarker $cName $fileName $prefix $_RealFileName
    }
}

function _CreatevirtualFile($cName = $ContainerName, $prefix, $LastLocalFileModifiedDate, $_RealFileName) {
    $response = "";
    try { 
        $createHeader = $internalheaders;
        $createHeader.Add("X-Object-Meta-Cb-Modifiedtime", $LastLocalFileModifiedDate)
        $createHeader.Add("X-Object-Manifest", ($cName + "/" + $_RealFileName + $prefix))
        $createHeader.Add("Content-Length", "0")
        $object = Invoke-WebRequest -Method PUT -Headers $createHeader ($StorageUri + $cName + "/" + $_RealFileName)
    } 
    catch {
        Write-Log -Level Warn -Message ("An error occured while creating virtualfile" + $fileName)
        $response = $_.Exception.Response
    }
    
    if ($object.StatusCode -eq 201) {
        Write-Log -Level Info -Message ("creating " + $fileName + "'s virtual file")
        return $object;
    }
    elseif ($response.StatusCode.Value__ -eq 401) {
        (GetToken);
        Write-Log -Level Info -Message "Token has been expired"
        Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
        _CreatevirtualFile $cName $prefix $LastLocalFileModifiedDate $_RealFileName
    }
}

function BigFileUpload($localfilePath) {
    $_RealFileName = Split-Path $localfilePath -leaf
    $prefix = _splitFile $localfilePath 10000000 
    
    $guid = ($localfilePath + $prefix)
    UploadAll -LocalFilePath ($guid + "*") -cName compute_images -extension "*"

    $lastObjectName = Get-ChildItem $guid*  -File | Sort-Object Length | Select Name, LastWriteTime -First 1
    _SetMarker -cName compute_images -filename $lastObjectName.Name -prefix $prefix -_RealFileName $_RealFileName
    _CreatevirtualFile -cName compute_images -prefix $prefix -LastLocalFileModifiedDate $lastObjectName.LastWriteTime.ToUniversalTime() -_RealFileName $_RealFileName


    Remove-Item -Path $localfilePath$prefix*
}

 
function _splitFile($inFile, [Int32] $bufSize) {
    $localFile = (get-item $inFile) 
    $_guid = ([guid]::NewGuid()).ToString().Replace("-", "")
    $_guid = "EB7A645290604987A8593CF7224B6A3D" #forcloudberry
    $guidName = ("!CB_" + $_guid + "_")
    $outPrefix = $localFile.FullName + $guidName.ToUpper() 
    $stream = [System.IO.File]::OpenRead($inFile)
  
    $chunkNum = 1
    $barr = New-Object byte[] $bufSize

    while ( $bytesRead = $stream.Read($barr, 0, $bufsize)) {
        $outFile = ($outPrefix + $chunkNum.ToString().PadLeft(6, '0'))
        $ostream = [System.IO.File]::OpenWrite($outFile)
        $ostream.Write($barr, 0, $bytesRead);
        $ostream.close();
        $chunkNum += 1
    }
    return $guidName;
}

function CreatManifestFileForBigFile($localPath, $FileName, $cName = $ContainerName) {

    $arr = Get-ChildItem  $localPath    | Foreach-Object {$_.Name}
    $Falloutlist = @()
    $ManifestPath = $($localPath + "/" + $FileName + ".manifest.json")
 
    foreach ($f in $arr) {
        $file = GetCloudFileMetaData -fileName $f -cName compute_images
        if ($file.StatusCode -eq 200) {
            $CurrentItem = New-Object system.Object
            $CurrentItem | Add-Member -type Noteproperty -Name path -Value compute_images/$f
            $CurrentItem | Add-Member -type Noteproperty -Name etag -Value $file.Etag
            $CurrentItem | Add-Member -type Noteproperty -Name size_bytes -Value $file."Content-Length".Replace("""", "")
        		
            $Falloutlist = $Falloutlist + $CurrentItem
        }
    }
    $Falloutlist| convertto-json >  $ManifestPath

     
    #UploadFile -isManifest $true -cName $cName -localfilePath $($ManifestPath+"/"+$FileName)
  
    return $true
}


 
#warm up
GetToken
#ListCloudFiles "compute_images"
#GetCloudFileDetail -fileName "SSRS_ReportCount.pbix" -cName "compute_images"

UploadAll -cName "compute_images" -extension "*" -LocalFilePath "D:\Setup\SSRS_ReportCount.pbix" 

#HasSpecificFileOnTheCloud -cName "compute_images" -localFile  "D:\Setup\SSRS_ReportCount.pbix" 


#GetCloudFileDetail -fileName "nmap-7.70-setup.exe" -cName "compute_images"

#BigFileUpload -localfilePath  "D:\Setup\SSRS_ReportCount.pbix"

 
#SplitFilesWithgfsplit D:\Setup\Sys_Ctr_Ops_Manager_Svr_2012_wSP1_Turkish_X18-57405.ISO   50000
 
#curl -v -k -X GET -H "X-Auth-Token: AUTH_tk91fe51c43f07cb8e7c3c7d8a00bc22dd" "https://linkpluscloud.eu.storage.oraclecloud.com/v1/Storage-linkpluscloud/compute_images?marker=Sys_Ctr_Ops_Manager_Svr_2012_wSP1_Turkish_X18-57405.ISO!CB_EB7A645290604987A8593CF7224B6A3D_000012&prefix=Sys_Ctr_Ops_Manager_Svr_2012_wSP1_Turkish_X18-57405.ISO!CB_EB7A645290604987A8593CF7224B6A3D_&delimiter=%2F&format=xml"



#curl -v -k -X PUT -H "X-Auth-Token: AUTH_tk91fe51c43f07cb8e7c3c7d8a00bc22dd" -H "X-Object-Meta-Cb-Modifiedtime: Tuesday, ‎April ‎26, ‎2016, ‏‎11:38:39 GMT" -H "X-Object-Manifest: compute_images/Sys_Ctr_Ops_Manager_Svr_2012_wSP1_Turkish_X18-57405.ISO!CB_EB7A645290604987A8593CF7224B6A3D_" -H "Content-Length: 0"   "https://linkpluscloud.eu.storage.oraclecloud.com/v1/Storage-linkpluscloud/compute_images/Sys_Ctr_Ops_Manager_Svr_2012_wSP1_Turkish_X18-57405.ISO"





























# function GetWebRequest($Uri, $get, $InFile, $OutFile) {
#     $headers = @{}
#     $_result;

#     if ($script:AuthToken -eq '') {
#         (GetToken);
#     }

#     $headers["X-Auth-Token"] = $script:AuthToken;
#     try {
#         if ($InFile) {
#             Write-Log -Level Info ("Invoke-WebRequest -Method " + $get + " -Headers [""X-Auth-Token""]" + $headers["X-Auth-Token"] + " " + $Uri + "-InFile" + $InFile)
#             $response = Invoke-WebRequest -Method $get -Headers $headers $Uri -InFile  $InFile
#         }
#         else {
#             Write-Log -Level Info ("Invoke-WebRequest -Method " + $get + " -Headers [""X-Auth-Token""]" + $headers["X-Auth-Token"] + " " + $Uri)
#             $response = Invoke-WebRequest -Method $get -Headers $headers $Uri
#         }
        
#         if ($response.StatusCode -eq 200) {
#             Write-Log -Level Info -Message ("Successfully executed.`t" + $response.StatusDescription + "`t" + $get + "`t" + $Uri)
#         }
#         elseif ($response.StatusCode -eq 401) {
#             (GetToken);
#             Write-Log -Level Info -Message "Token has been expired"
#             Write-Log -Level Warn -Message "Old Token's value is "+$script:AuthToken
#             $_result = (GetWebRequest $Uri $get)
#         }
#         elseif ($response.StatusCode -eq 404) {
#             Write-Log -Level Info -Message "No object found(s)"
#         }
#         elseif ($response.StatusCode -eq 204) {
#             Write-Log -Level Info -Message "No object found(s)"
#         }
#         else {
#             Write-Log -Level Info -Message "For Status Codes: https://docs.oracle.com/en/cloud/iaas/storage-cloud/ssapi/Status%20Codes.html"
#             Write-Log -Level Info -Message ("Status Code: " + $response.StatusDescription + " " + $Uri + " " + $get)
#             Write-Log -Level Info -Message "ERROR GetWebRequest else block";
#         }
#         Write-Host $response
#     }
#     catch {
#         Write-Log -Level Warn -Message ($_.Exception.Message)
#         Write-Output  $response
#         return $null;
#     }
#     return CheckGetData($_result);
# }









# function CheckGetData($result) {
#     $_result;
#     if ($result -ne $null -and [bool]($result.PSobject.Properties.name -match "RawContent")) {
#         if ($result.Content.gettype().Name -eq 'String') {
#             $_result = $result.Content.Split("`r`n");
#         }
#         elseif ($result.Content.gettype().Name -eq 'Byte[]') {
#             $_result = ConvertTextToObject($result.RawContent);
#         }
#     }
    
#     return ($_result);
# }

# function ConvertTextToObject($_result) {
#     if (!$_result) {return $null; }

#     $_result = $_result.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
#     $properties = @{}
#     $properties.Add("StatusCode", $_result[0].Replace("HTTP/1.1" , "").Split(" ")[1])
#     $properties.Add("StatusDescription", $_result[0].Replace("HTTP/1.1" , "").Split(" ")[2])

#     for ($i = 1; $i -lt $_result.Length; $i++) {
#         $properties.Add($_result[$i].Split(": ", [StringSplitOptions]"None")[0] , ([regex]::split($_result[$i], ":\s"))[1])
#     }

#     $object = New-Object –TypeName PSObject –Prop $properties
#     return $object;
# }



# function ManifestFile($remoteFile, $cName = $ContainerName) {
#     #You can't download objects that are larger than 10 MB using the web console. To download such objects, use the CLI or REST API.
#     $ssUri = ($StorageUri + $cName + '/' + $remoteFile + "?multipart-manifest=get")
#     Write-Host $ssUri
#     Write-Log -Level Info -Message ("Starting to download " + $remoteFile + " from the cloud")
#     $file = GetCloudFileMetaData $remoteFile $cName
#     #if($file.Contains("application/x-www-form-urlencoded;charset=UTF-8"))
#     #{
#     #has manifestfile
#     return (GetWebRequest $ssUri  Get)
#     # }
#     #else
#     #{
#     #     Write-Log -Level Warn -Message (" "+$remoteFile +" doesn't have manifest file")
#     #    return $null
#     # }
# }



# function UploadFile($localfilePath, $toUploadFileName, $cName = $ContainerName, $isManifest) {
#     #TODO: We must consider replace the file which has already in there this method overrides now
#     if (!$toUploadFileName) {
#         $toUploadFileName = (Get-ChildItem $localfilePath).Name
#     }
#     $ssUri = ($StorageUri + $cName + '/' + $toUploadFileName)

#     if (!$isManifest) {

#         if ((HasSpecificFileOnTheCloud -cName $cName -localFile $localfilePath -toUploadFileName $toUploadFileName ) -eq $true) {
#             return $true;
#         }
#     }
#     else {
#         $ssUri = $ssUri + "?multipart-manifest=put"
#     }
	

#     Write-Log -Level Info -Message (" Starting to upload " + $localfilePath + "' as named " + $toUploadFileName + " to cloud")

#     $response = GetWebRequest -Uri  $ssUri -get PUT -InFile $localfilePath 

#     if ($response.StatusCode -eq 201) {
#         Write-Log -Level Info -Message (" File successfully uploaded.`t" + ($response.StatusDescription) + "`tPUT`t" + ($StorageUri + $cName + '/' + ($toUploadFileName.Name)))
#         return $true;
#     }
#     else {
#         Write-Log -Level Warn -Message ("Error occured while file uploading" + $response.StatusDescription)
#         Write-Output $response
#         return $false;
#     }
# }








 