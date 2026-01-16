#!/usr/bin/env node
/**
 * Wake the most recent Claude Code session that contributed to a PR
 *
 * Usage: node wake-session.js <pr_branch> <message>
 *
 * Environment variables required:
 *   CLAUDE_ACCESS_TOKEN - OAuth access token from ~/.claude/.credentials.json
 *   CLAUDE_ORG_UUID - Organization UUID (optional, will fetch if not provided)
 *
 * This script:
 * 1. Lists all Claude Code sessions
 * 2. Finds sessions matching the PR branch
 * 3. Sends a wake-up message to the most recently updated session
 */

const { randomUUID } = require('crypto');
const fs = require('fs');

const API_BASE_URL = 'https://api.anthropic.com';

// Retry configuration
const RETRY_DELAYS = [2000, 4000, 8000, 16000];

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchWithRetry(url, options, retries = RETRY_DELAYS.length) {
  let lastError = null;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options);

      if (response.ok || response.status < 500) {
        return response;
      }

      if (attempt < retries) {
        const delay = RETRY_DELAYS[attempt] || 2000;
        console.error(`Server error ${response.status}, retrying in ${delay}ms...`);
        await sleep(delay);
        continue;
      }

      return response;
    } catch (error) {
      lastError = error;

      if (attempt < retries) {
        const delay = RETRY_DELAYS[attempt] || 2000;
        console.error(`Network error, retrying in ${delay}ms...`);
        await sleep(delay);
        continue;
      }
    }
  }

  throw lastError || new Error('Request failed after retries');
}

function getAuthHeaders(accessToken) {
  return {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'anthropic-version': '2023-06-01',
  };
}

async function getOrgUUID(accessToken) {
  // Check if already provided
  if (process.env.CLAUDE_ORG_UUID) {
    return process.env.CLAUDE_ORG_UUID;
  }

  const response = await fetchWithRetry(`${API_BASE_URL}/api/oauth/profile`, {
    method: 'GET',
    headers: getAuthHeaders(accessToken),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch profile: ${response.status} ${response.statusText}`);
  }

  const profile = await response.json();
  return profile.organization.uuid;
}

async function listSessions(accessToken, orgUUID) {
  const response = await fetchWithRetry(`${API_BASE_URL}/v1/sessions`, {
    method: 'GET',
    headers: {
      ...getAuthHeaders(accessToken),
      'x-organization-uuid': orgUUID,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to list sessions: ${response.status} ${response.statusText}`);
  }

  const data = await response.json();
  return data.data;
}

async function sendMessage(accessToken, orgUUID, sessionId, message) {
  const event = {
    events: [{
      uuid: randomUUID(),
      session_id: sessionId,
      type: 'user',
      parent_tool_use_id: null,
      message: {
        role: 'user',
        content: message,
      },
    }],
  };

  const response = await fetchWithRetry(`${API_BASE_URL}/v1/sessions/${sessionId}/events`, {
    method: 'POST',
    headers: {
      ...getAuthHeaders(accessToken),
      'x-organization-uuid': orgUUID,
    },
    body: JSON.stringify(event),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to send message: ${response.status} ${response.statusText} - ${text}`);
  }

  return true;
}

function extractBranchesFromSession(session) {
  const outcome = session.session_context?.outcomes?.find(o => o.type === 'git_repository');
  return outcome?.git_info?.branches ?? [];
}

function findMatchingSessions(sessions, targetBranch) {
  return sessions.filter(session => {
    const branches = extractBranchesFromSession(session);
    return branches.includes(targetBranch);
  });
}

function getMostRecentSession(sessions) {
  if (sessions.length === 0) return null;

  return sessions.reduce((latest, session) => {
    const latestTime = new Date(latest.updated_at).getTime();
    const sessionTime = new Date(session.updated_at).getTime();
    return sessionTime > latestTime ? session : latest;
  });
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: node wake-session.js <pr_branch> <message>');
    console.error('');
    console.error('Environment variables:');
    console.error('  CLAUDE_ACCESS_TOKEN - Required: OAuth access token');
    console.error('  CLAUDE_ORG_UUID     - Optional: Organization UUID');
    process.exit(1);
  }

  const [targetBranch, ...messageParts] = args;
  const message = messageParts.join(' ');

  const accessToken = process.env.CLAUDE_ACCESS_TOKEN;
  if (!accessToken) {
    console.error('Error: CLAUDE_ACCESS_TOKEN environment variable is required');
    process.exit(1);
  }

  try {
    console.log(`Looking for sessions on branch: ${targetBranch}`);

    // Get org UUID
    const orgUUID = await getOrgUUID(accessToken);
    console.log(`Organization UUID: ${orgUUID.slice(0, 8)}...`);

    // List all sessions
    const sessions = await listSessions(accessToken, orgUUID);
    console.log(`Found ${sessions.length} total sessions`);

    // Filter to matching branch
    const matchingSessions = findMatchingSessions(sessions, targetBranch);
    console.log(`Found ${matchingSessions.length} sessions matching branch`);

    if (matchingSessions.length === 0) {
      console.log('No sessions found for this branch. Nothing to wake.');
      // Output for GitHub Actions
      if (process.env.GITHUB_OUTPUT) {
        fs.appendFileSync(process.env.GITHUB_OUTPUT, 'session_found=false\n');
      }
      return;
    }

    // Get most recent session
    const targetSession = getMostRecentSession(matchingSessions);
    console.log(`Most recent session: ${targetSession.id}`);
    console.log(`  Title: ${targetSession.title}`);
    console.log(`  Status: ${targetSession.session_status}`);
    console.log(`  Updated: ${targetSession.updated_at}`);

    // Send wake-up message
    console.log(`\nSending wake-up message...`);
    await sendMessage(accessToken, orgUUID, targetSession.id, message);
    console.log('Message sent successfully!');

    // Output for GitHub Actions
    if (process.env.GITHUB_OUTPUT) {
      const output = [
        'session_found=true',
        `session_id=${targetSession.id}`,
        `session_title=${targetSession.title}`,
        `session_status=${targetSession.session_status}`,
      ].join('\n') + '\n';
      fs.appendFileSync(process.env.GITHUB_OUTPUT, output);
    }

  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
