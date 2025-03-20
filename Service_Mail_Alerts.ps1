# Define Variables
$TenantID = "Enter your Tenant ID"
$ClientID = "Enter your Client ID"
$ClientSecret = "Enter client secret"
$ServiceName = "sshd"
$RecipientEmail = "admin@test.onmicrosoft.com"
$SenderEmail = "admin@test.onmicrosoft.com"
$VMName = "Secops-LAB-VM"
$IPAddress = "10.0.0.4"

# Get Access Token
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
    grant_type    = "client_credentials"
    client_id     = $ClientID
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
}

$AccessToken = $TokenResponse.access_token

# Check SSH Service Status
$ServiceStatus = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($ServiceStatus -eq $null) {
    Write-Host "Service $ServiceName not found. Exiting."
    exit
}

if ($ServiceStatus.Status -eq "Stopped") {
    # Restart SSH Service
    Restart-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 5  
    $NewStatus = Get-Service -Name $ServiceName

    # Email Body with Embedded HTML & CSS
    $EmailBody = @"
{
    "message": {
        "subject": "Alert: SFTP Service Found in Stopped State",
        "body": {
            "contentType": "HTML",
            "content": "<!DOCTYPE html>
                        <html>
                        <head></head>
                        <body style='font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 0;'>
                            <div style='width: 100%; max-width: 100%; margin: 20px auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0, 0, 0, 0.1); border-left: 5px solid #0078D4;'>
                                
                                <!-- Header with Logo -->
                                <div style='text-align: center; padding: 10px 0;'>
                                    <img src='https://www.atqor.com/media/4rbg4j3o/logo-atqor.png' alt='Microsoft Azure Logo' style='width: 150px;'>
                                </div>
                                
                                <!-- Alert Heading -->
                                <p style='color: #d9534f; font-size: 18px; font-weight: bold; text-align: center;'>SFTP Service Alert</p>

                                <!-- Email Content -->
                                <div style='padding: 15px; font-size: 14px; color: #333; line-height: 1.6;'>
                                    <p><strong>VM Name:</strong> <span style='color: #0078D4; font-weight: bold;'>$VMName</span></p>
                                    <p><strong>IP Address:</strong> <span style='color: #0078D4; font-weight: bold;'>$IPAddress</span></p>
                                    <p>The SFTP service <strong>$ServiceName</strong> was found in <strong>Stopped</strong> state.</p>
                                    <p>The Service has been <span style='color: #0078D4; font-weight: bold;'>Restarted</span>. Please check.</p>
                                </div>

                                <!-- Footer -->
                                <div style='text-align: center; font-size: 12px; color: #666; padding-top: 10px;'>
                                    <p>Microsoft Azure | atQor</p>
                                    <img src='https://www.atqor.com/media/qkhbzliv/microsoftsolutionspartner-msinfrastructureazure.png' alt='Microsoft Azure Partner' style='display: block; margin: 10px auto; max-width: 150px;'>
                                </div>
                            </div>
                        </body>
                        </html>"
        },
        "toRecipients": [
            {
                "emailAddress": {
                    "address": "$RecipientEmail"
                }
            }
        ]
    }
}
"@

    # API Endpoint (Use 'users/{email}' for service principal)
    $GraphUri = "https://graph.microsoft.com/v1.0/users/$SenderEmail/sendMail"

    # Headers
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
        "Accept"        = "application/json"
    }

    # Send Email
    Invoke-RestMethod -Uri $GraphUri -Headers $Headers -Method Post -Body $EmailBody

    Write-Host "Service was stopped and restarted. Email sent to $RecipientEmail."
} else {
    Write-Host "Service $ServiceName is already running. No action needed."
}
