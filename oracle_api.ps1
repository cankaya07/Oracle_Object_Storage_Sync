# BEGIN Parameters
$ContainerName='EXCH_AREA';
$StorageAccountName='Storage-xxx'
$UserEmail='xxx@email.com'
$UserPass = 'password'
$OracleApiUri='https://xxx.eu.storage.oraclecloud.com/'
$LocalFilePath='E:\Pictures'
$extension='*'
# END Parameters

$AuthUri=$OracleApiUri+'auth/v1.0'
$StorageUri=$OracleApiUri+'v1/'+$StorageAccountName+'/'+$ContainerName
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
        WriteVerboseMessage ("Invoke-WebRequest -Method "+ $get+" -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+ $Uri)
        $response = Invoke-WebRequest -Method $get -Headers $headers $Uri
        
        if($response.StatusCode -eq 200)
        {
            WriteVerboseMessage ("Successfully executed.`t"+($response.StatusCode)+"`t"+$get+"`t"+$Uri)
            return $response
        }
        elseif($response.StatusCode -eq 401){
            WriteVerboseMessage ("Token has been expired")
            WriteVerboseMessage ("Old Token's value is "+$script:AuthToken)
            (GetToken);
            return (GetWebRequest $Uri $get)
        }
        else
        {
            WriteVerboseMessage ("For Status Codes: https://docs.oracle.com/en/cloud/iaas/storage-cloud/ssapi/Status%20Codes.html")
            WriteVerboseMessage $response.StatusCode+$Uri+" "+$get
            Write-Host "ERROR GetWebRequest else block";
        }

    }
    catch
    {

        Write-Host $_.Exception.Message
        Write-Host $response
        $tempHeaderString=$headers | Out-String
        WriteVerboseMessage ("ERROR`t"+$get+"`t"+ $Uri+"`t"+ $tempHeaderString+"`t"+ $response).ToString()
    }
}

function GetToken
{  
    $headers_ = @{}
    $headers_["X-Storage-User"] = $XStorageUser
    $headers_["X-Storage-Pass"] = $UserPass
    WriteVerboseMessage ("Getting new Token: ").ToString()
    $script:AuthToken = (Invoke-WebRequest -Method GET -Headers $headers_ $AuthUri).Headers["X-Auth-Token"].ToString();
    WriteVerboseMessage ("New Token's value is "+ ($script:AuthToken)).ToString()
}

function WriteVerboseMessage([string]$message)
{
    #$message = $message.substring -replace "\t", "`t"
    Write-Verbose ("`t"+($message)) -Verbose
}

function GetCloudFileMetaData($fileName)
{
    WriteVerboseMessage ("Getting "+$fileName +"'s metadata from cloud")
    return  (GetWebRequest ($StorageUri+'/'+$fileName) Head)
}

function ListCloudFiles()
{
     WriteVerboseMessage ("Getting file list from cloud")
     return  (GetWebRequest $StorageUri  Get).Content.Split("`r`n")
}

function UploadFile($localfile)
{
    $ssUri= ($StorageUri+'/'+($_.Name))

    WriteVerboseMessage ("Starting to upload "+$fileName +"'to cloud")
    WriteVerboseMessage ("Invoke-WebRequest -Method Put -Headers [""X-Auth-Token""]"+$headers["X-Auth-Token"]+" "+  ($StorageUri+'/'+($_.Name))+" -Infile"+ $localfile)
    $response = Invoke-WebRequest -Headers $headers -Method Put -uri $ssUri -Infile $localfile

    Write-Host ($response)
    Write-Host $response.Content
    if($response.StatusCode -eq 200)
    {
        WriteVerboseMessage ("File successfully uploaded.`t"+($response.StatusCode)+"`tPUT`t"+($StorageUri+'/'+($_.Name)))
        return $response
    }
    else
    {
        WriteVerboseMessage ("Error occured while file uploading")
    }
}

# DO NOT USE THIS METHOD
function DeleteFileFromFileSystem($fileName)
{
    WriteVerboseMessage ("Deleting this file "+$fileName +"'from cloud")
    #Write-Host (GetWebRequest ($StorageUri+'/'+$fileName) Delete)
    #return (GetWebRequest ($StorageUri+'/'+$fileName) Delete).Content 

    Write-Host (GetWebRequest ($StorageUri+'/'+$fileName)  Delete).Content 
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
            WriteVerboseMessage ("Content Lengths are not proper for "+($_.Name)+" "+$cloudFile.Headers["Content-Length"] +" <> "+$_.Length)
            $errorFlag=1
        }

        #as we expect the date of these files
        if([datetime]$cloudFile.Headers["Last-Modified"] -lt $_.LastWriteTimeUtc)
        {
            WriteVerboseMessage ("Last-Modified/LastWriteTimeUtc are not proper for "+($_.Name)+" "+$cloudFile.Headers["Last-Modified"]+" <= "+ $_.LastWriteTimeUtc)
            $errorFlag=1
        }

        if($errorFlag -eq 0)
        {
            WriteVerboseMessage ("By-passing file already has on the cloud "+($_.Name));
        }
    }
    else
    {
        if($errorFlag -eq 0)
        {
            WriteVerboseMessage ("Uploading.... "+($_.Name))
            UploadFile $_.FullName 
        }
    }

    if($errorFlag -eq 1)
    {
        Write-Host "We have a problem :)"
        break;
    }

    $i=$i+1;
  
    }

}

ListCloudFiles




