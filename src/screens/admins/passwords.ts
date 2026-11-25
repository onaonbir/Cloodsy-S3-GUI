// The server's admin password policy (admin/admin.go validatePassword): at
// least 8 characters and at most 72 bytes, bcrypt's input limit. The server
// counts bytes for both; counting characters for the minimum is never looser.

export const MIN_PASSWORD_LENGTH = 8;
export const MAX_PASSWORD_BYTES = 72;

const encoder = new TextEncoder();

export const utf8Length = (s: string) => encoder.encode(s).length;

/** 'short' / 'long' when the password breaks the policy, else null. */
export function passwordProblem(password: string): 'short' | 'long' | null {
  if ([...password].length < MIN_PASSWORD_LENGTH) return 'short';
  if (utf8Length(password) > MAX_PASSWORD_BYTES) return 'long';
  return null;
}

/** A created admin or a reset password, as the server returned it (shown once). */
export interface PasswordResult { username: string; password: string; generated: boolean }

/** The server's answer to POST /admins or PUT /admins/{u}/password; it may leave out what it was given. */
export function toPasswordResult(
  answer: { username?: string; password?: string; auto_generated?: boolean } | null | undefined,
  username: string,
  requested: string,
): PasswordResult {
  return {
    username: answer?.username || username,
    password: answer?.password || requested,
    generated: answer?.auto_generated === true,
  };
}
