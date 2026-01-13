/**
 * get_session tool implementation
 */

import { z } from "zod";
import { getAuthContext } from "../auth.js";
import { getSession } from "../api-client.js";
import type { ToolResponse } from "../types.js";

/**
 * Input schema for get_session
 */
export const getSessionSchema = {
  session_id: z.string().describe("The session ID to retrieve"),
};

export const getSessionDescription =
  "Get detailed information about a specific Claude Code web session.";

/**
 * Handler for get_session tool
 */
export async function handleGetSession(params: {
  session_id: string;
}): Promise<ToolResponse> {
  try {
    const auth = await getAuthContext();
    const session = await getSession(auth, params.session_id);

    // Extract useful information
    const source = session.session_context.sources.find(
      (s) => s.type === "git_repository"
    );
    const outcome = session.session_context.outcomes.find(
      (o) => o.type === "git_repository"
    );

    const summary = {
      id: session.id,
      title: session.title,
      status: session.session_status,
      type: session.type,
      model: session.session_context.model,
      repo: source?.url ?? null,
      branch: outcome?.git_info?.branches[0] ?? null,
      created_at: session.created_at,
      updated_at: session.updated_at,
      environment_id: session.environment_id,
    };

    return {
      content: [{ type: "text", text: JSON.stringify(summary, null, 2) }],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `Error getting session: ${message}` }],
      isError: true,
    };
  }
}
