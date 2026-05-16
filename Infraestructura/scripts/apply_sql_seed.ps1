param(
    [string]$Host = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Db = "postgres",
    [string]$Password = "",
    [string]$SqlFile = "..\dataTest\bd_app_schema.sql"
)

if ($Password -ne "") {
    $env:PGPASSWORD = $Password
}

Write-Host "Applying SQL seed $SqlFile to $User@$Host:$Port/$Db"
pSQL -h $Host -p $Port -U $User -d $Db -f $SqlFile
