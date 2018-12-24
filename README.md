# Onboarding

This script was created for a hybrid environment with on-prem AD and email through O365.
	*Creates AD account with the format: [first initial][last name]
	    *If username already taken in AD, adds a "2" to the end of it, IE: JSmith2 in the event there are x2 John Smith users, JSmith3 if  there are 3x, etc.
	*Sets a temporary password for that account
	*Fills in all attributes of a user by department
	*Creates a new home drive for that user
	*Adds that user to all necessary security groups for their department
	*Asks if this user needs an email address, and if so, creates an O365 account and assigns it an O365 Business Premium license
	    *Adds that user to all necessary email distribution lists and O365 groups for that dept

--Have noticed some strange errors if PowerShell is not being run as administrator
--Seems to work fine being run locally on a system with RSAT installed
