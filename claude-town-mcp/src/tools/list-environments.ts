/**
 * list_environments tool implementation
 *
 * Lists available Claude Code environments.
 */

import { listEnvironments } from "../api-client.js";
import { getAuthContext } from "../auth.js";
import type { ToolResponse } from "../types.js";

export const listEnvironmentsDescription =
  "List available Claude Code environments. " +
  "Environments are required when creating new sessions. " +
  "Each environment has an ID, name, and state.";

/**
 * Handler for list_environments tool
 */
export async function handleListEnvironments(): Promise<ToolResponse> {
  const auth = await getAuthContext();
  const environments = await listEnvironments(auth);

  if (environments.length === 0) {
    return {
      content: [
        {
          type: "text",
          text:
            "No environments found. Please create an environment first " +
            "by starting a session from the Claude Code web interface at https://claude.ai/code",
        },
      ],
      isError: false,
    };
  }

  const envList = environments
    .map(
      (env) =>
        `- ${env.name} (${env.environment_id})\n` +
        `  State: ${env.state}\n` +
        `  Created: ${env.created_at}`
    )
    .join("\n\n");

  return {
    content: [
      {
        type: "text",
        text: `Found ${environments.length} environment(s):\n\n${envList}`,
      },
    ],
    isError: false,
  };
}
