# Email Marketing Setup Guide

## Overview
The app now integrates with email marketing services to automatically add subscribers to your email list. Subscribers are saved to both Firebase (as backup) and your chosen email service.

## Supported Services

### 1. Mailchimp (Recommended)
- **Free tier**: Up to 2,000 contacts
- **Best for**: General email marketing, automation, and campaigns
- **Dashboard**: https://mailchimp.com

### 2. ConvertKit
- **Free tier**: Up to 1,000 subscribers
- **Best for**: Content creators, course creators
- **Dashboard**: https://convertkit.com

### 3. SendGrid
- **Free tier**: 100 emails/day
- **Best for**: Transactional + marketing emails
- **Dashboard**: https://sendgrid.com

## Setup Instructions

### Step 1: Choose Your Service
1. Sign up for your preferred email service
2. Create an audience/list in your service's dashboard

### Step 2: Get API Credentials

#### For Mailchimp:
1. Go to Account → Extras → API keys
2. Create a new API key
3. Find your List ID: Audience → Settings → Audience name and defaults
4. Note your data center (e.g., us1, us2) from your Mailchimp URL

#### For ConvertKit:
1. Go to Settings → Advanced → API
2. Copy your API Secret
3. Create a form and copy its ID from the URL

#### For SendGrid:
1. Go to Settings → API Keys
2. Create a new API key with "Marketing" permissions
3. Go to Marketing → Contacts → Lists
4. Create a list and copy its ID

### Step 3: Configure the App

1. Copy `EmailConfig-Template.plist` to `EmailConfig.plist`
2. Add your API credentials to `EmailConfig.plist`
3. Never commit `EmailConfig.plist` to Git (it's already in .gitignore)

### Step 4: Test the Integration

1. Run the app
2. Go to Profile → Emails
3. Submit a test email
4. Check your email service dashboard to confirm the subscriber was added

## Features

### What Gets Captured:
- Email address
- First name (optional)
- Source (ios_app, ios_app_profile)
- Timestamp
- App version
- Platform (iOS)

### In Your Email Service Dashboard:
- View all subscribers
- Create segments (iOS users, new users, etc.)
- Send email campaigns
- Set up automation workflows
- Track open rates and engagement
- Export subscriber lists

## Firebase Backup
All emails are also saved to Firebase Firestore in the `email_list` collection as a backup.

## Troubleshooting

### Email not appearing in service:
1. Check API credentials in EmailConfig.plist
2. Check console logs for error messages
3. Verify the email isn't already subscribed
4. Check your email service's API status

### Common Errors:
- "Email service not configured": Add your API keys to EmailConfig.plist
- "Invalid email address": Ensure valid email format
- "API error": Check your API key permissions and rate limits

## Best Practices

1. **Welcome Email**: Set up an automation in your email service to send a welcome email
2. **Double Opt-in**: Enable in your email service for GDPR compliance
3. **Segments**: Create segments for iOS users to send targeted content
4. **Regular Engagement**: Send weekly encouragement emails as promised
5. **Monitor Metrics**: Track open rates and adjust content accordingly

## Security Notes

- API keys are stored locally in EmailConfig.plist
- Never commit API keys to version control
- For production, consider using:
  - Firebase Remote Config for API keys
  - iOS Keychain for secure storage
  - Environment variables in CI/CD

## Support

For email service-specific help:
- Mailchimp: https://mailchimp.com/help/
- ConvertKit: https://help.convertkit.com/
- SendGrid: https://docs.sendgrid.com/