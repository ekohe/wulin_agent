import {test} from "node:test";
import assert from "node:assert/strict";
import {isFirstAssistantInTurn, isLastAssistantInTurn, turnText} from "../../app/javascript/wulin_agent/turnFeedback";

const user = (text) => ({role: "user", content: [{type: "text", text}]});
const assistant = (...parts) => ({role: "assistant", content: parts});
const text = (value) => ({type: "text", text: value});
const call = {type: "tool-call", toolCallId: "call_1"};

const messages = [
  user("Delete Alice"),
  assistant(text("I'll delete Alice."), call),
  assistant(text("Done."), text("Anything else?")),
  user("No"),
  assistant(call),
];

test("knows where a turn starts and ends", () => {
  assert.equal(isFirstAssistantInTurn(messages, 1), true);
  assert.equal(isFirstAssistantInTurn(messages, 2), false);
  assert.equal(isLastAssistantInTurn(messages, 1), false);
  assert.equal(isLastAssistantInTurn(messages, 2), true);
});

test("copies every text segment of the turn, a blank line apart", () => {
  assert.equal(turnText(messages, 2), "I'll delete Alice.\n\nDone.\n\nAnything else?");
});

test("has nothing to copy for a turn without text", () => {
  assert.equal(turnText(messages, 4), "");
});
