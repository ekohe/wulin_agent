import {test} from "node:test";
import assert from "node:assert/strict";
import {hasPendingApprovalInApi, toAssistantUiMessages} from "../../app/javascript/wulin_agent/messageMapper";

const shape = (content) => content.map((part) => part.type === "text" ? `text:${part.text}` : `call:${part.toolCallId}`);

const calls = [
  {id: "call_1", name: "list_grids", arguments: {}},
  {id: "call_2", name: "list_records", arguments: {controller: "people"}},
];
const results = [
  {id: "call_1", name: "list_grids", result: [{controller: "people"}]},
  {id: "call_2", name: "list_records", result: {total: 2}},
];

test("renders a stored turn in the order it happened", () => {
  const [, assistant] = toAssistantUiMessages([
    {role: "user", content: "How many people?"},
    {
      role: "assistant",
      content: "Let me check.\n\nThere are 2 people.",
      metadata: {
        tool_calls: calls,
        tool_results: results,
        parts: [
          {type: "text", text: "Let me check."},
          {type: "tool_call", id: "call_1"},
          {type: "tool_call", id: "call_2"},
          {type: "text", text: "There are 2 people."},
        ],
      },
    },
  ]);

  assert.deepEqual(shape(assistant.content), ["text:Let me check.", "call:call_1", "call:call_2", "text:There are 2 people."]);
  assert.deepEqual(assistant.content[2].result, {total: 2});
});

test("renders a turn stored before the order was kept as calls, then text", () => {
  const [assistant] = toAssistantUiMessages([
    {role: "assistant", content: "There are 2 people.", metadata: {tool_calls: calls, tool_results: results}},
  ]);

  assert.deepEqual(shape(assistant.content), ["call:call_1", "call:call_2", "text:There are 2 people."]);
});

test("keeps calls and text the stored order does not mention", () => {
  const [assistant] = toAssistantUiMessages([
    {
      role: "assistant",
      content: "There are 2 people.",
      metadata: {tool_calls: calls, tool_results: results, parts: [{type: "tool_call", id: "call_2"}]},
    },
  ]);

  assert.deepEqual(shape(assistant.content), ["call:call_2", "call:call_1", "text:There are 2 people."]);
});

test("marks a paused turn as requiring action, with the approval's expiry", () => {
  const apiMessages = [
    {role: "user", content: "Delete Alice"},
    {
      role: "assistant",
      content: "",
      metadata: {
        tool_calls: [{id: "call_1", name: "destroy_record", arguments: {id: 1}}],
        tool_results: [{id: "call_1", name: "destroy_record", result: {status: "approval_required", approval_token: "tok", approval_expires_at: "2026-11-03T04:00:00Z"}}],
        parts: [{type: "tool_call", id: "call_1"}],
      },
    },
  ];
  const [, assistant] = toAssistantUiMessages(apiMessages);

  assert.deepEqual(assistant.status, {type: "requires-action", reason: "tool-calls"});
  assert.deepEqual(assistant.content[0].approval, {id: "tok", expiresAt: "2026-11-03T04:00:00Z"});
  assert.equal(hasPendingApprovalInApi(apiMessages), true);
});

test("shows an expired call's stored result rather than inferring an approval", () => {
  const [assistant] = toAssistantUiMessages([
    {
      role: "assistant",
      content: "",
      metadata: {
        tool_calls: [{id: "call_1", name: "destroy_record", arguments: {}}],
        tool_results: [{id: "call_1", name: "destroy_record", result: {status: "expired", tool: "destroy_record"}}],
      },
    },
  ]);

  assert.equal(assistant.content[0].approval, undefined);
  assert.deepEqual(assistant.content[0].result, {status: "expired", tool: "destroy_record"});
  assert.equal(assistant.status, undefined);
});
