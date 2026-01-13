/**
 * Authentication utilities for claude-town-mcp
 *
 * Loads OAuth credentials from the well-known Claude credentials file.
 */

import { readFileSync, existsSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import type { ClaudeCredentials, UserProfile } from "./types.js";

const API_BASE_URL = "https://api.anthropic.com";

/**
 * Get the path to the Claude credentials file
 */
export function getCredentialsPath(): string {
  const home = homedir();
  return join(home, ".claude", ".credentials.json");
}

/**
 * Load credentials from the well-known location
 */
export function loadCredentials(): ClaudeCredentials | null {
  const credentialsPath = getCredentialsPath();

  if (!existsSync(credentialsPath)) {
    return null;
  }

  try {
    const content = readFileSync(credentialsPath, "utf-8");
    return JSON.parse(content) as ClaudeCredentials;
  } catch {
    return null;
  }
}

/**
 * Get the OAuth access token, or throw if not available
 */
export function getAccessToken(): string {
  const credentials = loadCredentials();

  if (!credentials?.claudeAiOauth?.accessToken) {
    throw new Error(
      "Claude Code web sessions require authentication with a Claude.ai account. " +
        "Please run /login in Claude Code to authenticate."
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
