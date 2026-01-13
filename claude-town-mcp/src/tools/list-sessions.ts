/**
 * list_sessions tool implementation
 */

import { z } from "zod";
import { getAuthContext } from "../auth.js";
import { listSessions } from "../api-client.js";
import type { ToolResponse, SessionStatus } from "../types.js";

/**
 * Input schema for list_sessions
 */
export const listSessionsSchema = {
  status_filter: z
    .enum([
      "running",
      "working",
      "waiting",
      "idle",
      "completed",
      "archived",
      "cancelled",
      "rejected",
    ])
    .optional()
    .describe("Filter by session status"),
  repo_filter: z
    .string()
    .optional()
    .describe("Filter by repository name (substring match)"),
  limit: z
    .number()
    .min(1)
    .max(100)
    .default(50)
    .describe("Maximum number of sessions to return"),
};

export const listSessionsDescription =
  "List all Claude Code web sessions with optional filtering by status or repository.";

/**
 * Handler for list_sessions tool
 */
export async function handleListSessions(params: {
  status_filter?: SessionStatus;
  repo_filter?: string;
  limit?: number;
}): Promise<ToolResponse> {
  try {
    const auth = await getAuthContext();
    let sessions = await listSessions(auth);

    // Apply status filter
    if (params.status_filter) {
      sessions = sessions.filter((s) => s.status === params.status_filter);
    }

    // Apply repo filter (substring match)
    if (params.repo_filter) {
      const filter = params.repo_filter.toLowerCase();
      sessions = sessions.filter(
        (s) => s.repo && s.repo.toLowerCase().includes(filter)
      );
    }

    // Apply limit
    const limit = params.limit ?? 50;
    sessions = sessions.slice(0, limit);

    if (sessions.length === 0) {
      return {
        content: [{ type: "text", text: "No sessions found matching filters." }],
      };
    }

    return {
      content: [{ type: "text", text: JSON.stringify(sessions, null, 2) }],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `Error listing sessions: ${message}` }],
      isError: true,
    };
  }
}
