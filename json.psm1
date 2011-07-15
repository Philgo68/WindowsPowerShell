#requires -version 2.0
# No help (yet) because I'm still changing and renaming everything every time I mess with this code
Add-Type -Assembly System.ServiceModel.Web, System.Runtime.Serialization
$utf8 = [System.Text.Encoding]::UTF8


function Convert-JsonToXml
{
PARAM([Parameter(ValueFromPipeline=$true)][string[]]$json)
BEGIN { $mStream = new-object System.IO.MemoryStream }
PROCESS {
   $json | Write-String -Stream $mStream
}
END {
   $mStream.Position = 0
   $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($mStream,[System.Xml.XmlDictionaryReaderQuotas]::Max)
   try
   {
      $xml = new-object Xml.XmlDocument
      $xml.Load($jsonReader)
      $xml
   }
   finally
   {
      $jsonReader.Close()
      $mStream.Dispose()
   }
}
}
 
function Convert-XmlToJson
{
PARAM([Parameter(ValueFromPipeline=$true)][xml]$xml)
Process{
   $mStream = new-object System.IO.MemoryStream
   $jsonWriter = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonWriter($mStream)
   try
   {
     $xml.Save($jsonWriter)
     $bytes = $mStream.ToArray()
     [System.Text.Encoding]::UTF8.GetString($bytes,0,$bytes.Length)
   }
   finally
   {
     $jsonWriter.Close()
     $mStream.Dispose()
   }
}
}



function ConvertFrom-Json {
PARAM( [Parameter(Mandatory=$true)][Type[]]$type, [Parameter(ValueFromPipeline=$true,Mandatory=$true)][String]$json )
PROCESS{ 
   $ms = New-object IO.MemoryStream (,$utf8.GetBytes($json))
   Import-Json $type $ms 
   $ms.dispose()
}
}

function Import-Json {
[CmdletBinding(DefaultParameterSetName="File")]
PARAM( 
[Parameter(Mandatory=$true,Position=1)][Type[]]$type
, 
[Parameter(Mandatory=$true,Position=2,ParameterSetName="Stream")][IO.Stream]$Stream 
, 
[Parameter(Mandatory=$true,Position=2,ParameterSetName="File")][String]$Path
)
BEGIN {
   if($PSCmdlet.ParameterSetName -eq "File") {
      $Stream = [IO.File]::Open($Path, "Read")
   }
}
PROCESS{
   if($type.Count -gt 1) {
      $t,$types = @($type)
      $js = New-Object System.Runtime.Serialization.Json.DataContractJsonSerializer $t, (,@($types))
   } else {
      $js = New-Object System.Runtime.Serialization.Json.DataContractJsonSerializer @($type)[0] 
   }
   Write-Output $js.ReadObject($Stream)
}
END {
   if($PSCmdlet.ParameterSetName -eq "File") {
      $Stream.Dispose()
   }
}
}

function Export-Json {
[CmdletBinding(DefaultParameterSetName="File")]
PARAM( 
[Parameter(Mandatory=$true,Position=1)][Array]$InputObject
, 
[Parameter(Mandatory=$true,Position=2,ParameterSetName="Stream")][IO.Stream]$Stream 
, 
[Parameter(Mandatory=$true,Position=2,ParameterSetName="File")][String]$Path
)
BEGIN {
   if($PSCmdlet.ParameterSetName -eq "File") {
      $Stream = [IO.File]::Open($Path, "Write")
   }
}
PROCESS {
   [type]$Type = @($InputObject)[0].GetType()

   if($Type -isnot [Array]) { #$InputObject.Count -gt 1 -and 
      [type]$Type = "$($Type)[]"
   }
   
   [Type[]]$types = ($InputObject | select -expand PsTypeNames) | % { $_ -split "`n" -replace "^Selected\." } | Select -unique
   
   #Write-Verbose $($Types | select -expand FullName | out-string)
   #Write-Verbose "Stream: $($Stream.GetType())"
   Write-Verbose "Output: $Type"
   Write-Verbose "Input: $($InputObject.GetType())"
   
   $js = New-Object System.Runtime.Serialization.Json.DataContractJsonSerializer $Type #, $Types #, ([int]::MaxValue), $false, $null, $false
   $js.WriteObject( $stream, $InputObject )
}
END {
   if($PSCmdlet.ParameterSetName -eq "File") {
      $Stream.Dispose()
   }
}
}


function ConvertTo-Json {
PARAM( [Parameter(ValueFromPipeline=$true,Mandatory=$true)]$object )
BEGIN {    
   [type]$lastType = $null
   function Out-JsonString {
      Param($items)
      $ms = New-Object IO.MemoryStream
      Export-Json $items.ToArray() $ms
      $utf8.GetString( $ms.ToArray(), 0, $ms.Length )
      $ms.Dispose()
   }
}
PROCESS {
   $thisType = $object.GetType()
   if(!$lastType -or $lastType -ne $thisType) { 
      if($lastType) { Out-JsonString $items }
      # make a new collection
      $items = new-object "System.Collections.Generic.List[$thisType]"
   }
   $items.Add($object)
   $lastType = $thisType
}
END {
   Out-JsonString $items
}
}

function Write-String {
param([Parameter()]$stream,[Parameter(ValueFromPipeline=$true)]$string)
process {
  $bytes = $utf8.GetBytes($string)
  $stream.Write( $bytes, 0, $bytes.Length )
}  
}
New-Alias fromjson ConvertFrom-Json
New-Alias tojson ConvertTo-Json

New-Alias cvfjs ConvertFrom-Json
New-Alias cvtjs ConvertTo-Json
New-Alias ipjs Import-Json
New-Alias epjs Export-Json


Export-ModuleMember -Function ConvertFrom-Json, Import-Json, Export-Json, ConvertTo-Json, Convert-JsonToXml, Convert-XmlToJson -Alias *