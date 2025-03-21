﻿# Define Variables
$TenantID = "Enter your Tenant ID"
$ClientID = "Enter your Client ID"
$ClientSecret = "Enter client secret"
$RecipientEmail = "admin@test.onmicrosoft.com"
$SenderEmail = "admin@test.onmicrosoft.com"

# Get Access Token
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
    grant_type    = "client_credentials"
    client_id     = $ClientID
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
} -ErrorAction Stop

$AccessToken = $TokenResponse.access_token

# Fetch Disk Utilization using Get-WmiObject
$Drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $TotalSize = [math]::Round($_.Size / 1GB, 2)
    $FreeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
    $UsedSpace = $TotalSize - $FreeSpace
    $Usage = if ($TotalSize -ne 0) { [math]::Round((($UsedSpace / $TotalSize) * 100), 2) } else { 0 }

    [PSCustomObject]@{
        Drive     = $_.DeviceID
        UsedSpace = "$UsedSpace GB"
        FreeSpace = "$FreeSpace GB"
        TotalSize = "$TotalSize GB"
        Usage     = $Usage
    }
} | Where-Object { $_.Usage -ge 20 }

# **Exit if no drives exceed 20% usage**
if (-not $Drives) {
    Write-Host "No drives exceeded 20% usage. Exiting script."
    exit
}

# Construct HTML Table
$TableRows = $Drives | ForEach-Object {
    "<tr>
        <td>$($_.Drive)</td>
        <td>$($_.UsedSpace)</td>
        <td>$($_.FreeSpace)</td>
        <td>$($_.TotalSize)</td>
        <td style='color:red; font-weight:bold;'>$($_.Usage)%</td>
    </tr>"
}

# Construct HTML Body with Fixed Logo Size
$HTMLBody = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
        .container { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0, 0, 0, 0.1); border-left: 5px solid #0078D4; }
        .header { text-align: center; padding: 10px 0; }
        .header img { width: 150px; } /* atQor Logo Size */
        .alert { color: #d9534f; font-size: 18px; font-weight: bold; text-align: center; }
        .content { padding: 15px; font-size: 14px; color: #333; line-height: 1.6; }
        .highlight { color: #0078D4; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0078D4; color: white; }
        .footer { text-align: center; font-size: 12px; color: #666; padding-top: 10px; }
        .footer img { display: block; margin: 10px auto; width: 150px; height: auto; } /* Explicitly set width */
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <img src='https://www.atqor.com/media/4rbg4j3o/logo-atqor.png' alt='atQor Logo'>
        </div>

        <p class='alert'>High Disk Usage Alert</p>

        <div class='content'>
            <p><strong>Virtual Machine Name:</strong> <span class='highlight'>Secopslab-VM</span></p>
            <p><strong>IP Address:</strong> <span class='highlight'>10.0.0.4</span></p>
            <p>The following drives have exceeded the <b>20%</b> usage threshold:</p>
            <table>
                <tr>
                    <th>Drive</th>
                    <th>Used Space (GB)</th>
                    <th>Free Space (GB)</th>
                    <th>Total Size (GB)</th>
                    <th>Usage (%)</th>
                </tr>
                $TableRows
            </table>
            <p>Please free up space or investigate the issue.</p>
        </div>

        <div class='footer'>
            <p>Microsoft Azure | atQor</p>
            <img src='https://www.atqor.com/media/qkhbzliv/microsoftsolutionspartner-msinfrastructureazure.png' alt='Microsoft Azure Logo'>
        </div>
    </div>
</body>
</html>
"@

# Create JSON Email Body
$EmailBody = @{
    message = @{
        subject = "High Disk Usage Alert"
        body = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
        toRecipients = @(@{
            emailAddress = @{
                address = $RecipientEmail
            }
        })
    }
} | ConvertTo-Json -Depth 10

# Graph API Endpoint
$GraphUri = "https://graph.microsoft.com/v1.0/users/$SenderEmail/sendMail"

# Headers
$Headers = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# Send Email & Handle Errors
try {
    Invoke-RestMethod -Uri $GraphUri -Headers $Headers -Method Post -Body $EmailBody -ErrorAction Stop
    Write-Host "Email sent successfully to $RecipientEmail."
} catch {
    Write-Host "Failed to send email. Error: $_"
}
