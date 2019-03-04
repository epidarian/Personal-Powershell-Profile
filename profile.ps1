function Encode-ImageToBase64 ([String]$FilePath, [String]$Prefix="data:image/png;base64"){
	$rawImageToByteString = [convert]::ToBase64String((Get-Content $FilePath -Encoding byte))
	$formattedImageFromByteStringToBase64 = "`"$Prefix,$rawImageToByteString`""
	echo $formattedImageFromByteStringToBase64
}

function Generate-RandomString ([int]$Length = 8, [switch]$SelectedSpecials, [switch]$AlphaCaps, [switch]$AlphaLowers, [switch]$Numerals) {
    if ($Length -le 0) {
        Write-Host "Error! Nonsensical Length"
    } else {
        if ($SelectedSpecials -ne $true) {
            $keyspace += [char[]]([char]33 + [char]126 + [char]64 + [char]46 + [char]94 + [char]35 + [char]95)
        } 

        if ($Numerals -ne $true) {
            $keyspace += [char[]]([char]48..[char]57)
        }
    
        if ($AlphaCaps -ne $true) {
            $keyspace += [char[]]([char]65..[char]90)
        }

        if ($AlphaLowers -ne $true) {
            $keyspace += [char[]]([char]97..[char]122)
        }
        
        if ($keyspace.Length -le 0) {
            Write-Host "Keyspace Error! No character pool! Increase Empathy!!!!" 
        } else { 
            $ResultString = (1..$Length | % {$keyspace | Get-Random}) -join "" 
            echo $ResultString
        }
    }
}
