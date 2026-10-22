export type Mail = { to: string; subject: string; text: string };
export type SendMail = (mail: Mail) => Promise<void>;

// Until a transactional provider is wired in (phase F6), mails are printed to the
// server console in development and refused in production, so a deploy without
// a provider fails loudly instead of silently dropping verification links.
export const sendMail: SendMail = async (mail) => {
  if (process.env.NODE_ENV === "production") {
    throw new Error("Mail provider not configured");
  }
  console.info(`[mail] to=${mail.to} subject="${mail.subject}"\n${mail.text}`);
};
