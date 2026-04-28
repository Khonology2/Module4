# Flow-Space Backend Environment Variables

This document describes all environment variables used in the Flow-Space backend application.

## Application Configuration

### APP_URL or BASE_URL
**Required for Production**

The base URL of your application. This is used in email links (e.g., invitation acceptance links).

- **Development**: `http://localhost:3000`
- **Staging**: `https://staging.your-domain.com`
- **Production**: `https://your-domain.com`

**Example:**
```env
APP_URL=https://flowspace.example.com
```

## Server Configuration

### PORT
Port on which the backend server runs.
- **Default**: `8000`

### NODE_ENV
Application environment mode.
- **Values**: `development`, `staging`, `production`
- **Default**: `development`

## Database Configuration

### DB_HOST
PostgreSQL database host.
- **Default**: `localhost`

### DB_PORT
PostgreSQL database port.
- **Default**: `5432`

### DB_NAME
PostgreSQL database name.
- **Default**: `flow_space`

### DB_USER
PostgreSQL database username.
- **Default**: `postgres`

### DB_PASSWORD
PostgreSQL database password.
- **Default**: `postgres`

## JWT Configuration

### JWT_SECRET
Secret key for signing JWT tokens. **MUST BE CHANGED IN PRODUCTION**.
- **Default**: `your-super-secret-jwt-key-change-in-production`

### JWT_EXPIRES_IN
JWT token expiration time.
- **Default**: `24h`
- **Examples**: `1h`, `7d`, `30m`

## Email/SMTP Configuration

### SMTP_HOST
SMTP server hostname.
- **Default**: `smtp.gmail.com`
- **Examples**: 
  - Gmail: `smtp.gmail.com`
  - SendGrid: `smtp.sendgrid.net`
  - AWS SES: `email-smtp.us-east-1.amazonaws.com`

### SMTP_PORT
SMTP server port.
- **Default**: `587` (TLS)
- **Alternatives**: `465` (SSL), `25` (non-secure)

### SMTP_SECURE
Whether to use secure connection.
- **Values**: `true`, `false`
- **Default**: `false` (uses STARTTLS on port 587)

### SMTP_USER
SMTP authentication username (usually your email address).
- **Example**: `your-email@gmail.com`

### SMTP_PASS
SMTP authentication password.
- **For Gmail**: Use an [App Password](https://support.google.com/accounts/answer/185833)
- **Example**: `abcd efgh ijkl mnop`

## Example .env File

Create a `.env` file in the `backend` directory with the following content:

```env
# Application
APP_URL=http://localhost:3000
PORT=8000
NODE_ENV=development

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flow_space
DB_USER=postgres
DB_PASSWORD=postgres

# JWT
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRES_IN=24h

# SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-gmail-app-password
```

## Production Deployment Checklist

When deploying to production, ensure you:

1. ✅ Set `APP_URL` to your actual production domain
2. ✅ Change `JWT_SECRET` to a strong random string
3. ✅ Use a secure database password
4. ✅ Configure proper SMTP credentials
5. ✅ Set `NODE_ENV=production`
6. ✅ Review all security-related settings

## Bug Fix: Hardcoded URLs

**Fixed Issue**: The `sendCollaboratorInvitation` method previously used hardcoded `http://localhost:3000` URLs, which would not work in production environments.

**Solution**: The URLs are now configurable via the `APP_URL` or `BASE_URL` environment variables, with a fallback to `http://localhost:3000` for development.

**Impact**: Collaborator invitation emails will now use the correct domain based on your deployment environment.

