function Export-DbaDiagnosticQuery {
	<#
		.SYNOPSIS 
			Export-DbaDiagnosticQuery can convert ouput generated by Invoke-DbaDiagnosticQuery to CSV or Excel

		.DESCRIPTION
			The default output format of Invoke-DbaDiagnosticQuery is a custom object. It can also output to CSV and Excel. 
			However, CSV output can generate a lot of files and Excel output depends on the ImportExcel module by Doug Fike (https://github.com/dfinke/ImportExcel)
			Export-DbaDiagnosticQuery can be used to convert from the default export type to the other available export types.

		.PARAMETER InputObject
			Specifies the objects to convert
			
		.PARAMETER ConvertTo
			Specifies the output type. Valid choices are Excel and CSV. CSV is the default.
			
		.PARAMETER Path
			Specifies the path to the output files. 

		.PARAMETER Suffix
			Suffix for the filename. It's datetime by default.

        .PARAMETER NoPlanExport
            Use this switch to suppress exporting of .sqlplan files

        .PARAMETER NoQueryExport
            Use this switch to suppress exporting of .sql files

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.NOTES
			Tags: Query
			Author: Andre Kamman (@AndreKamman), http://clouddba.io

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Export-DbaDiagnosticQuery

		.EXAMPLE  
			Invoke-DbaDiagnosticQuery -SqlInstance sql2016 | Export-DbaDiagnosticQuery -Path c:\temp

			Converts output from Invoke-DbaDiagnosticQuery to multiple CSV files
			
		.EXAMPLE 
			$output = Invoke-DbaDiagnosticQuery -SqlInstance sql2016
			Export-DbaDiagnosticQuery -InputObject $output -ConvertTo Excel

			Converts output from Invoke-DbaDiagnosticQuery to Excel worksheet(s) in the Documents folder
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[object[]]$InputObject,
		[ValidateSet("Excel", "Csv")]
		[string]$ConvertTo = "Csv",
		[System.IO.FileInfo]$Path = [Environment]::GetFolderPath("mydocuments"),
		[string]$Suffix = "$(Get-Date -format 'yyyyMMddHHmmssms')",
        [switch]$NoPlanExport,
        [switch]$NoQueryExport,
		[switch][Alias('Silent')]$EnableException
	)
	
	begin {
		if ($ConvertTo -eq "Excel") {
			try {
				Import-Module ImportExcel -ErrorAction Stop
			}
			catch {
				$message = "Failed to load module, exporting to Excel feature is not available
							Install the module from: https://github.com/dfinke/ImportExcel
							Valid alternative conversion format is csv"
				Stop-Function -Message $message
				return
			}
		}

		if(!$(Test-Path $Path)) {
			try 
			{				
				New-Item $Path -ItemType Directory -ErrorAction Stop | Out-Null
				Write-Message -Level Output -Message "Created directory $Path"
			} catch {
				Stop-Function -Message "Failed to create directory $Path" -Continue
			}
		}
		
		Function Remove-InvalidFileNameChars {
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true,
						   Position = 0,
						   ValueFromPipeline = $true,
						   ValueFromPipelineByPropertyName = $true)]
				[String]$Name
			)
			$Name = $Name.Replace(" ","-")
			$invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
			$re = "[{0}]" -f [RegEx]::Escape($invalidChars)
			return ($Name -replace $re)
		}
	}
	
	process {
		if (Test-FunctionInterrupt) { return }
		
		foreach ($row in $InputObject) {
			$result = $row.Result
			$name = $row.Name
			$SqlInstance = $row.SqlInstance.Replace("\", "$")
			$dbname = $row.DatabaseName
			$number = $row.Number			
				
			if ($null -eq $result) {
				Stop-Function -Message "Result was empty for $name" -Target $result -Continue
			}
				
			$queryname = Remove-InvalidFileNameChars -Name $Name
			$excelfilename = "$Path\$SqlInstance-DQ-$Suffix.xlsx"
			$exceldbfilename = "$Path\$SqlInstance-DQ-$dbname-$Suffix.xlsx"
			$csvdbfilename = "$Path\$SqlInstance-$dbname-DQ-$number-$queryname-$Suffix.csv"
			$csvfilename = "$Path\$SqlInstance-DQ-$number-$queryname-$Suffix.csv"

            if (($result | Get-Member | Where-Object Name -eq "Query Plan").Count -gt 0) {
                $plannr = 0
                foreach ($plan in $result."Query Plan") {
                    $plannr += 1
                    if ($row.DatabaseSpecific) {
                        $planfilename = "$Path\$SqlInstance-$dbname-DQ-$number-$queryname-$plannr-$Suffix.sqlplan"
                    }
                    else {
                        $planfilename = "$Path\$SqlInstance-DQ-$number-$queryname-$plannr-$Suffix.sqlplan"
                    }
                    
                    if (!$NoPlanExport)
                    {
					    Write-Message -Level Output -Message "Exporting $planfilename"
                        $plan | Out-File -FilePath $planfilename
                    }
                }

                $result = $result | Select-Object * -ExcludeProperty "Query Plan"
            }

            if (($result | Get-Member | Where-Object Name -eq "Complete Query Text").Count -gt 0) {
                $sqlnr = 0
                foreach ($sql in $result."Complete Query Text") {
                    $sqlnr += 1
                    if ($row.DatabaseSpecific) {
                        $sqlfilename = "$Path\$SqlInstance-$dbname-DQ-$number-$queryname-$sqlnr-$Suffix.sql"
                    }
                    else {
                        $sqlfilename = "$Path\$SqlInstance-DQ-$number-$queryname-$sqlnr-$Suffix.sql"
                    }
                    
                    if (!$NoQueryExport)
                    {
					    Write-Message -Level Output -Message "Exporting $sqlfilename"
                        $sql | Out-File -FilePath $sqlfilename
                    }
                }

                $result = $result | Select-Object * -ExcludeProperty "Complete Query Text"
            }

			switch ($ConvertTo) {
				"Excel"
				{
					if ($row.DatabaseSpecific) {
						Write-Message -Level Output -Message "Exporting $exceldbfilename"
						$result | Export-Excel -Path $exceldbfilename -WorkSheetname $Name -AutoSize -AutoFilter -BoldTopRow -FreezeTopRow
					}
					else {
						Write-Message -Level Output -Message "Exporting $excelfilename"
					    $result | Export-Excel -Path $excelfilename -WorkSheetname $Name -AutoSize -AutoFilter -BoldTopRow -FreezeTopRow
					}
				}
				"csv"
				{
					if ($row.DatabaseSpecific) {
						Write-Message -Level Output -Message "Exporting $csvdbfilename"
						$result | Export-Csv -Path $csvdbfilename -NoTypeInformation -Append
					}
					else {
						Write-Message -Level Output -Message "Exporting $csvfilename"
						$result | Export-Csv -Path $csvfilename -NoTypeInformation -Append
					}
				}
			}
		}
	}
}
