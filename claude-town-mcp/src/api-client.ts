/**
 * Claude Code Sessions API client
 *
 * Implements the undocumented Claude Code web sessions API.
 */

import { randomUUID } from "crypto";
import { getAuthHeaders, type AuthContext } from "./auth.js";
import type {
  Session,
  SessionsListResponse,
  SessionSummary,
  SendEventsRequest,
} from "./types.js";

const API_BASE_URL = "https://api.anthropic.com";

/**
 * Retry configuration for API requests
 */
const RETRY_DELAYS = [2000, 4000, 8000, 16000];
const MAX_RETRIES = RETRY_DELAYS.length;

/**
 * Check if an error is retryable (network or server error)
 */
function isRetryableError(response: Response): boolean {
  return response.status >= 500;
}

/**
 * Sleep for a given number of milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Make an API request with retry logic
 */
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  retries = MAX_RETRIES
): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options);

      if (response.ok || !isRetryableError(response)) {
        return response;
      }

      // Server error, retry if we have retries left
      if (attempt < retries) {
        const delay = RETRY_DELAYS[attempt] ?? 2000;
        await sleep(delay);
        continue;
      }

      return response;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      if (attempt < retries) {
        const delay = RETRY_DELAYS[attempt] ?? 2000;
        await sleep(delay);
        continue;
      }
    }
  }

  throw lastError ?? new Error("Request failed after retries");
}

/**
 * Get headers with organization UUID
 */
function getFullHeaders(auth: AuthContext): Record<string, string> {
  return {
    ...getAuthHeaders(auth.accessToken),
    "x-organization-uuid": auth.orgUUID,
  };
}

/**
 * Extract session summary from full session object
 */
function toSessionSummary(session: Session): SessionSummary {
  const source = session.session_context.sources.find(
    (s) => s.type === "git_repository"
  );
  const outcome = session.session_context.outcomes.find(
    (o) => o.type === "git_repository"
  );

  let repo: string | null = null;
  if (source?.url) {
    // Extract owner/name from GitHub URL
    const match = source.url.match(/github\.com[:/]([^/]+\/[^/]+?)(?:\.git)?$/);
    if (match) {
      repo = match[1] ?? null;
    }
  }

  const branch = outcome?.git_info?.branches[0] ?? null;

  return {
    id: session.id,
    title: session.title,
    status: session.session_status,
    repo,
    branch,
    created_at: session.created_at,
    updated_at: session.updated_at,
  };
}

/**
 * List all sessions
 */
export async function listSessions(auth: AuthContext): Promise<SessionSummary[]> {
  const response = await fetchWithRetry(`${API_BASE_URL}/v1/sessions`, {
    method: "GET",
    headers: getFullHeaders(auth),
  });

  if (!response.ok) {
    if (response.status === 401) {
      throw new Error("Session expired. Please run /login to sign in again.");
    }
    throw new Error(`Failed to list sessions: ${response.statusText}`);
  }

  const data = (await response.json()) as SessionsListResponse;
  return data.data.map(toSessionSummary);
}

/**
 * Get a specific session by ID
 */
export async function getSession(
  auth: AuthContext,
  sessionId: string
): Promise<Session> {
  const response = await fetchWithRetry(
    `${API_BASE_URL}/v1/sessions/${sessionId}`,
    {
      method: "GET",
      headers: getFullHeaders(auth),
    }
  );

  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Session not found: ${sessionId}`);
    }
    if (response.status === 401) {
      throw new Error("Session expired. Please run /login to sign in again.");
    }
    throw new Error(`Failed to get session: ${response.statusText}`);
  }

  return (await response.json()) as Session;
}

/**
 * Send a message to a session
 */
export async function sendMessage(
  auth: AuthContext,
  sessionId: string,
  message: string
): Promise<boolean> {
  const event: SendEventsRequest = {
    events: [
      {
        uuid: randomUUID(),
        session_id: sessionId,
        type: "user",
        parent_tool_use_id: null,
        message: {
          role: "user",
          content: message,
        },
      },
    ],
  };

  const response = await fetchWithRetry(
    `${API_BASE_URL}/v1/sessions/${sessionId}/events`,
    {
      method: "POST",
      headers: getFullHeaders(auth),
      body: JSON.stringify(event),
    }
  );

  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Session not found: ${sessionId}`);
    }
    if (response.status === 401) {
      throw new Error("Session expired. Please run /login to sign in again.");
    }
    throw new Error(`Failed to send message: ${response.statusText}`);
  }

  return true;
}

/**
 * Poll session status until it reaches a target state or timeout
 */
export async function waitForSessionStatus(
  auth: AuthContext,
  sessionId: string,
  targetStatuses: string[],
  timeoutMs: number = 60000,
  pollIntervalMs: number = 2000
): Promise<Session> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeoutMs) {
    const session = await getSession(auth, sessionId);

    if (targetStatuses.includes(session.session_status)) {
      return session;
    }

    // Check for terminal failure states
    if (["cancelled", "rejected"].includes(session.session_status)) {
      throw new Error(
        `Session ${sessionId} reached terminal state: ${session.session_status}`
      );
    }

    await sleep(pollIntervalMs);
  }

  throw new Error(
    `Timeout waiting for session ${sessionId} to reach status: ${targetStatuses.join(", ")}`
  );
}

/**
 * Environment info from environment_providers API
 */
export interface Environment {
  kind: string;
  environment_id: string;
  name: string;
  created_at: string;
  state: string;
  config: unknown | null;
}

/**
 * List all environments (from environment_providers endpoint)
 */
export async function listEnvironments(auth: AuthContext): Promise<Environment[]> {
  const response = await fetchWithRetry(
    `${API_BASE_URL}/v1/environment_providers`,
    {
      method: "GET",
      headers: getFullHeaders(auth),
    }
  );

  if (!response.ok) {
    if (response.status === 401) {
      throw new Error("Session expired. Please run /login to sign in again.");
    }
    throw new Error(`Failed to list environments: ${response.statusText}`);
  }

  const data = (await response.json()) as { environments: Environment[] };
  return data.environments;
}

/**
 * Create a new session
 */
export async function createSession(
  auth: AuthContext,
  params: {
    environmentId: string;
    repoUrl: string;
    repoOwner: string;
    repoName: string;
    branch?: string;
    model?: string;
  }
): Promise<Session> {
  const response = await fetchWithRetry(`${API_BASE_URL}/v1/sessions`, {
    method: "POST",
    headers: getFullHeaders(auth),
    body: JSON.stringify({
      environment_id: params.environmentId,
      session_context: {
        sources: [
          {
            type: "git_repository",
            url: params.repoUrl,
          },
        ],
        outcomes: [
          {
            type: "git_repository",
            git_info: {
              type: "github",
              repo: `${params.repoOwner}/${params.repoName}`,
              branches: params.branch ? [params.branch] : [],
            },
          },
        ],
        model: params.model ?? "claude-sonnet-4-20250514",
        allowed_tools: [],
        disallowed_tools: [],
        cwd: "",
      },
    }),
  });

  if (!response.ok) {
    if (response.status === 401) {
      throw new Error("Session expired. Please run /login to sign in again.");
    }
    const errorText = await response.text();
    throw new Error(`Failed to create session: ${response.statusText} - ${errorText}`);
  }

  return (await response.json()) as Session;
}
