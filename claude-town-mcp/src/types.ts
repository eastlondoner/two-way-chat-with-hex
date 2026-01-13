/**
 * Type definitions for claude-town-mcp
 */

/**
 * OAuth credentials stored in ~/.claude/.credentials.json
 */
export interface ClaudeCredentials {
  claudeAiOauth?: {
    accessToken: string;
    refreshToken: string;
    expiresAt: number;
    scopes?: string[];
    subscriptionType?: string;
    rateLimitTier?: string;
  };
}

/**
 * User profile response from /api/oauth/profile
 */
export interface UserProfile {
  account: {
    uuid: string;
    full_name: string;
    display_name: string;
    email: string;
    has_claude_max: boolean;
    has_claude_pro: boolean;
  };
  organization: {
    uuid: string;
    name: string;
    organization_type: string;
    billing_type: string;
    rate_limit_tier: string;
    has_extra_usage_enabled: boolean;
  };
}

/**
 * Session status enum
 */
export type SessionStatus =
  | "running"
  | "working"
  | "waiting"
  | "idle"
  | "completed"
  | "archived"
  | "cancelled"
  | "rejected";

/**
 * Git repository source in session context
 */
export interface GitRepositorySource {
  type: "git_repository";
  url: string;
  revision?: string;
}

/**
 * Git repository outcome with branch info
 */
export interface GitRepositoryOutcome {
  type: "git_repository";
  git_info: {
    branches: string[];
    repo: string;
    type: "github";
  };
}

/**
 * Session context from the API
 */
export interface SessionContext {
  allowed_tools: string[];
  disallowed_tools: string[];
  cwd: string;
  model: string;
  sources: GitRepositorySource[];
  outcomes: GitRepositoryOutcome[];
}

/**
 * Full session object from the API
 */
export interface Session {
  id: string;
  title: string;
  session_status: SessionStatus;
  type: string;
  environment_id: string;
  created_at: string;
  updated_at: string;
  session_context: SessionContext;
}

/**
 * Sessions list response
 */
export interface SessionsListResponse {
  data: Session[];
}

/**
 * Session summary for list_sessions tool output
 */
export interface SessionSummary {
  id: string;
  title: string;
  status: SessionStatus;
  repo: string | null;
  branch: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Event to send to a session
 */
export interface SessionEvent {
  uuid: string;
  session_id: string;
  type: "user";
  parent_tool_use_id: null;
  message: {
    role: "user";
    content: string;
  };
}

/**
 * Events request body
 */
export interface SendEventsRequest {
  events: SessionEvent[];
}

/**
 * Standard tool response format - includes index signature for MCP SDK compatibility
 */
export interface ToolResponse {
  [key: string]: unknown;
  content: { type: "text"; text: string }[];
  isError?: boolean;
}
