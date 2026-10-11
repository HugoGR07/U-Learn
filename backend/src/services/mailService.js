const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

exports.sendMail = (to, subject, html) =>
  transporter.sendMail({ from: `"U-Learn" <${process.env.SMTP_USER}>`, to, subject, html });