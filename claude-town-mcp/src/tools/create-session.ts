/**
 * create_session tool implementation
 *
 * Creates a new Claude Code web session on a GitHub repository.
 */

import { z } from "zod";
import {
  listEnvironments,
  createSession,
  sendMessage,
  waitForSessionStatus,
} from "../api-client.js";
import { getAuthContext } from "../auth.js";
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
  environment_id: z
    .string()
    .optional()
    .describe(
      "Environment ID to use (optional, uses first active environment if not specified). " +
        "Use list_environments to see available environments."
    ),
  model: z
    .string()
    .optional()
    .describe(
      "Model to use (optional, defaults to claude-sonnet-4-20250514). " +
        "Options: claude-sonnet-4-20250514, claude-opus-4-5-20251101"
    ),
};

export const createSessionDescription =
  "Create a new Claude Code web session on a GitHub repository. " +
  "Requires the Anthropic GitHub App to be installed on the repository. " +
  "Returns the session ID and status after creation.";

/**
 * Handler for create_session tool
 */
export async function handleCreateSession(params: {
  repo: string;
  branch?: string;
  prompt: string;
  environment_id?: string;
  model?: string;
}): Promise<ToolResponse> {
  const auth = await getAuthContext();

  // Parse repo into owner/name
  const repoMatch = params.repo.match(/^([^/]+)\/([^/]+)$/);
  if (!repoMatch) {
    return {
      content: [
        {
          type: "text",
          text: `Invalid repo format: ${params.repo}. Expected owner/name format (e.g., 'eastlondoner/claude')`,
        },
      ],
      isError: true,
    };
  }
  const [, repoOwner, repoName] = repoMatch;

  // Get environment ID
  let environmentId = params.environment_id;
  if (!environmentId) {
    const environments = await listEnvironments(auth);
    const activeEnv = environments.find((e) => e.state === "active");
    if (!activeEnv) {
      return {
        content: [
          {
            type: "text",
            text:
              "No active environments found. Please create an environment first " +
              "by starting a session from the Claude Code web interface.",
          },
        ],
        isError: true,
      };
    }
    environmentId = activeEnv.environment_id;
  }

  // Create the session
  const session = await createSession(auth, {
    environmentId,
    repoUrl: `https://github.com/${params.repo}`,
    repoOwner: repoOwner!,
    repoName: repoName!,
    branch: params.branch,
    model: params.model,
  });

  // Send the initial prompt
  await sendMessage(auth, session.id, params.prompt);

  // Wait briefly for session to start processing
  try {
    await waitForSessionStatus(auth, session.id, ["working", "running"], 10000, 1000);
  } catch {
    // Ignore timeout - session may still be initializing
  }

  return {
    content: [
      {
        type: "text",
        text:
          `Session created successfully!\n\n` +
          `Session ID: ${session.id}\n` +
          `Status: ${session.session_status}\n` +
          `Environment: ${environmentId}\n` +
          `Repository: ${params.repo}\n` +
          `Branch: ${params.branch ?? "(default)"}\n` +
          `Model: ${params.model ?? "claude-sonnet-4-20250514"}\n` +
          `Prompt: ${params.prompt}\n\n` +
          `Use get_session_status to monitor progress.\n` +
          `Use send_message to send additional messages.`,
      },
    ],
    isError: false,
  };
}
