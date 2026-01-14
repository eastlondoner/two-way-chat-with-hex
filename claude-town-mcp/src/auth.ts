/**
 * Authentication utilities for claude-town-mcp
 *
 * Loads OAuth credentials from well-known Claude credentials locations.
 * Supports both CLI credentials and desktop app credentials.
 */

import { readFileSync, existsSync } from "fs";
import { homedir, platform } from "os";
import { join } from "path";
import type { ClaudeCredentials, UserProfile } from "./types.js";

const API_BASE_URL = "https://api.anthropic.com";

/**
 * Get all possible credential file paths in priority order
 */
export function getCredentialsPaths(): string[] {
  const home = homedir();
  const paths: string[] = [];

  // Primary: CLI credentials (works on all platforms)
  paths.push(join(home, ".claude", ".credentials.json"));

  // Secondary: Desktop app config on macOS
  if (platform() === "darwin") {
    paths.push(join(home, "Library", "Application Support", "Claude", "config.json"));
  }

  return paths;
}

/**
 * Get the path to the Claude credentials file (primary location)
 */
export function getCredentialsPath(): string {
  const home = homedir();
  return join(home, ".claude", ".credentials.json");
}

/**
 * Try to load credentials from the desktop app config
 * The token is stored encrypted, so we can only use it if there's also
 * a plaintext token available (which there usually isn't)
 */
function loadDesktopAppCredentials(configPath: string): ClaudeCredentials | null {
  if (!existsSync(configPath)) {
    return null;
  }

  try {
    const content = readFileSync(configPath, "utf-8");
    const config = JSON.parse(content);

    // Desktop app stores token under "oauth:tokenCache" key, encrypted
    const tokenCache = config["oauth:tokenCache"];
    if (tokenCache && typeof tokenCache === "string") {
      // Token is encrypted (starts with version prefix like "djEw")
      // We cannot decrypt it without access to the app's keychain
      // Return null to indicate we found credentials but can't use them
      return null;
    }

    return null;
  } catch {
    return null;
  }
}

/**
 * Load credentials from the well-known locations
 * Tries CLI credentials first, then desktop app
 */
export function loadCredentials(): ClaudeCredentials | null {
  const paths = getCredentialsPaths();

  for (const credentialsPath of paths) {
    if (!existsSync(credentialsPath)) {
      continue;
    }

    // Handle desktop app config differently
    if (credentialsPath.includes("Application Support")) {
      const desktopCreds = loadDesktopAppCredentials(credentialsPath);
      if (desktopCreds) {
        return desktopCreds;
      }
      continue;
    }

    // CLI credentials - plaintext JSON
    try {
      const content = readFileSync(credentialsPath, "utf-8");
      return JSON.parse(content) as ClaudeCredentials;
    } catch {
      continue;
    }
  }

  return null;
}

/**
 * Check if desktop app credentials exist but are encrypted
 */
function hasEncryptedDesktopCredentials(): boolean {
  if (platform() !== "darwin") {
    return false;
  }

  const configPath = join(homedir(), "Library", "Application Support", "Claude", "config.json");
  if (!existsSync(configPath)) {
    return false;
  }

  try {
    const content = readFileSync(configPath, "utf-8");
    const config = JSON.parse(content);
    const tokenCache = config["oauth:tokenCache"];
    return tokenCache && typeof tokenCache === "string" && tokenCache.startsWith("djE");
  } catch {
    return false;
  }
}

/**
 * Get the OAuth access token, or throw if not available
 */
export function getAccessToken(): string {
  const credentials = loadCredentials();

  if (!credentials?.claudeAiOauth?.accessToken) {
    // Check if user has desktop app credentials that we can't use
    if (hasEncryptedDesktopCredentials()) {
      throw new Error(
        "Found Claude desktop app credentials, but they are encrypted. " +
          "Please run Claude Code CLI and use /login to create plaintext credentials at ~/.claude/.credentials.json"
      );
    }

    throw new Error(
      "Claude Code web sessions require authentication with a Claude.ai account. " +
        "Please run /login in Claude Code CLI to authenticate."
    );
  }

  // Check if token is expired
  const expiresAt = credentials.claudeAiOauth.expiresAt;
  if (expiresAt && Date.now() > expiresAt) {
    throw new Error(
      "OAuth token has expired. Please run /login in Claude Code to re-authenticate."
    );
  }

  return credentials.claudeAiOauth.accessToken;
}

/**
 * Get the standard headers for API requests
 */
export function getAuthHeaders(accessToken: string): Record<string, string> {
  return {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
    "anthropic-version": "2023-06-01",
  };
}

/**
 * Cached organization UUID to avoid repeated API calls
 */
let cachedOrgUUID: string | null = null;
let cachedAccessToken: string | null = null;

/**
 * Fetch the user profile to get the organization UUID
 */
export async function fetchUserProfile(
  accessToken: string
): Promise<UserProfile> {
  const response = await fetch(`${API_BASE_URL}/api/oauth/profile`, {
    method: "GET",
    headers: getAuthHeaders(accessToken),
  });

  if (!response.ok) {
    if (response.status === 401) {
      throw new Error(
        "OAuth token is invalid or expired. Please run /login in Claude Code."
      );
    }
    throw new Error(`Failed to fetch user profile: ${response.statusText}`);
  }

  return (await response.json()) as UserProfile;
}

/**
 * Get the organization UUID, fetching it if not cached
 */
export async function getOrganizationUUID(accessToken: string): Promise<string> {
  // Return cached value if token hasn't changed
  if (cachedOrgUUID && cachedAccessToken === accessToken) {
    return cachedOrgUUID;
  }

  const profile = await fetchUserProfile(accessToken);
  cachedOrgUUID = profile.organization.uuid;
  cachedAccessToken = accessToken;

  return cachedOrgUUID;
}

/**
 * Get auth context with both access token and org UUID
 */
export interface AuthContext {
  accessToken: string;
  orgUUID: string;
}

export async function getAuthContext(): Promise<AuthContext> {
  const accessToken = getAccessToken();
  const orgUUID = await getOrganizationUUID(accessToken);
  return { accessToken, orgUUID };
}
