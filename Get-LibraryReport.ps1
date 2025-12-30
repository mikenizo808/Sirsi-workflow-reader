Function Get-LibraryReport{

    <#
        .DESCRIPTION
            Imports a text report from a custom public library software and returns the desired values as PowerShell objects.

        .NOTES
            This works with text reports from a legacy version of `SirsiDynix Symphony WorkFlows`, used by some public Libraries.

        .EXAMPLE
        #paste into Powershell. Adjust paths as needed. No backslash at the end of the path when importing.
        Import-Module "C:\Scripts\Get-LibraryReport.ps1" -Force
        
        #show a brief report with only a few columns
        Get-LibraryReport -Path ~/Downloads/example-library-report.txt -Brief

        #show a "Pretty" report (if your terminal is wide enough)
        Get-LibraryReport -Path ~/Downloads/example-library-report.txt -Pretty

        #Save a report to a variable
        $report = Get-LibraryReport -Path ~/Downloads/example-library-report.txt
        
        #show first entry in report
        $report[0]

        #show full report
        $report
        
        #show report in grid view
        $report | Out-GridViiew
        
        #export report
        $report | Export-Csv -NoTypeInformation C:\Temp\report.csv

        #show pretty report
        report | Format-Table -AutoSize

        #or, use the "Pretty" switch
        Get-LibraryReport -Path ~/Downloads/example-library-report.txt -Pretty

    #>

    [CmdletBinding()]
    Param(

        #String. The path to a text file containing the raw library report to be processed.
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [Alias('InputFile')]
        [string]$Path,

        #Switch. Optionally return only a few properties for each entry such as Header, Author, Location, and Description. This is ignored if using the "Pretty" parameter.
        [switch]$Brief,

        #Switch. Optionally show pretty text output. This automatically does a "Format-Table -AutoSize" to make the output wider.
        [Alias('Wide')]
        [switch]$Pretty,

        #Switch. Optionally use the legacy sorting approach contained in the default vendor reports. This is undersired for a Library location that does not split sections into sub-groups since author names may be out of order.
        [switch]$UseLegacySorting,

        #Switch. Optionally show the raw inputted text file with character counts for each line.
        [switch]$ShowCharacterCount,

        #Switch. Optionally show the raw inputted text file without processing it.
        [switch]$Passthru
    )

    Process{

        ## Handle input content
        $content = Get-Content $Path

        ## Optionally show ingested content
        if($Passthru.IsPresent){
            return $content
        }

        ## Optionally show the character count per line, then exit
        if($ShowCharacterCount.IsPresent){
            foreach($line in $content){
                Write-Output ('{0},{1}' -f $line.Length, $line)
            }
            return $null
        }
        
        ## details
        $items = @()
        foreach($line in $content){
            
            ## Header will be 3 letters
            if($line.Length -eq 3){
                $Header = $line
            }
            ## Handle header exception for graphic novels
            Elseif($line -match '^GN '){
                $Header = $line
            }

            ## Handle author
            if($line -like "*,*" -and $line.Length -lt 50){
                $Author = $line.Trim()
            }

            ## Handle Description
            if($line -match ' / '){
                $Description = $line.Trim()
            }

            ## Handle copy count
            if($line -match 'copy:'){
                $copyCount = ((($line -split 'copy:')[1] -split ' ')[0]).Trim()
            }

            ## Handle "item ID"
            if($line -match 'item ID:'){
                $itemID = ((($line -split 'item ID:')[1] -split ' ')[0]).Trim()

                ## Optionally handle ID with double colon "::"
                if($itemID -match '^:'){
                    $itemID = $itemID -replace '^:',''
                }
            }

            ## Handle type
            if($line -match 'type:'){
                $type = ((($line -split 'type:')[1] -split ' ')[0]).Trim()
            }
            
            ## Handle location
            if($line -match 'location:'){
                $Location = ($line -split 'location:')[1]

                if($Location -match '-'){
                    $Location = ($Location -split '-')[0]
                }
            }

            ## We can use 'Date of discharge' to indicate the end of a book/item
            if($line -match 'Date of discharge:'){
                
                $items += [PSCustomObject]@{
                    Header       = $Header
                    Author       = $Author
                    Description  = $Description
                    Copy         = $copyCount
                    ItemId       = $itemID 
                    Type         = $type
                    Date         = ($line -split 'Date of discharge:')[1]
                    Location     = $Location
                }
            }
        }#End foreach

        ## Handle sorting
        if($UseLegacySorting){
            Write-Warning -Message 'Legacy sorting may result in less than optimal path to target location.'
        }
        Else{
            $items = $items | Sort-Object Location,Header,Author,Description
        }

        ## Handle output
        if($items){
            if($Pretty.IsPresent){
                $items | Format-Table -AutoSize
            }
            Elseif($Brief.IsPresent){
                return $items | Select-Object Header, Author, Location, Description
            }
            Else{
                return $items
            }
        }
        Else{
            Write-Warning -Message 'No results. Check your inputs and try again.'
            exit 1
        }
    }#End Process
}#End Function
