#!/usr/bin/env node
/**
 * claude-town-mcp - MCP server for orchestrating Claude Code web sessions
 *
 * This MCP server provides tools to interact with Claude Code web sessions
 * via the undocumented Claude Code Sessions API.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import {
  listSessionsSchema,
  listSessionsDescription,
  handleListSessions,
} from "./tools/list-sessions.js";
import {
  getSessionSchema,
  getSessionDescription,
  handleGetSession,
} from "./tools/get-session.js";
import {
  sendMessageSchema,
  sendMessageDescription,
  handleSendMessage,
} from "./tools/send-message.js";
import {
  getSessionStatusSchema,
  getSessionStatusDescription,
  handleGetSessionStatus,
} from "./tools/get-session-status.js";
import {
  createSessionSchema,
  createSessionDescription,
  handleCreateSession,
} from "./tools/create-session.js";
import {
  listEnvironmentsDescription,
  handleListEnvironments,
} from "./tools/list-environments.js";

/**
 * Register all tools with the MCP server
 */
function registerTools(server: McpServer): void {
  // list_sessions - List all Claude Code web sessions
  server.registerTool(
    "list_sessions",
    {
      description: listSessionsDescription,
      inputSchema: listSessionsSchema,
    },
    async (params) => {
      return handleListSessions(params as Parameters<typeof handleListSessions>[0]);
    }
  );

  // get_session - Get detailed session information
  server.registerTool(
    "get_session",
    {
      description: getSessionDescription,
      inputSchema: getSessionSchema,
    },
    async (params) => {
      return handleGetSession(params as Parameters<typeof handleGetSession>[0]);
    }
  );

  // send_message - Send a message to a session (fire-and-forget)
  server.registerTool(
    "send_message",
    {
      description: sendMessageDescription,
      inputSchema: sendMessageSchema,
    },
    async (params) => {
      return handleSendMessage(params as Parameters<typeof handleSendMessage>[0]);
    }
  );

  // get_session_status - Get current session status
  server.registerTool(
    "get_session_status",
    {
      description: getSessionStatusDescription,
      inputSchema: getSessionStatusSchema,
    },
    async (params) => {
      return handleGetSessionStatus(
        params as Parameters<typeof handleGetSessionStatus>[0]
      );
    }
  );

  // create_session - Create a new session
  server.registerTool(
    "create_session",
    {
      description: createSessionDescription,
      inputSchema: createSessionSchema,
    },
    async (params) => {
      return handleCreateSession(params as Parameters<typeof handleCreateSession>[0]);
    }
  );

  // list_environments - List available environments
  server.registerTool(
    "list_environments",
    {
      description: listEnvironmentsDescription,
      inputSchema: {},
    },
    async () => {
      return handleListEnvironments();
    }
  );
}

/**
 * Main entry point
 */
async function main(): Promise<void> {
  // Create the MCP server
  const server = new McpServer({
    name: "claude-town-mcp",
    version: "0.1.0",
  });

  // Register all tools
  registerTools(server);

  // Create stdio transport
  const transport = new StdioServerTransport();

  // Handle shutdown
  const shutdown = async (): Promise<void> => {
    await transport.close();
    process.exit(0);
  };

  process.on("SIGINT", () => void shutdown());
  process.on("SIGTERM", () => void shutdown());

  // Connect and start
  await server.connect(transport);
}

main().catch((err: unknown) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
