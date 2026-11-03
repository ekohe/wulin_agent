import {test} from "node:test";
import assert from "node:assert/strict";
import {streamResponse} from "../../app/javascript/wulin_agent/runtime/streamResponse";

// A response body as the server writes it: one "prefix:json" line per event.
function body(lines) {
  const encoder = new TextEncoder();
  return new ReadableStream({
    start(controller) {
      controller.enqueue(encoder.encode(lines.join("\n") + "\n"));
      controller.close();
    },
  });
}

async function last(iterator) {
  let value;
  for await (value of iterator);
  return value;
}

const shape = (content) => content.map((part) => part.type === "text" ? `text:${part.text}` : `call:${part.toolCallId}`);

test("streams text and tool calls in the order they arrive", async () => {
  const update = await last(streamResponse(body([
    '0:"Let me check."',
    'b:{"toolCallId":"call_1","toolName":"list_grids"}',
    'c:{}',
    'a:{"toolCallId":"call_1","result":[]}',
    'b:{"toolCallId":"call_2","toolName":"list_records"}',
    'c:{"controller":"people"}',
    'a:{"toolCallId":"call_2","result":{"total":2}}',
    '0:"Found 2 people."',
    'd:{"finishReason":"stop"}',
  ])));

  assert.deepEqual(shape(update.content), ["text:Let me check.", "call:call_1", "call:call_2", "text:Found 2 people."]);
  assert.deepEqual(update.content[2].args, {controller: "people"});
  assert.deepEqual(update.content[2].result, {total: 2});
});

test("pauses on an approval with its token and expiry", async () => {
  const update = await last(streamResponse(body([
    '0:"I will delete Alice."',
    'b:{"toolCallId":"call_1","toolName":"destroy_record"}',
    'c:{"id":1}',
    'a:{"toolCallId":"call_1","result":{"status":"approval_required","approval_token":"tok","approval_expires_at":"2026-11-03T04:00:00Z"}}',
  ])));

  assert.deepEqual(update.status, {type: "requires-action", reason: "tool-calls"});
  assert.deepEqual(shape(update.content), ["text:I will delete Alice.", "call:call_1"]);
  assert.deepEqual(update.content[1].approval, {id: "tok", expiresAt: "2026-11-03T04:00:00Z"});
});

test("on a resume, settles the paused call in place and yields only what follows", async () => {
  const paused = {type: "tool-call", toolCallId: "call_1", toolName: "destroy_record", args: {}, approval: {id: "tok", approved: true}};
  const update = await last(streamResponse(body([
    'a:{"toolCallId":"call_1","result":{"success":true}}',
    '0:"Done."',
    'd:{"finishReason":"stop"}',
  ]), [paused]));

  assert.deepEqual(paused.result, {success: true});
  assert.deepEqual(shape(update.content), ["text:Done."]);
});

test("writes a stream error as its own text segment", async () => {
  const update = await last(streamResponse(body(['0:"Working on it."', '3:"Error : boom"'])));

  assert.deepEqual(shape(update.content), ["text:Working on it.", "text:Error : boom"]);
});
