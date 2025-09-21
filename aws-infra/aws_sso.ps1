# Windows PowerShell AWS SSO helper for multiple profiles
# Auto logs in, picks a default profile (layered-staging), exports credentials for CLI/Terraform

# ---- SETTINGS ----
# Change this to your desired default profile name (from ~/.aws/config)
$DEFAULT_PROFILE_NAME = "layered-staging-382650357241"
$AUTO_USE_DEFAULT     = $false  # false = always ask which profile

# ---- FUNCTIONS ----
function Need($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Please install $cmd"
        exit 1
    }
}

Need "aws"

# ---- GET ALL PROFILES ----
$allProfiles = aws configure list-profiles | Where-Object { $_ -match "-" }  # only SSO profiles
if (-not $allProfiles) {
    Write-Error "No AWS CLI profiles found in ~/.aws/config"
    exit 1
}

# ---- SELECT PROFILE ----
$chosenProfile = $null
if ($AUTO_USE_DEFAULT -and $allProfiles -contains $DEFAULT_PROFILE_NAME) {
    $chosenProfile = $DEFAULT_PROFILE_NAME
} else {
    Write-Host "🧭 Select an AWS profile:"
    $i = 1
    foreach ($p in $allProfiles) {
        Write-Host (" {0,2}) {1}" -f $i, $p)
        $i++
    }
    do {
        $choice = Read-Host "Enter number"
    } until ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $allProfiles.Count)
    $chosenProfile = $allProfiles[$choice - 1]
}

Write-Host "🔐 AWS SSO Login for profile: $chosenProfile"
aws sso login --profile $chosenProfile | Out-Null

# ---- REGION DETECTION ----
$SSO_REGION = aws configure get sso_region --profile $chosenProfile
if (-not $SSO_REGION) { $SSO_REGION = "eu-central-1" }

# ---- GET ACCOUNT DETAILS ----
$cacheDir = Join-Path $HOME ".aws\sso\cache"
$latestFile = Get-ChildItem $cacheDir -Filter *.json |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$cacheData = Get-Content $latestFile.FullName -Raw | ConvertFrom-Json
$ACCESS_TOKEN = $cacheData.accessToken

$ACCOUNT_ID   = aws configure get sso_account_id --profile $chosenProfile
$ROLE_NAME    = aws configure get sso_role_name --profile $chosenProfile

Write-Host "➡️  Using: $chosenProfile ($ACCOUNT_ID) with role $ROLE_NAME"

# ---- GET TEMPORARY CREDENTIALS ----
$CREDS_JSON = aws sso get-role-credentials `
    --region $SSO_REGION `
    --access-token $ACCESS_TOKEN `
    --account-id $ACCOUNT_ID `
    --role-name $ROLE_NAME `
    --output json | ConvertFrom-Json

$env:AWS_ACCESS_KEY_ID     = $CREDS_JSON.roleCredentials.accessKeyId
$env:AWS_SECRET_ACCESS_KEY = $CREDS_JSON.roleCredentials.secretAccessKey
$env:AWS_SESSION_TOKEN     = $CREDS_JSON.roleCredentials.sessionToken

# ---- EXPIRATION CHECK ----
$expirationEpoch = [int64]$CREDS_JSON.roleCredentials.expiration
$expirationUtc = [DateTimeOffset]::FromUnixTimeMilliseconds($expirationEpoch).UtcDateTime
$nowUtc = [DateTime]::UtcNow
$timeLeft = $expirationUtc - $nowUtc

if ($timeLeft.TotalMinutes -lt 10) {
    Write-Warning "⚠️ AWS session expires in less than 10 minutes! ($([math]::Round($timeLeft.TotalMinutes,2)) min)"
} else {
    Write-Host "✅ AWS session valid for another $([math]::Round($timeLeft.TotalMinutes,2)) minutes."
}

Write-Host ""
Write-Host "✅ Credentials exported."
Write-Host "   Profile : $chosenProfile"
Write-Host "   Account : $ACCOUNT_ID"
Write-Host "   Role    : $ROLE_NAME"
Write-Host "   Region  : $SSO_REGION"
Write-Host ""
Write-Host "Now you can run AWS CLI or Terraform commands in this session."

