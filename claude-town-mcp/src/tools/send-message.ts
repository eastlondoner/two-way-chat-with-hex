/**
 * send_message tool implementation
 */

import { z } from "zod";
import { getAuthContext } from "../auth.js";
import { sendMessage } from "../api-client.js";
import type { ToolResponse } from "../types.js";

/**
 * Input schema for send_message
 */
export const sendMessageSchema = {
  session_id: z.string().describe("The session ID to send the message to"),
  message: z.string().describe("The message content to send"),
};

export const sendMessageDescription =
  "Send a message to an existing Claude Code web session. This is fire-and-forget - it returns immediately after sending without waiting for a response.";

/**
 * Handler for send_message tool
 */
export async function handleSendMessage(params: {
  session_id: string;
  message: string;
}): Promise<ToolResponse> {
  try {
    const auth = await getAuthContext();
    await sendMessage(auth, params.session_id, params.message);

    return {
      content: [
        {
          type: "text",
          text: `Message sent to session ${params.session_id}. The session will process it asynchronously.`,
        },
      ],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `Error sending message: ${message}` }],
      isError: true,
    };
  }
}
