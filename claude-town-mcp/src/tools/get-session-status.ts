/**
 * get_session_status tool implementation
 */

import { z } from "zod";
import { getAuthContext } from "../auth.js";
import { getSession } from "../api-client.js";
import type { ToolResponse } from "../types.js";

/**
 * Input schema for get_session_status
 */
export const getSessionStatusSchema = {
  session_id: z.string().describe("The session ID to check"),
};

export const getSessionStatusDescription =
  "Get the current status of a Claude Code web session. This is a lightweight check for monitoring session progress.";

/**
 * Handler for get_session_status tool
 */
export async function handleGetSessionStatus(params: {
  session_id: string;
}): Promise<ToolResponse> {
  try {
    const auth = await getAuthContext();
    const session = await getSession(auth, params.session_id);

    const status = {
      id: session.id,
      status: session.session_status,
      title: session.title,
      updated_at: session.updated_at,
    };

    return {
      content: [{ type: "text", text: JSON.stringify(status, null, 2) }],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `Error getting session status: ${message}` }],
      isError: true,
    };
  }
}
