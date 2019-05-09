<#
	.ONBOARDING SCRIPT
	
	.FUNCTIONALITY
	This script performs the following:
	*Creates AD account with the format: [first initial][last name]
		**If username already taken in AD, adds a "2" to the end of it, IE: JSmith2 in the event there are x2 John Smith users, JSmith3 if there are 3x, etc.
	*Sets a temporary password for that account
	*Fills in all attributes of a user by department
	*Creates a new home drive for that user
	*Adds that user to all necessary security groups for their department
	*Asks if this user needs an email address, and if so, creates an O365 account and assigns it an O365 Business Premium license
		**Adds that user to all necessary email distribution lists and O365 groups for that dept
#>

<# 
TO DO:
    -Model after user - currently defaults to one directory, need to make it mirror same OU as the user copying from
    -Model after user - copy same email groups as the user copying from
#>

function Create-Email {
    $emailAddress = $userName + "@Contoso.com"
    $UserCredential = Get-Credential
	$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
	Import-PSSession $Session -DisableNameChecking
	Connect-MsolService -Credential $UserCredential
	
	New-MsolUser -DisplayName $fullName -FirstName $firstName -LastName $lastName -UserPrincipalName $emailAddress `
    -UsageLocation US -LicenseAssignment Contosocompany:O365_BUSINESS_PREMIUM -Password "Password123" -ForceChangePassword $true
    
    switch($employeeType) {
        1 {
            Start-Sleep -Seconds 180
            Set-MsolUser -UserPrincipalName $emailAddress -Department "Customer Service" -City "Philadelphia" -Title "Customer Service Specialist"
			"Contoso-Philadelphia","CustomerServiceTeam" | Add-DistributionGroupMember -Member $emailAddress
            Add-UnifiedGroupLinks -Identity "CustomerServiceO365Group" -LinkType Members -Links $emailAddress
        }
        2 {
            Start-Sleep -Seconds 180
            Set-MsolUser -UserPrincipalName $emailAddress -Department "Customer Service" -City "Philadelphia" -Title "Tech Advisor"
			"Contoso-Philadelphia","CustomerServiceTeam" | Add-DistributionGroupMember -Member $emailAddress
            "CustomerServiceO365Group","Tech365Group" | Add-UnifiedGroupLinks -LinkType Members -Links $emailAddress
        }
    }
    # Email distribution lists that all employees are meant to be added to
    "CompanyWideDistro", "CompanyWideDistro2" | Add-DistributionGroupMember -Member $emailAddress
    Get-PSSession | Remove-PSSession
}

function Create-Directory {
	$HomeDrive = 'Z:'
	$UserRoot = '\\fileServer\Users$\'
	$HomeDirectory = $UserRoot+$userName
	Set-ADUser $userName -HomeDrive $HomeDrive -HomeDirectory $HomeDirectory
	New-Item -Path $HomeDirectory -Type Directory -Force
}
# Creates users's home folder on the network share drive

Write-Host "Select employee type: `n 1: Customer Service `n 2: Tech Advisor `n 3: Warehouse `n 4: Retail `n 5: Model After User `n"
$employeeType = Read-Host -Prompt 'Enter employee type'
# Prompts to select the user's department

$firstName = Read-Host -Prompt 'Enter first name '
$lastName = Read-Host -Prompt 'Enter last name '
$fullName = $firstName + " " + $lastName
$userName = $firstName.Substring(0,1)+$lastname
# Creates username with the "first Initial, last name" format.  Tom Smith = TSmith

<#
    USERNAME CHECK
    The loop below checks if $userName already exists in AD.
    If it does exist, $userExist has a value of TRUE and initiates a loop which appends a "1" to $userName.
    It then performs a second check to see if $userName + 1 exists in AD.
    If that name is still taken, the number is taken off the end of $userName, and the loop repeats with "2" appended, etc.
#>
$userSuffix = 1
$userExists = [bool] (Get-ADUser -Filter { SamAccountName -eq $userName })
while ($userExists -eq $true) {
    $userName = $userName + $userSuffix
    $userSuffix++
    $userExists = [bool] (Get-ADUser -Filter { SamAccountName -eq $userName })
    if ($userExists -eq $true) {
		$userName = $userName -replace ".$"
		# This removes the last character of $userName (the number.) Otherwise you end up with "$userName" + 12 instead of "$userName" + 2.
    }
}

$password = "Temp1234" | ConvertTo-SecureString -AsPlainText -Force
$email = Read-Host -Prompt 'User receiving an email address? (Y/N) '

if ($email -eq 'Y') {
	Create-Email
}

New-ADUser -UserPrincipalName $userName -SamAccountName $userName -Name $fullName -GivenName $firstName -Surname $lastName `
-AccountPassword $password -ChangePasswordAtLogon $True -Enabled $True

switch ($employeeType) {
	# CUSTOMER SERVICE
	1 {
		Set-ADUser -Identity $userName -Office "Philadelphia" -Department "Customer Service" -DisplayName $fullName -Title "Customer Service Specialist" -Manager bossman
		Get-ADUser $userName | Move-ADObject -TargetPath "OU=Customer Service-Philadelphia,OU=Contoso Users,DC=Contoso,DC=com"

		"CustomerServiceGroup1","CustomerServiceGroup2" | Add-ADGroupMember -Members $userName
	
		Create-Directory
	}

	# TECH ADVISOR
	2 {
		Set-ADUser -Identity $userName -Office "Philadelphia" -Department "Customer Service" -DisplayName $fullName -Title "Customer Service Tech Advisor" -Manager bossman
		Get-ADUser $userName | Move-ADObject -TargetPath "OU=Customer Service-Philadelphia,OU=Contoso Users,DC=Contoso,DC=com"

		"CustomerServiceGroup1","TechGroup1" | Add-ADGroupMember -Members $userName
	
		Create-Directory
	}

	# WAREHOUSE
	3 {
		Set-ADUser -Identity $userName -Office "Philadelphia" -DisplayName $fullName -Manager wwhiteley
		Get-ADUser $userName | Move-ADObject -TargetPath "OU=Warehouse-Philadelphia,OU=Contoso Users,DC=Contoso,DC=com"
	}

	# RETAIL
	4 {
        $store = Read-Host -Prompt "Enter store (Philadelphia/LA/Chicago/NYC) "
        switch ($store) {
            "Philadelphia" {
                Set-ADUser -Identity $userName -Office "Philadelphia" -DisplayName $fullName -Manager jfuller
                Get-ADUser $userName | Move-ADObject -TargetPath "OU=Retail Store Personnel - Philadelphia,OU=Contoso Users,DC=Contoso,DC=com"
            }
            "LA" {
                Set-ADUser -Identity $userName -Office "LA" -DisplayName $fullName -Manager bossman2
                Get-ADUser $userName | Move-ADObject -TargetPath "OU=Retail Store Personnel - LA,OU=Contoso Users,DC=Contoso,DC=com"
            }
            "Chicago" {
                Set-ADUser -Identity $userName -Office "Chicago" -DisplayName $fullName -Manager bosslady
                Get-ADUser $userName | Move-ADObject -TargetPath "OU=Retail Store Personnel - Chicago,OU=Contoso Users,DC=Contoso,DC=com"
            }
            "NYC" {
                Set-ADUser -Identity $userName -Office "NYC" -DisplayName $fullName
                Get-ADUser $userName | Move-ADObject -TargetPath "OU=Retail Store Personnel - NYC,OU=Contoso Users,DC=Contoso,DC=com"
            }
        }
		Add-ADGroupMember -Identity RetailGroup -Members $userName
	}

	# MODEL AFTER USER
	default {
        $copyFromUser = Read-Host -Prompt "Enter username to copy access from"
        $copyProp = Get-ADUser -Identity $copyFromUser -Properties MemberOf
        $toProp = Get-ADUser -Identity $userName -Properties MemberOf
        $copyProp.MemberOf | Where-Object {$toProp.MemberOf -notcontains $_} | Add-ADGroupMember -Members $toProp
        # Prompts you to type in the username of someone to copy access from.  Adds new user to all groups of original user.
        
		Set-ADUser -Identity $userName -Office "Philadelphia" -DisplayName $fullName
		Get-ADUser $userName | Move-ADObject -TargetPath "OU=Office Personnel,OU=Contoso Users,DC=Contoso,DC=com"
		
		Create-Directory
	}
}

# Groups that are meant to be accessed by all employees
"CommonGroup1","CommonGroup2" | Add-ADGroupMember -Members $userName
