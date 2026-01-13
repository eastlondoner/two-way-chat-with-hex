/**
 * create_session tool implementation
 *
 * Note: The create session API endpoint has not been discovered yet.
 * Sessions are currently created through the Claude Code web interface
 * or via the claude.ai/code page.
 *
 * This is a placeholder that will be implemented once the API is reverse-engineered.
 */

import { z } from "zod";
import type { ToolResponse } from "../types.js";

/**
 * Input schema for create_session
 */
export const createSessionSchema = {
  repo: z
    .string()
    .describe("GitHub repository in owner/name format (e.g., 'eastlondoner/claude')"),
  branch: z
    .string()
    .optional()
    .describe("Git branch to use (optional, defaults to repo default branch)"),
  prompt: z.string().describe("Initial task/prompt for the session"),
};

export const createSessionDescription =
  "Create a new Claude Code web session on a GitHub repository. " +
  "Requires the Anthropic GitHub App to be installed on the repository. " +
  "The session will be polled until it reaches 'running' or 'working' status.";

/**
 * Handler for create_session tool
 *
 * TODO: Implement once the create session API is discovered.
 * The API likely requires:
 * - POST to an endpoint like /v1/sessions or /v1/environment_providers/{id}/sessions
 * - Request body with repo URL, branch, and initial prompt
 * - Polling until session transitions from 'initializing' to 'running'
 */
export async function handleCreateSession(params: {
  repo: string;
  branch?: string;
  prompt: string;
}): Promise<ToolResponse> {
  // TODO: Implement when API is discovered
  // For now, return an informative error

  return {
    content: [
      {
        type: "text",
        text:
          `Creating new Claude Code web sessions is not yet supported via the MCP server.\n\n` +
          `The create session API endpoint has not been discovered yet. ` +
          `Sessions can currently only be created through:\n` +
          `- The Claude Code web interface at https://claude.ai/code\n` +
          `- The Claude iOS app\n\n` +
          `Once a session is created, you can use:\n` +
          `- list_sessions: to find the session ID\n` +
          `- send_message: to send tasks to the session\n` +
          `- get_session_status: to monitor progress\n\n` +
          `Requested session would have been:\n` +
          `- Repository: ${params.repo}\n` +
          `- Branch: ${params.branch ?? "(default)"}\n` +
          `- Prompt: ${params.prompt}`,
      },
    ],
    isError: true,
  };
}
