import {test} from "node:test";
import assert from "node:assert/strict";
import {createTurnParts, findApprovedCall, findRefusedCall} from "../../app/javascript/wulin_agent/turnParts";

const call = (id, extra = {}) => ({type: "tool-call", toolCallId: id, toolName: "list_grids", args: {}, ...extra});

test("keeps text and tool calls in arrival order, merging consecutive text", () => {
  const turn = createTurnParts();
  turn.appendText("Let me ");
  turn.appendText("check.");
  turn.addToolCall(call("call_1"));
  turn.addToolCall(call("call_2"));
  turn.appendText("Found 2 people.");

  assert.deepEqual(
    turn.content().map((part) => part.type === "text" ? part.text : part.toolCallId),
    ["Let me check.", "call_1", "call_2", "Found 2 people."]
  );
  assert.deepEqual(turn.toolCalls().map((part) => part.toolCallId), ["call_1", "call_2"]);
});

test("starts a separate segment for an error after text", () => {
  const turn = createTurnParts();
  turn.appendText("Working on it.");
  turn.startText("Error : boom");

  assert.deepEqual(turn.content(), [
    {type: "text", text: "Working on it."},
    {type: "text", text: "Error : boom"},
  ]);
});

test("copies text parts on every read and keeps tool calls by identity", () => {
  const turn = createTurnParts();
  const part = call("call_1");
  turn.appendText("a");
  turn.addToolCall(part);

  const first = turn.content();
  const second = turn.content();
  assert.notEqual(first[0], second[0]);
  assert.equal(second[1], part);
  assert.equal(turn.isEmpty(), false);
  assert.equal(createTurnParts().isEmpty(), true);
});

test("finds the approved call that has not run yet", () => {
  const ran = call("call_1", {approval: {approved: true}, result: {success: true}});
  const waiting = call("call_2", {approval: {id: "tok", approved: true}});

  assert.equal(findApprovedCall([ran, waiting]), waiting);
  assert.equal(findApprovedCall([ran]), undefined);
});

test("finds a refusal made just now even though assistant-ui stored an error result on it", () => {
  const fromHistory = call("call_1", {approval: {approved: false}, result: {status: "rejected"}});
  const justNow = call("call_2", {approval: {id: "tok", approved: false, reason: "User declined"}, result: {error: "User declined"}, isError: true});

  assert.equal(findRefusedCall([fromHistory, justNow]), justNow);
  assert.equal(findRefusedCall([fromHistory]), undefined);
});

test("takes the latest refusal when a resumed message holds an earlier one", () => {
  const earlier = call("call_1", {approval: {id: "tok-1", approved: false}, result: {status: "rejected"}});
  const latest = call("call_2", {approval: {id: "tok-2", approved: false}});

  assert.equal(findRefusedCall([earlier, latest]), latest);
});
