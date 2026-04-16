const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT) || 587,
      secure: process.env.SMTP_SECURE === 'true' || false,
      auth: {
        user: process.env.SMTP_USER,
        pass: (process.env.SMTP_PASS || '').replace(/\s+/g, '')
      },
      connectionTimeout: parseInt(process.env.SMTP_CONNECTION_TIMEOUT_MS || '10000', 10),
      greetingTimeout: parseInt(process.env.SMTP_GREETING_TIMEOUT_MS || '10000', 10),
      socketTimeout: parseInt(process.env.SMTP_SOCKET_TIMEOUT_MS || '15000', 10),
      tls: {
        rejectUnauthorized: false
      }
    });
    this.fromName = process.env.SMTP_FROM_NAME || process.env.EMAIL_FROM_NAME || 'Flownet Workspaces';
    this.fromEmail = process.env.SMTP_FROM_EMAIL || process.env.EMAIL_FROM_ADDRESS || process.env.SMTP_USER;
    this.replyTo = process.env.EMAIL_REPLY_TO || this.fromEmail;
  }

  async testConnection() {
    try {
      await this.transporter.verify();
      return true;
    } catch (error) {
      return false;
    }
  }

  async sendVerificationEmail(toEmail, userName, verificationCode) {
    try {
      const mailOptions = {
        from: {
          name: this.fromName,
          address: this.fromEmail
        },
        to: toEmail,
        subject: 'Verify Your Email - Flownet Workspaces',
        html: this.buildVerificationEmailHtml(userName, verificationCode),
        replyTo: this.replyTo
      };

      const result = await this.transporter.sendMail(mailOptions);
      return { success: true, messageId: result.messageId };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async sendPasswordResetEmail(toEmail, userName, resetLink) {
    try {
      const mailOptions = {
        from: {
          name: this.fromName,
          address: this.fromEmail
        },
        to: toEmail,
        subject: 'Reset Your Password - Flownet Workspaces',
        html: this.buildPasswordResetEmailHtml(userName, resetLink),
        replyTo: this.replyTo
      };

      const result = await this.transporter.sendMail(mailOptions);
      return { success: true, messageId: result.messageId };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  buildVerificationEmailHtml(userName, verificationCode) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verification</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f4f4f4; }
        .container { background-color: #ffffff; border-radius: 10px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 300; }
        .content { padding: 40px 30px; }
        .verification-code { background-color: #f8f9fa; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0; }
        .verification-code h2 { color: #667eea; margin: 0; font-size: 32px; letter-spacing: 3px; font-family: 'Courier New', monospace; }
        .instructions { background-color: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 20px 0; }
        .security-note { background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; color: #856404; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
    </style>
}</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome to Flownet Workspaces</h1>
        </div>
        <div class="content">
            <h2>Verify Your Email Address</h2>
            <p>Hi <strong>${userName}</strong>,</p>
            <p>Use the code below to verify your email address:</p>
            <div class="verification-code">
                <h2>${verificationCode}</h2>
            </div>
            <div class="instructions">
                <h3>Instructions:</h3>
                <ol>
                    <li>Copy the verification code above</li>
                    <li>Return to the app</li>
                    <li>Enter the code in the verification screen</li>
                </ol>
            </div>
            <div class="security-note">
                This code will expire in 15 minutes.
            </div>
            <p>Best regards,<br><strong>The Flownet Workspaces Team</strong></p>
        </div>
        <div class="footer">
            <p>© ${new Date().getFullYear()} Flownet Workspaces</p>
        </div>
    </div>
</body>
</html>
    `;
  }

  buildPasswordResetEmailHtml(userName, resetLink) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f4f4f4; }
        .container { background-color: #ffffff; border-radius: 10px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%); color: white; padding: 30px; text-align: center; }
        .content { padding: 40px 30px; }
        .button { display: inline-block; background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; font-weight: bold; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
    </style>
}</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Password Reset Request</h1>
        </div>
        <div class="content">
            <h2>Reset Your Password</h2>
            <p>Hi <strong>${userName}</strong>,</p>
            <p>We received a request to reset your password.</p>
            <a href="${resetLink}" class="button">Reset Password</a>
            <p>If the button doesn't work, copy and paste this link:<br>${resetLink}</p>
            <p>Best regards,<br><strong>The Flownet Workspaces Team</strong></p>
        </div>
        <div class="footer">
            <p>© ${new Date().getFullYear()} Flownet Workspaces</p>
        </div>
    </div>
</body>
</html>
    `;
  }

  async sendApprovalRequestEmail(toEmail, recipientName, deliverableTitle, requestedByName) {
    try {
      const subject = 'Approval Request: ' + (deliverableTitle || 'Deliverable');
      const html = `<!DOCTYPE html>
<html><body>
  <p>Hi ${recipientName || ''},</p>
  <p>${requestedByName || 'A delivery lead'} has sent an approval request for <strong>${deliverableTitle || 'a deliverable'}</strong>.</p>
  <p>Please log in to Flownet Workspaces to review and approve.</p>
  <p>Best regards,<br/>Flownet Workspaces</p>
</body></html>`;
      const mailOptions = {
        from: { name: this.fromName, address: this.fromEmail },
        to: toEmail,
        subject,
        html,
        replyTo: this.replyTo
      };
      const result = await this.transporter.sendMail(mailOptions);
      return { success: true, messageId: result.messageId };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async sendApprovalReminderEmail(toEmail, recipientName, deliverableTitle, reportTitle) {
    try {
      const subject = 'Reminder: Approval Pending';
      const html = `<!DOCTYPE html>
<html><body>
  <p>Hi ${recipientName || ''},</p>
  <p>This is a reminder that approval is pending for <strong>${deliverableTitle || 'a deliverable'}</strong>${reportTitle ? ` and report <strong>${reportTitle}</strong>` : ''}.</p>
  <p>Please log in to Flownet Workspaces to review.</p>
  <p>Best regards,<br/>Flownet Workspaces</p>
</body></html>`;
      const mailOptions = {
        from: { name: this.fromName, address: this.fromEmail },
        to: toEmail,
        subject,
        html,
        replyTo: this.replyTo
      };
      const result = await this.transporter.sendMail(mailOptions);
      return { success: true, messageId: result.messageId };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

module.exports = EmailService;
